-- A refund can never exceed what the customer paid for the line. Refunds are
-- valued at the net unit price (after the allocated order discount), so the
-- refunded amount of a line is at most its net_amount.

select
    order_item_id,
    quantity,
    net_amount,
    refunded_quantity,
    refunded_amount
from {{ ref('fact_sales') }}
where refunded_amount > net_amount + 0.01
