select * from {{ source('ecommerce_raw', 'shipping_methods') }}
