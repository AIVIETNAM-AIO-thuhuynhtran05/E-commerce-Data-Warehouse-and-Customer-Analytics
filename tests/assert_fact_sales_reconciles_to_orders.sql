-- Line-level sales must add back up to the order header.
-- Gross must equal the order subtotal, and allocated discounts must equal the
-- order discount within a rounding tolerance of one cent per line.
-- Returns the orders that do not reconcile; the test passes when none do.

with lines as (

    select
        order_id,
        count(*)             as line_count,
        sum(gross_amount)    as gross_amount,
        sum(discount_amount) as discount_amount
    from {{ ref('fact_sales') }}
    group by order_id

)

select
    orders.order_id,
    orders.subtotal,
    lines.gross_amount,
    orders.discount_amount,
    lines.discount_amount as allocated_discount_amount
from {{ ref('fact_orders') }} as orders
inner join lines
    on orders.order_id = lines.order_id
where abs(orders.subtotal - lines.gross_amount) > 0.01
   or abs(orders.discount_amount - lines.discount_amount) > 0.01 * lines.line_count
