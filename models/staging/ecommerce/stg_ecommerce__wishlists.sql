with source as (

    select * from {{ source('ecommerce_raw', 'wishlists') }}

),

renamed as (

    select
        id                            as wishlist_id,
        user_id                       as customer_id,
        trim(name)                    as wishlist_name,
        cast(created_at as timestamp) as created_at
    from source

)

select * from renamed
