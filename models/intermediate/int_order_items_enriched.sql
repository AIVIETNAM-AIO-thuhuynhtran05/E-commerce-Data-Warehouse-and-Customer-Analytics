select
    oi.id as order_item_id,
    oi.order_id,
    o.user_id as customer_id,
    cast(o.created_at as date) as order_date,
    o.order_status_id,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    oi.tax_amount,
    oi.quantity * oi.unit_price as gross_line_amount,
    oi.quantity * oi.unit_price - coalesce(oi.discount_amount, 0) as net_line_amount
from {{ ref('stg_ecommerce__order_items') }} as oi
inner join {{ ref('stg_ecommerce__orders') }} as o
    on oi.order_id = o.id
