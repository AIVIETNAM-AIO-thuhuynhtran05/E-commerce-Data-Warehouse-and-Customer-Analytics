select * from {{ source('ecommerce_raw', 'users') }}
