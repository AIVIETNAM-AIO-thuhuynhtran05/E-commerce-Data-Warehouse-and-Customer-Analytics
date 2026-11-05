with source as (

    select * from {{ source('ecommerce_raw', 'suppliers') }}

),

renamed as (

    select
        id                 as supplier_id,
        trim(name)         as supplier_name,
        trim(contact_name) as contact_name,
        lower(trim(email)) as email,
        trim(phone)        as phone,
        trim(website)      as website
    from source

)

select * from renamed
