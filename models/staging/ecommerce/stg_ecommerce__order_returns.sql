with source as (

    select * from {{ source('ecommerce_raw', 'order_returns') }}

),

renamed as (

    select
        id                              as return_id,
        order_item_id,
        reason_id                       as return_reason_id,
        quantity                        as returned_quantity,
        lower(trim(status))             as return_status,
        cast(requested_at as timestamp) as requested_at,
        cast(processed_at as timestamp) as processed_at
    from source

)

select * from renamed
