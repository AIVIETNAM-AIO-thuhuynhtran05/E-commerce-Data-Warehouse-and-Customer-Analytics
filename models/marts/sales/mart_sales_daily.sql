-- Grain: one row per order date and product category.
-- Line measures come from fact_sales; order counts are distinct orders, so
-- they are not additive across categories (an order can span categories).

with sales as (

    select * from {{ ref('fact_sales') }}

),

dates as (

    select * from {{ ref('dim_date') }}

),

products as (

    select product_key, category_name from {{ ref('dim_product') }}

)

select
    dates.date_day                                  as order_date,
    dates.year_month,
    dates.is_weekend,
    products.category_name,
    count(distinct sales.order_id)                  as order_count,
    sum(sales.quantity)                             as units_sold,
    sum(sales.gross_amount)                         as gross_amount,
    sum(sales.discount_amount)                      as discount_amount,
    sum(sales.net_amount)                           as net_amount,
    sum(sales.recognized_revenue)                   as recognized_revenue,
    sum(sales.refunded_amount)                      as refunded_amount
from sales
inner join dates
    on sales.order_date_key = dates.date_key
inner join products
    on sales.product_key = products.product_key
group by all
