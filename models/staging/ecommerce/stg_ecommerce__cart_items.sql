select * from {{ source('ecommerce_raw', 'cart_items') }}
