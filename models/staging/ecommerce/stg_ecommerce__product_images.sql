with source as (

    select * from {{ source('ecommerce_raw', 'product_images') }}

),

renamed as (

    select
        id             as product_image_id,
        product_id,
        trim(url)      as image_url,
        trim(alt_text) as alt_text,
        sort_order
    from source

)

select * from renamed
