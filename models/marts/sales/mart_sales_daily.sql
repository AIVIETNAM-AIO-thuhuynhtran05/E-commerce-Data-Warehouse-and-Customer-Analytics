-- =============================================================================
-- mart_sales_daily
-- =============================================================================
-- Grain: mỗi ngày đặt đơn và mỗi danh mục sản phẩm một dòng, 29.865 dòng
-- (2021-01-01 đến 2025-12-31, 22 danh mục).
--
-- Bảng tổng hợp sẵn cho dashboard doanh số theo ngày. Thay vì để dashboard tự
-- join fact_sales với dim_date, dim_product rồi group by mỗi lần mở, bảng này
-- tính sẵn một lần khi chạy dbt.
--
-- Đã kiểm tra: tổng recognized_revenue và gross_amount ở đây khớp tuyệt đối
-- với fact_sales, tức không dòng nào bị mất khi join.
-- =============================================================================

with sales as (

    select * from {{ ref('fact_sales') }}

),

dates as (

    select * from {{ ref('dim_date') }}

),

-- chỉ cần danh mục của sản phẩm
products as (

    select product_key, category_name from {{ ref('dim_product') }}

)

select
    -- các cột để nhóm (dimension) -------------------------------------------
    dates.date_day                                  as order_date,
    dates.year_month,
    dates.is_weekend,
    products.category_name,

    -- các số đo ---------------------------------------------------------------
    -- count(distinct): một đơn có nhiều dòng sản phẩm, đếm thường sẽ đếm trùng.
    -- Chú ý: order_count không cộng được qua các danh mục, vì một đơn có thể
    -- có sản phẩm thuộc nhiều danh mục. Muốn tổng số đơn trong ngày thì đếm
    -- lại từ fact_orders.
    count(distinct sales.order_id)                  as order_count,
    sum(sales.quantity)                             as units_sold,
    sum(sales.gross_amount)                         as gross_amount,
    sum(sales.discount_amount)                      as discount_amount,
    sum(sales.net_amount)                           as net_amount,
    sum(sales.recognized_revenue)                   as recognized_revenue,
    -- tiền hoàn được ghi vào ngày đặt đơn, không phải ngày hoàn tiền
    sum(sales.refunded_amount)                      as refunded_amount
from sales
-- inner join: mọi dòng bán đều có ngày và sản phẩm hợp lệ (đã có test
-- relationships), nên inner join không làm mất dòng
inner join dates
    on sales.order_date_key = dates.date_key
inner join products
    on sales.product_key = products.product_key
-- group by all: DuckDB tự group theo mọi cột không phải hàm tổng hợp
-- (order_date, year_month, is_weekend, category_name)
group by all
