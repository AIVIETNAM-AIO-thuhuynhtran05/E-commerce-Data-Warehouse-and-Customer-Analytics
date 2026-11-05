select * from {{ source('ecommerce_raw', 'warehouses') }}
