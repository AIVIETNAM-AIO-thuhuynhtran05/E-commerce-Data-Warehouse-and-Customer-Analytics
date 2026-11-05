select * from {{ source('ecommerce_raw', 'addresses') }}
