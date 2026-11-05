-- One row per customer who has placed at least one order.

with orders as (

    select * from {{ ref('int_orders__enriched') }}

)

select
    customer_id,
    min(order_date)                                              as first_order_date,
    max(order_date)                                              as last_order_date,
    count(*)                                                     as order_count,
    count(*) filter (where counts_as_revenue)                    as revenue_order_count,
    sum(order_total)                                             as lifetime_order_value,
    sum(case when counts_as_revenue then order_total else 0 end) as lifetime_revenue
from orders
group by customer_id
