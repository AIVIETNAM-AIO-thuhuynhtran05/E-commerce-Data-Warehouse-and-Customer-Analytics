select * from {{ source('ecommerce_raw', 'categories') }}
