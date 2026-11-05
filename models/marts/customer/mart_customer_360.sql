with order_metrics as (
    select
        customer_id,
        count(*) as order_count,
        sum(total) as lifetime_order_value,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date
    from {{ ref('fact_orders') }}
    group by customer_id
),
review_metrics as (
    select
        user_id as customer_id,
        count(*) as review_count,
        avg(rating) as average_review_rating
    from {{ ref('stg_ecommerce__product_reviews') }}
    group by user_id
)
select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.customer_created_at,
    coalesce(o.order_count, 0) as order_count,
    coalesce(o.lifetime_order_value, 0) as lifetime_order_value,
    o.first_order_date,
    o.most_recent_order_date,
    coalesce(r.review_count, 0) as review_count,
    r.average_review_rating
from {{ ref('dim_customer') }} as c
left join order_metrics as o
    on c.customer_id = o.customer_id
left join review_metrics as r
    on c.customer_id = r.customer_id
