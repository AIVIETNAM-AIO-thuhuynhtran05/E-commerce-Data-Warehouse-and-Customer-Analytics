with source as (

    select * from {{ source('ecommerce_raw', 'wishlist_items') }}

),

renamed as (

    select
        id                          as wishlist_item_id,
        wishlist_id,
        product_id,
        cast(added_at as timestamp) as added_at
    from source

)

select * from renamed
