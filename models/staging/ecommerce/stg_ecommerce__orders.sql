select * from {{ source('ecommerce_raw', 'orders') }}
