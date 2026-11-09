-- =============================================================================
-- mart_customer_360
-- =============================================================================
-- Grain: mỗi khách hàng một dòng, 7.000 dòng.
--
-- "Customer 360" là bảng nhìn toàn diện về một khách hàng: hồ sơ, lịch sử
-- mua, giá trị mang lại, phân nhóm RFM, đánh giá sản phẩm. Khác với fact và
-- dimension (dùng để join, cắt lát), mart là bảng tổng hợp sẵn để đọc trực
-- tiếp hoặc đưa thẳng vào dashboard.
--
-- RFM là cách phân nhóm khách theo 3 tiêu chí:
--   R - Recency  : lần mua gần nhất cách đây bao lâu (càng gần càng tốt)
--   F - Frequency: mua bao nhiêu lần
--   M - Monetary : mang lại bao nhiêu tiền
-- Mỗi tiêu chí được chấm từ 1 đến 5, rồi kết hợp lại thành nhóm như
-- Champions, Loyal, At risk...
--
-- RFM chỉ tính trên đơn được tính doanh thu. "Hôm nay" được lấy là ngày đặt
-- đơn cuối cùng trong dữ liệu, vì dữ liệu là lịch sử (2021 đến 2025). Nếu dùng
-- ngày hiện tại thật, mọi khách đều trông như đã bỏ đi từ lâu.
-- =============================================================================

-- Bước 1: lấy dữ liệu đầu vào ---------------------------------------------------

-- Thông tin hồ sơ khách hàng.
with customers as (

    select * from {{ ref('dim_customer') }}

),

-- Đơn hàng kèm ngày thật. fact_orders chỉ có order_date_key (số YYYYMMDD),
-- nên join dim_date để lấy lại kiểu date, phục vụ tính số ngày ở bước RFM.
orders as (

    select
        orders.customer_key,
        dates.date_day as order_date,
        orders.order_total,
        orders.counts_as_revenue
    from {{ ref('fact_orders') }} as orders
    inner join {{ ref('dim_date') }} as dates
        on orders.order_date_key = dates.date_key

),

-- Ngày mốc để tính recency: ngày đặt đơn cuối cùng trong toàn bộ dữ liệu.
-- Kết quả chỉ có 1 dòng.
reference_date as (

    select max(order_date) as as_of_date from orders

),

-- Bước 2: tính các chỉ số mua hàng của từng khách ------------------------------

order_metrics as (

    select
        customer_key,
        count(*)                                                     as order_count,
        count(*) filter (where counts_as_revenue)                    as revenue_order_count,
        sum(order_total)                                             as lifetime_order_value,
        sum(case when counts_as_revenue then order_total else 0 end) as lifetime_revenue,
        min(order_date)                                              as first_order_date,
        max(order_date)                                              as last_order_date,
        -- lần mua gần nhất có tính doanh thu, dùng cho điểm R
        max(order_date) filter (where counts_as_revenue)             as last_revenue_order_date
    from orders
    group by customer_key

),

-- Số đánh giá và điểm đánh giá trung bình của từng khách.
-- Bảng review có customer_id chứ không có customer_key, nên tạo khoá bằng cùng
-- cách băm để join được với customers.
reviews as (

    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
        count(*)    as review_count,
        avg(rating) as average_review_rating
    from {{ ref('stg_ecommerce__product_reviews') }}
    group by 1  -- group by cột thứ nhất, tức customer_key

),

-- Bước 3: chấm điểm RFM ------------------------------------------------------

rfm as (

    select
        order_metrics.customer_key,
        -- số ngày từ lần mua gần nhất đến ngày mốc
        date_diff('day', order_metrics.last_revenue_order_date, reference_date.as_of_date) as recency_days,

        -- ntile(5): sắp xếp khách theo một cột rồi chia thành 5 nhóm bằng nhau,
        -- nhóm 1 là thấp nhất, nhóm 5 là cao nhất.
        -- R: sắp theo ngày mua gần nhất tăng dần, nên mua gần đây nhất được 5.
        ntile(5) over (order by order_metrics.last_revenue_order_date)                     as recency_score,
        -- F: mua càng nhiều đơn điểm càng cao
        ntile(5) over (order by order_metrics.revenue_order_count)                         as frequency_score,
        -- M: mang lại càng nhiều tiền điểm càng cao
        ntile(5) over (order by order_metrics.lifetime_revenue)                            as monetary_score
    from order_metrics
    -- cross join với bảng 1 dòng: gắn ngày mốc vào mọi khách
    cross join reference_date
    -- chỉ chấm điểm khách có ít nhất một đơn tính doanh thu
    where order_metrics.revenue_order_count > 0

)

