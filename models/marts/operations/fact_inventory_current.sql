-- Grain: one row per inventory record. Current state only; the source has
-- no history, and some product/warehouse pairs appear in several records.

with inventory as (

    select * from {{ ref('stg_ecommerce__product_inventories') }}

),

warehouses as (

    select * from {{ ref('stg_ecommerce__warehouses') }}

)

select
    inventory.inventory_id,
    {{ dbt_utils.generate_surrogate_key(['inventory.product_id']) }} as product_key,
    inventory.warehouse_id,
    warehouses.warehouse_name,
    warehouses.city                                                  as warehouse_city,
    inventory.quantity_on_hand,
    inventory.quantity_reserved,
    inventory.quantity_on_hand - inventory.quantity_reserved         as quantity_available,
    inventory.reorder_level,
    inventory.quantity_on_hand - inventory.quantity_reserved
        <= inventory.reorder_level                                   as needs_reorder
from inventory
left join warehouses
    on inventory.warehouse_id = warehouses.warehouse_id
