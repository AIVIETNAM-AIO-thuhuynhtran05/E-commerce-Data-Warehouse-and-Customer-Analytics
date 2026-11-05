with source as (

    select * from {{ source('ecommerce_raw', 'orders') }}

),

renamed as (

    select
        id                                as order_id,
        user_id                           as customer_id,
        order_status_id,
        billing_address_id,
        shipping_address_id,
        shipping_method_id,
        coupon_id,
        {{ to_money('subtotal') }}        as subtotal,
        {{ to_money('discount_amount') }} as discount_amount,
        {{ to_money('tax_amount') }}      as tax_amount,
        {{ to_money('shipping_cost') }}   as shipping_cost,
        {{ to_money('total') }}           as order_total,
        cast(created_at as timestamp)     as ordered_at
    from source

)

select * from renamed
