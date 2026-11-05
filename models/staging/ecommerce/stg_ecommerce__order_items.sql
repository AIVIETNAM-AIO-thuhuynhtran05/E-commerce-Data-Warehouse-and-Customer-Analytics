with source as (

    select * from {{ source('ecommerce_raw', 'order_items') }}

),

renamed as (

    select
        id                                as order_item_id,
        order_id,
        product_id,
        quantity,
        {{ to_money('unit_price') }}      as unit_price,
        {{ to_money('discount_amount') }} as line_discount_amount,
        {{ to_money('tax_amount') }}      as tax_amount
    from source

)

select * from renamed
