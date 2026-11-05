with source as (

    select * from {{ source('ecommerce_raw', 'support_tickets') }}

),

renamed as (

    select
        id                            as ticket_id,
        user_id                       as customer_id,
        trim(subject)                 as subject,
        lower(trim(priority))         as priority,
        lower(trim(status))           as ticket_status,
        cast(created_at as timestamp) as created_at
    from source

)

select * from renamed
