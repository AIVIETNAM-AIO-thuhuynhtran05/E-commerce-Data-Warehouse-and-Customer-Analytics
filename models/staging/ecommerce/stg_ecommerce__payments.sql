select * from {{ source('ecommerce_raw', 'payments') }}
