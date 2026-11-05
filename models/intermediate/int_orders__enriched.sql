-- One row per order with status business rules, item counts and payments.
-- This is the single place where "does this order count as revenue?" is decided.

with orders as (

    select * from {{ ref('stg_ecommerce__orders') }}

),

statuses as (

    select * from {{ ref('stg_ecommerce__order_statuses') }}

),

status_rules as (

    select * from {{ ref('order_status_mapping') }}

),

items as (

    select
        order_id,
        count(*)      as item_line_count,
        sum(quantity) as item_quantity
    from {{ ref('stg_ecommerce__order_items') }}
    group by order_id

),

payments as (

    select * from {{ ref('int_orders__payments_agg') }}

)

select
    orders.order_id,
    orders.customer_id,
    orders.ordered_at,
    cast(orders.ordered_at as date)                as order_date,
    orders.order_status_id,
    statuses.status_name,
    status_rules.fulfillment_stage,
    status_rules.counts_as_revenue,
    orders.billing_address_id,
    orders.shipping_address_id,
    orders.shipping_method_id,
    orders.coupon_id,
    coalesce(items.item_line_count, 0)             as item_line_count,
    coalesce(items.item_quantity, 0)               as item_quantity,
    items.order_id is not null                     as has_items,
    orders.subtotal,
    orders.discount_amount,
    orders.tax_amount,
    orders.shipping_cost,
    orders.order_total,
    coalesce(payments.payment_count, 0)            as payment_count,
    coalesce(payments.completed_payment_amount, 0) as completed_payment_amount,
    coalesce(payments.refunded_payment_amount, 0)  as refunded_payment_amount,
    payments.last_completed_payment_at
from orders
left join statuses
    on orders.order_status_id = statuses.order_status_id
left join status_rules
    on statuses.status_name = status_rules.status_name
left join items
    on orders.order_id = items.order_id
left join payments
    on orders.order_id = payments.order_id
