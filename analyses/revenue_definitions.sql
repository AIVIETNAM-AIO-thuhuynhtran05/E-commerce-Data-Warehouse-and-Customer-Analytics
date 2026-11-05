-- The same dataset gives different "revenue" figures depending on the definition.
-- The project uses recognized_revenue (row 4) as its revenue metric.

select 'All order totals, any status' as definition, sum(order_total) as amount
from {{ ref('fact_orders') }}

union all

select 'Completed payments', sum(payment_amount)
from {{ ref('fact_payments') }}
where payment_status = 'completed'

union all

select 'Net sales, any status (before tax and shipping)', sum(net_amount)
from {{ ref('fact_sales') }}

union all

select 'Recognized revenue (paid, shipped, delivered; before tax and shipping)', sum(recognized_revenue)
from {{ ref('fact_sales') }}

order by amount desc
