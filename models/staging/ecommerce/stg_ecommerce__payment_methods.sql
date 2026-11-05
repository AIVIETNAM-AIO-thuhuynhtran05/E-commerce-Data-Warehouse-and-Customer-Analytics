with source as (

    select * from {{ source('ecommerce_raw', 'payment_methods') }}

),

renamed as (

    select
        id                as payment_method_id,
        lower(trim(name)) as payment_method_name
    from source

)

select * from renamed
