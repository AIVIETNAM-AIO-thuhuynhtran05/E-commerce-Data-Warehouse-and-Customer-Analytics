with source as (

    select * from {{ source('ecommerce_raw', 'shipping_methods') }}

),

renamed as (

    select
        id                          as shipping_method_id,
        lower(trim(name))           as shipping_method_name,
        trim(carrier)               as carrier,
        {{ to_money('base_cost') }} as base_cost,
        estimated_days
    from source

)

select * from renamed
