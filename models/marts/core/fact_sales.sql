-- Grain: one row per order item.
-- Main fact table of the sales star schema. Every measure here is additive at
-- line level. Order-level amounts (shipping, order total) live in fact_orders;
-- do not join them in here, or they repeat once per line (fan-out).

with lines as (

    select * from {{ ref('int_order_items__enriched') }}

),

geography as (

    select address_id, geography_key from {{ ref('int_addresses__geography') }}

)

select
    -- keys
    lines.order_item_id,
    lines.order_id,
    {{ date_key('lines.order_date') }}                                            as order_date_key,
    {{ dbt_utils.generate_surrogate_key(['lines.customer_id']) }}                 as customer_key,
    {{ dbt_utils.generate_surrogate_key(['lines.product_id']) }}                  as product_key,
    geography.geography_key                                                       as ship_to_geography_key,
    {{ dbt_utils.generate_surrogate_key(['coalesce(lines.coupon_id, -1)']) }}     as promotion_key,
    {{ dbt_utils.generate_surrogate_key(['lines.shipping_method_id']) }}          as shipping_method_key,
    {{ dbt_utils.generate_surrogate_key(['lines.order_status_id']) }}             as order_status_key,

    -- measures
    lines.quantity,
    lines.unit_price,
    lines.gross_amount,
    lines.discount_amount,
    lines.net_amount,
    lines.tax_amount,
    lines.recognized_revenue,
    lines.refunded_quantity,
    lines.refunded_amount
from lines
left join geography
    on lines.shipping_address_id = geography.address_id
