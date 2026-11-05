select
    id as shipment_id,
    order_id,
    cast(shipped_at as date) as shipped_date,
    cast(delivered_at as date) as delivered_date,
    tracking_number
from {{ ref('stg_ecommerce__shipments') }}
