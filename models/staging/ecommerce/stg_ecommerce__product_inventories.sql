with source as (

    select * from {{ source('ecommerce_raw', 'product_inventories') }}

),

renamed as (

    select
        id                as inventory_id,
        product_id,
        warehouse_id,
        quantity_on_hand,
        quantity_reserved,
        reorder_level
    from source

)

select * from renamed
