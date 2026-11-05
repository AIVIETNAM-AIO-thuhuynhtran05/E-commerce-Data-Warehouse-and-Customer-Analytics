select
    i.id as inventory_id,
    i.product_id,
    i.warehouse_id,
    w.name as warehouse_name,
    i.quantity_on_hand,
    i.quantity_reserved,
    i.quantity_on_hand - i.quantity_reserved as quantity_available,
    i.reorder_level
from {{ ref('stg_ecommerce__product_inventories') }} as i
left join {{ ref('stg_ecommerce__warehouses') }} as w
    on i.warehouse_id = w.id
