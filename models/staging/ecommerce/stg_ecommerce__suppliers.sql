select * from {{ source('ecommerce_raw', 'suppliers') }}
