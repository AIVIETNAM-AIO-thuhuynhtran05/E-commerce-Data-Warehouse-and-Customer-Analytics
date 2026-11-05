with source as (

    select * from {{ source('ecommerce_raw', 'users') }}

),

renamed as (

    select
        id                            as customer_id,
        trim(first_name)              as first_name,
        trim(last_name)               as last_name,
        lower(trim(email))            as email,
        trim(phone)                   as phone,
        cast(created_at as timestamp) as created_at,
        cast(updated_at as timestamp) as updated_at
    from source

)

select * from renamed
