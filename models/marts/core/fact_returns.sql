select
    r.id as return_id,
    r.order_item_id,
    oi.order_id,
    oi.product_id,
    o.user_id as customer_id,
    cast(r.requested_at as date) as requested_date,
    cast(r.processed_at as date) as processed_date,
    r.quantity,
    r.reason_id,
    rr.reason_text,
    r.status
from {{ ref('stg_ecommerce__order_returns') }} as r
left join {{ ref('stg_ecommerce__order_items') }} as oi
    on r.order_item_id = oi.id
left join {{ ref('stg_ecommerce__orders') }} as o
    on oi.order_id = o.id
left join {{ ref('stg_ecommerce__return_reasons') }} as rr
    on r.reason_id = rr.id
