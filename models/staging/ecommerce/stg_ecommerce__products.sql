with source as (

    select * from {{ source('ecommerce_raw', 'products') }}

),

renamed as (

    select
        id                                 as product_id,
        upper(trim(sku))                   as sku,
        trim(name)                         as product_name,
        trim(description)                  as product_description,
        lower(trim(slug))                  as product_slug,
        brand_id,
        category_id,
        {{ to_money('price') }}            as price,
        {{ to_money('compare_at_price') }} as compare_at_price,
        is_active,
        cast(created_at as timestamp)      as created_at
    from source

)

select * from renamed
