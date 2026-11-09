-- =============================================================================
-- mart_product_performance
-- =============================================================================
-- Grain: mỗi sản phẩm một dòng, 400 dòng.
--
-- Bảng tổng hợp hiệu quả của từng sản phẩm: bán được bao nhiêu, doanh thu,
-- tỷ lệ trả hàng, điểm đánh giá, xếp hạng doanh thu. Dùng cho báo cáo
-- "top sản phẩm" hay "sản phẩm bị trả nhiều".
-- =============================================================================

-- Thông tin sản phẩm, danh mục, thương hiệu.
with products as (

    select * from {{ ref('dim_product') }}

),

-- Gộp fact_sales về cấp sản phẩm (mỗi sản phẩm một dòng) trước khi join,
-- để phép join với products là 1-1.
sales as (

    select
        product_key,
        count(distinct order_id)    as order_count,  -- số đơn có sản phẩm này
        sum(quantity)               as units_sold,
        sum(net_amount)             as net_amount,
        sum(recognized_revenue)     as recognized_revenue,
        sum(refunded_quantity)      as refunded_quantity,
        sum(refunded_amount)        as refunded_amount
    from {{ ref('fact_sales') }}
    group by product_key

),

-- Gộp đánh giá về cấp sản phẩm, cùng lý do.
reviews as (

    select
        product_id,
        count(*)    as review_count,
        avg(rating) as average_rating
    from {{ ref('stg_ecommerce__product_reviews') }}
    group by product_id

)

select
    products.product_key,
    products.product_id,
    products.sku,
    products.product_name,
    products.category_name,
    products.brand_name,
    products.current_price,
    products.is_active,

    -- sản phẩm chưa bán được gì thì left join trả về null, đổi thành 0
    coalesce(sales.order_count, 0)                                  as order_count,
    coalesce(sales.units_sold, 0)                                   as units_sold,
    coalesce(sales.net_amount, 0)                                   as net_amount,
    coalesce(sales.recognized_revenue, 0)                           as recognized_revenue,
    coalesce(sales.refunded_quantity, 0)                            as refunded_quantity,
    coalesce(sales.refunded_amount, 0)                              as refunded_amount,

    -- tỷ lệ trả hàng = số lượng đã hoàn / số lượng bán.
    -- nullif: sản phẩm chưa bán thì ra null thay vì lỗi chia cho 0.
    sales.refunded_quantity / nullif(sales.units_sold, 0)           as refund_rate,

    coalesce(reviews.review_count, 0)                               as review_count,
    round(reviews.average_rating, 2)                                as average_rating,

    -- xếp hạng theo doanh thu, 1 là cao nhất.
    -- rank(): các sản phẩm bằng doanh thu nhau được cùng hạng, hạng tiếp theo
    -- bị nhảy cóc (ví dụ 1, 2, 2, 4).
    rank() over (order by coalesce(sales.recognized_revenue, 0) desc) as revenue_rank
-- bắt đầu từ products để giữ cả sản phẩm chưa bán được
from products
left join sales
    on products.product_key = sales.product_key
-- reviews nối bằng product_id (natural key) vì bảng review chưa có product_key
left join reviews
    on products.product_id = reviews.product_id
