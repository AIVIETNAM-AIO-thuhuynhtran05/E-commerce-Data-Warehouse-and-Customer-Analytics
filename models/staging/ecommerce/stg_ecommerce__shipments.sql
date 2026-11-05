with source as (

    select * from {{ source('ecommerce_raw', 'shipments') }}

),

renamed as (

    select
        id                              as shipment_id,
        order_id,
        trim(tracking_number)           as tracking_number,
        cast(shipped_at as timestamp)   as shipped_at,
        cast(delivered_at as timestamp) as delivered_at
    from source

)

select * from renamed
