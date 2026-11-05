select * from {{ source('ecommerce_raw', 'payment_methods') }}
