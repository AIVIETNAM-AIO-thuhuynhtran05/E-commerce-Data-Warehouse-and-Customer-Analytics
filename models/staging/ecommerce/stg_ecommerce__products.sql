select * from {{ source('ecommerce_raw', 'products') }}
