with source as (

    select * from {{ source('ecommerce_raw', 'categories') }}

),

renamed as (

    select
        id                                                       as category_id,
        trim(name)                                               as category_name,
        trim(description)                                        as category_description,
        lower(trim(slug))                                        as category_slug,
        try_cast(nullif(trim(parent_category_id), '') as bigint) as parent_category_id
    from source

)

select * from renamed
