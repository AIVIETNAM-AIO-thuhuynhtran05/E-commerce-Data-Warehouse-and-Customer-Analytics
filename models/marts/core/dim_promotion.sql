-- Discount coupons plus one "No promotion" row (coupon_id = -1), so orders
-- without a coupon still join to the dimension instead of having a null key.

with coupons as (

    select
        coupon_id,
        coupon_code,
        discount_type,
        discount_value,
        min_purchase_amount,
        is_active,
        starts_at,
        ends_at
    from {{ ref('stg_ecommerce__discount_coupons') }}

),

no_promotion as (

    select
        -1                         as coupon_id,
        'NO PROMOTION'             as coupon_code,
        'none'                     as discount_type,
        cast(0 as decimal(18, 2))  as discount_value,
        cast(0 as decimal(18, 2))  as min_purchase_amount,
        false                      as is_active,
        cast(null as timestamp)    as starts_at,
        cast(null as timestamp)    as ends_at

),

unioned as (

    select * from coupons
    union all
    select * from no_promotion

)

select
    {{ dbt_utils.generate_surrogate_key(['coupon_id']) }} as promotion_key,
    *,
    coupon_id <> -1                                       as has_promotion
from unioned
