-- Grain: one row per return request.

with returns as (

    select * from {{ ref('stg_ecommerce__order_returns') }}

),

items as (

    select order_item_id, order_id, product_id, customer_id, quantity, net_amount
    from {{ ref('int_order_items__enriched') }}

),

reasons as (

    select * from {{ ref('stg_ecommerce__return_reasons') }}

)

select
    returns.return_id,
    returns.order_item_id,
    items.order_id,
    {{ date_key('returns.requested_at') }}                         as requested_date_key,
    {{ date_key('returns.processed_at') }}                         as processed_date_key,
    {{ dbt_utils.generate_surrogate_key(['items.customer_id']) }}  as customer_key,
    {{ dbt_utils.generate_surrogate_key(['items.product_id']) }}   as product_key,
    reasons.return_reason,
    returns.return_status,
    returns.returned_quantity,
    -- Amount the customer paid for the returned units: net unit price after the
    -- allocated discount, before tax, without shipping.
    cast(
        items.net_amount / nullif(items.quantity, 0) * returns.returned_quantity
        as decimal(18, 2)
    )                                                              as returned_amount
from returns
left join items
    on returns.order_item_id = items.order_item_id
left join reasons
    on returns.return_reason_id = reasons.return_reason_id
