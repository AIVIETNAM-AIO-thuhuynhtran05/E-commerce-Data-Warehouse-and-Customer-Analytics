with source as (

    select * from {{ source('ecommerce_raw', 'payments') }}

),

renamed as (

    select
        id                              as payment_id,
        order_id,
        payment_method_id,
        {{ to_money('amount') }}        as payment_amount,
        lower(trim(status))             as payment_status,
        trim(transaction_reference)     as transaction_reference,
        cast(processed_at as timestamp) as processed_at
    from source

)

select * from renamed
