select * from {{ source('ecommerce_raw', 'discount_coupons') }}
