-- Is product rating related to sales? Result: no.
-- Rows 1-3: correlations across 400 products. Row 4: share of reviews written
-- by a customer who has an order containing that product. Row 5: reviews dated
-- before the product's created_at.

with products as (

    select * from {{ ref('mart_product_performance') }}

),

reviews as (

    select * from {{ ref('stg_ecommerce__product_reviews') }}

),

order_items as (

    select customer_id, product_id from {{ ref('int_order_items__enriched') }}

)

select 'Pearson: average_rating vs recognized_revenue' as metric,
       round(corr(average_rating, recognized_revenue), 3) as value
from products
union all
select 'Pearson: average_rating vs refund_rate', round(corr(average_rating, refund_rate), 3)
from products
union all
select 'Pearson: review_count vs units_sold', round(corr(review_count, units_sold), 3)
from products
union all
select 'Share of reviews written by a buyer of the product',
       round(avg(case when exists (
           select 1 from order_items
           where order_items.customer_id = reviews.customer_id
             and order_items.product_id = reviews.product_id
       ) then 1 else 0 end), 3)
from reviews
union all
select 'Reviews dated before product created_at',
       count(*) filter (where reviews.reviewed_at < products_src.product_created_at)
from reviews
inner join {{ ref('dim_product') }} as products_src
    on reviews.product_id = products_src.product_id
