with source as (

    select * from {{ source('ecommerce_raw', 'cart_items') }}

),

renamed as (

    select
        id                          as cart_item_id,
        cart_id,
        product_id,
        quantity,
        cast(added_at as timestamp) as added_at
    from source

)

select * from renamed
