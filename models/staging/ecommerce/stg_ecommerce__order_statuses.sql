with source as (

    select * from {{ source('ecommerce_raw', 'order_statuses') }}

),

renamed as (

    select
        id                       as order_status_id,
        lower(trim(status_name)) as status_name,
        trim(description)        as status_description
    from source

)

select * from renamed
