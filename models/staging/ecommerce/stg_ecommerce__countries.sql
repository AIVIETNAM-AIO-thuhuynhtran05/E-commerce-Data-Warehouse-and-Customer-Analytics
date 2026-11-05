with source as (

    select * from {{ source('ecommerce_raw', 'countries') }}

),

renamed as (

    select
        id                as country_id,
        upper(trim(code)) as country_code,
        trim(name)        as country_name
    from source

)

select * from renamed
