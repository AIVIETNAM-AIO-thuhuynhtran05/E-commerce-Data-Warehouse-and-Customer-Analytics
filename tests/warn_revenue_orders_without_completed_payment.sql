-- Revenue is recognized from the order status (paid, shipped, delivered), not
-- from the payments table. Some of these orders have no completed payment.
-- This project keeps them in revenue by design (see README, Design decisions),
-- so this is a warning: it reports how many there are on every build without
-- blocking the pipeline.

{{ config(severity = 'warn') }}

select
    order_id,
    status_name,
    order_total,
    payment_count,
    completed_payment_amount
from {{ ref('int_orders__enriched') }}
where counts_as_revenue
  and completed_payment_amount = 0
