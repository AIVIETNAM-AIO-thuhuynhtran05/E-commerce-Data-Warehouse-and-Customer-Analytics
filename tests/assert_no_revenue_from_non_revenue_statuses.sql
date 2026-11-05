-- Pending, cancelled and refunded orders must not contribute recognized revenue.

select
    sales.order_item_id,
    statuses.status_name,
    sales.recognized_revenue
from {{ ref('fact_sales') }} as sales
inner join {{ ref('dim_order_status') }} as statuses
    on sales.order_status_key = statuses.order_status_key
where not statuses.counts_as_revenue
  and sales.recognized_revenue <> 0
