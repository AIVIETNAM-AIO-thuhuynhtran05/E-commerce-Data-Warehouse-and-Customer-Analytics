-- Grain: one row per order.
-- Holds order-level amounts (shipping, tax, total) that cannot be split
-- cleanly across order items.

with orders as (

    select * from {{ ref('int_orders__enriched') }}

),

geography as (

    select address_id, geography_key from {{ ref('int_addresses__geography') }}

)

select
    -- keys
    orders.order_id,
    {{ date_key('orders.order_date') }}                                           as order_date_key,
    {{ dbt_utils.generate_surrogate_key(['orders.customer_id']) }}                as customer_key,
    geography.geography_key                                                       as ship_to_geography_key,
    {{ dbt_utils.generate_surrogate_key(['coalesce(orders.coupon_id, -1)']) }}    as promotion_key,
    {{ dbt_utils.generate_surrogate_key(['orders.shipping_method_id']) }}         as shipping_method_key,
    {{ dbt_utils.generate_surrogate_key(['orders.order_status_id']) }}            as order_status_key,

    -- flags
    orders.counts_as_revenue,
    orders.has_items,

    -- measures
    orders.item_line_count,
    orders.item_quantity,
    orders.subtotal,
    orders.discount_amount,
    orders.tax_amount,
    orders.shipping_cost,
    orders.order_total,
    orders.completed_payment_amount
from orders
left join geography
    on orders.shipping_address_id = geography.address_id