-- Bước 4: ghép tất cả vào danh sách khách hàng ----------------------------------

select
    customers.customer_key,
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    customers.email,
    customers.signup_date,
    customers.first_order_cohort_month,

    -- khách chưa mua thì left join trả về null, đổi thành 0
    coalesce(order_metrics.order_count, 0)                         as order_count,
    coalesce(order_metrics.revenue_order_count, 0)                 as revenue_order_count,
    coalesce(order_metrics.lifetime_order_value, 0)                as lifetime_order_value,
    coalesce(order_metrics.lifetime_revenue, 0)                    as lifetime_revenue,

    -- giá trị đơn trung bình; nullif tránh chia cho 0 với khách chưa có đơn
    -- tính doanh thu (kết quả là null thay vì lỗi)
    order_metrics.lifetime_revenue
        / nullif(order_metrics.revenue_order_count, 0)             as average_order_value,
    order_metrics.first_order_date,
    order_metrics.last_order_date,

    -- điểm RFM
    rfm.recency_days,
    rfm.recency_score,
    rfm.frequency_score,
    rfm.monetary_score,

    -- Phân nhóm khách từ điểm R và F. case when xét từ trên xuống, gặp điều
    -- kiện đúng đầu tiên thì dừng, nên thứ tự các dòng có ý nghĩa.
    case
        when rfm.customer_key is null                                  then 'No revenue orders'  -- chưa có đơn tính doanh thu
        when rfm.recency_score >= 4 and rfm.frequency_score >= 4       then 'Champions'          -- mua gần đây và mua nhiều
        when rfm.frequency_score >= 4                                  then 'Loyal'              -- mua nhiều nhưng không gần đây
        when rfm.recency_score >= 4                                    then 'Recent'             -- mới mua nhưng ít lần
        when rfm.recency_score <= 2 and rfm.frequency_score >= 3       then 'At risk'            -- từng mua khá nhiều, lâu rồi không quay lại
        when rfm.recency_score <= 2                                    then 'Hibernating'        -- lâu không mua, mua ít
        else 'Needs attention'                                                                   -- ở giữa, cần theo dõi
    end                                                            as rfm_segment,

    coalesce(reviews.review_count, 0)                              as review_count,
    round(reviews.average_review_rating, 2)                        as average_review_rating
-- bắt đầu từ customers và left join mọi thứ, để giữ đủ 7.000 khách kể cả
-- khách chưa mua hay chưa đánh giá
from customers
left join order_metrics
    on customers.customer_key = order_metrics.customer_key
left join rfm
    on customers.customer_key = rfm.customer_key
left join reviews
    on customers.customer_key = reviews.customer_key

-- Chú ý:
-- 1. Định nghĩa: lifetime_revenue là tổng order_total của các đơn tính doanh
--    thu, tức số tiền khách được tính trên hoá đơn, gồm thuế và phí ship.
--    average_order_value và monetary_score dùng cùng cơ sở này. Đây là định
--    nghĩa có chủ đích cho giá trị khách hàng (README, quyết định số 9), khác
--    với recognized_revenue ở fact_sales (sau giảm giá, chưa gồm thuế và phí
--    ship). Tổng: 6,35 triệu so với 5,49 triệu; phần chênh đúng bằng thuế cộng
--    phí ship. Trên dashboard nên đặt tên khác nhau cho hai chỉ số này.
-- 2. Điểm cần sửa: ntile chia đều số khách nên cắt ngang những khách có cùng
--    giá trị. Ví dụ khách cùng có 1 đơn có người được 1 điểm F, có người được 2.
--    Nên dùng ngưỡng cố định hoặc phân vị để khách giống nhau luôn cùng điểm.
