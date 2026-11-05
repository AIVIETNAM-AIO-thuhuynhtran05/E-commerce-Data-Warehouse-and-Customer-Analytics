with source as (

    select * from {{ source('ecommerce_raw', 'discount_coupons') }}

),

renamed as (

    select
        id                                    as coupon_id,
        upper(trim(code))                     as coupon_code,
        lower(trim(discount_type))            as discount_type,
        {{ to_money('discount_value') }}      as discount_value,
        {{ to_money('min_purchase_amount') }} as min_purchase_amount,
        is_active,
        cast(starts_at as timestamp)          as starts_at,
        cast(ends_at as timestamp)            as ends_at
    from source

)

select * from renamed
