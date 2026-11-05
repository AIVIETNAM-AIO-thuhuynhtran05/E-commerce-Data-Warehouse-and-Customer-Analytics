with source as (

    select * from {{ source('ecommerce_raw', 'product_attributes') }}

),

renamed as (

    select
        id                as attribute_id,
        lower(trim(name)) as attribute_name,
        lower(trim(type)) as attribute_type
    from source

)

select * from renamed
