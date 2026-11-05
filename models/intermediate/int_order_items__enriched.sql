-- One row per order item. Adds order context, allocates the order-level
-- discount to lines, and attaches refunded returns.
--
-- Discounts only exist at order level in the source (line discounts are 0),
-- so each line receives a share of the order discount proportional to its
-- gross amount. The allocated discounts of an order sum back to the order
-- discount, up to rounding.

with items as (

    select * from {{ ref('stg_ecommerce__order_items') }}

),

orders as (

    select * from {{ ref('int_orders__enriched') }}

),

refunds as (

    select
        order_item_id,
        sum(returned_quantity) as refunded_quantity
    from {{ ref('stg_ecommerce__order_returns') }}
    where return_status = 'refunded'
    group by order_item_id

),

lines as (

    select
        items.order_item_id,
        items.order_id,
        items.product_id,
        orders.customer_id,
        orders.ordered_at,
        orders.order_date,
        orders.order_status_id,
        orders.counts_as_revenue,
        orders.shipping_address_id,
        orders.shipping_method_id,
        orders.coupon_id,
        items.quantity,
        items.unit_price,
        items.quantity * items.unit_price      as gross_amount,
        items.line_discount_amount,
        items.tax_amount,
        orders.discount_amount                 as order_discount_amount,
        orders.subtotal                        as order_subtotal,
        coalesce(refunds.refunded_quantity, 0) as refunded_quantity
    from items
    inner join orders
        on items.order_id = orders.order_id
    left join refunds
        on items.order_item_id = refunds.order_item_id

),

allocated as (

    select
        *,
        cast(
            line_discount_amount
            + case
                when order_subtotal > 0
                    then order_discount_amount * gross_amount / order_subtotal
                else 0
            end
            as decimal(18, 2)
        ) as discount_amount
    from lines

)

select
    order_item_id,
    order_id,
    product_id,
    customer_id,
    ordered_at,
    order_date,
    order_status_id,
    counts_as_revenue,
    shipping_address_id,
    shipping_method_id,
    coupon_id,
    quantity,
    unit_price,
    gross_amount,
    discount_amount,
    gross_amount - discount_amount                         as net_amount,
    tax_amount,
    refunded_quantity,
    cast(unit_price * refunded_quantity as decimal(18, 2)) as refunded_amount,
    case
        when counts_as_revenue then gross_amount - discount_amount
        else 0
    end                                                    as recognized_revenue
from allocated
