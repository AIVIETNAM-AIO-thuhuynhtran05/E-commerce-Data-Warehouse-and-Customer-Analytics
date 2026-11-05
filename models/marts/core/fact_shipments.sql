-- Grain: one row per shipment (one shipment per order in this dataset).

with shipments as (

    select * from {{ ref('stg_ecommerce__shipments') }}

),

orders as (

    select order_id, customer_id, shipping_method_id, ordered_at
    from {{ ref('stg_ecommerce__orders') }}

),

shipping_methods as (

    select shipping_method_id, estimated_days from {{ ref('stg_ecommerce__shipping_methods') }}

)

select
    shipments.shipment_id,
    shipments.order_id,
    {{ date_key('shipments.shipped_at') }}                                as shipped_date_key,
    {{ date_key('shipments.delivered_at') }}                              as delivered_date_key,
    {{ dbt_utils.generate_surrogate_key(['orders.customer_id']) }}        as customer_key,
    {{ dbt_utils.generate_surrogate_key(['orders.shipping_method_id']) }} as shipping_method_key,
    shipments.tracking_number,
    date_diff('day', cast(orders.ordered_at as date), cast(shipments.shipped_at as date))
                                                                          as days_to_ship,
    date_diff('day', cast(shipments.shipped_at as date), cast(shipments.delivered_at as date))
                                                                          as days_in_transit,
    date_diff('day', cast(shipments.shipped_at as date), cast(shipments.delivered_at as date))
        <= shipping_methods.estimated_days                                as is_delivered_on_time
from shipments
left join orders
    on shipments.order_id = orders.order_id
left join shipping_methods
    on orders.shipping_method_id = shipping_methods.shipping_method_id
