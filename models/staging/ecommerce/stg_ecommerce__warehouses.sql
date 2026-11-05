with source as (

    select * from {{ source('ecommerce_raw', 'warehouses') }}

),

renamed as (

    select
        id            as warehouse_id,
        trim(name)    as warehouse_name,
        trim(address) as address,
        trim(city)    as city,
        country_id
    from source

)

select * from renamed
