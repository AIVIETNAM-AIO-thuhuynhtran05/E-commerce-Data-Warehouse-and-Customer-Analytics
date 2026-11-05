with source as (

    select * from {{ source('ecommerce_raw', 'product_attribute_values') }}

),

renamed as (

    select
        id           as attribute_value_id,
        product_id,
        attribute_id,
        trim(value)  as attribute_value
    from source

)

select * from renamed
