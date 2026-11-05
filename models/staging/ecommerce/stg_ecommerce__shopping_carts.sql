with source as (

    select * from {{ source('ecommerce_raw', 'shopping_carts') }}

),

renamed as (

    select
        id                            as cart_id,
        user_id                       as customer_id,
        cast(created_at as timestamp) as created_at,
        cast(updated_at as timestamp) as updated_at
    from source

)

select * from renamed
