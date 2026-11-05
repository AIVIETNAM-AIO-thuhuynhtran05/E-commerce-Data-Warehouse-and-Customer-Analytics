with source as (

    select * from {{ source('ecommerce_raw', 'addresses') }}

),

renamed as (

    select
        id                          as address_id,
        user_id                     as customer_id,
        trim(street_address)        as street_address,
        trim(extended_address)      as extended_address,
        trim(city)                  as city,
        upper(trim(state_province)) as state_province,
        trim(postal_code)           as postal_code,
        country_id,
        is_default_billing,
        is_default_shipping
    from source

)

select * from renamed
