with source as (

    select * from {{ source('ecommerce_raw', 'support_messages') }}

),

renamed as (

    select
        id                         as message_id,
        ticket_id,
        lower(trim(sender_type))   as sender_type,
        trim(message)              as message_text,
        cast(sent_at as timestamp) as sent_at
    from source

)

select * from renamed
