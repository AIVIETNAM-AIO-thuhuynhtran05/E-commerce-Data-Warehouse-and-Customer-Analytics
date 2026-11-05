with source as (

    select * from {{ source('ecommerce_raw', 'brands') }}

),

renamed as (

    select
        id                as brand_id,
        trim(name)        as brand_name,
        trim(description) as brand_description,
        trim(logo_url)    as logo_url
    from source

)

select * from renamed
