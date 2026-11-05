-- Grain: one row per product.

with products as (

    select * from {{ ref('dim_product') }}

),

sales as (

    select
        product_key,
        count(distinct order_id)    as order_count,
        sum(quantity)               as units_sold,
        sum(net_amount)             as net_amount,
        sum(recognized_revenue)     as recognized_revenue,
        sum(refunded_quantity)      as refunded_quantity,
        sum(refunded_amount)        as refunded_amount
    from {{ ref('fact_sales') }}
    group by product_key

),

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
    coalesce(sales.order_count, 0)                                  as order_count,
    coalesce(sales.units_sold, 0)                                   as units_sold,
    coalesce(sales.net_amount, 0)                                   as net_amount,
    coalesce(sales.recognized_revenue, 0)                           as recognized_revenue,
    coalesce(sales.refunded_quantity, 0)                            as refunded_quantity,
    coalesce(sales.refunded_amount, 0)                              as refunded_amount,
    sales.refunded_quantity / nullif(sales.units_sold, 0)           as refund_rate,
    coalesce(reviews.review_count, 0)                               as review_count,
    round(reviews.average_rating, 2)                                as average_rating,
    rank() over (order by coalesce(sales.recognized_revenue, 0) desc) as revenue_rank
from products
left join sales
    on products.product_key = sales.product_key
left join reviews
    on products.product_id = reviews.product_id
