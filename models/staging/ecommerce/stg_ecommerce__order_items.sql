select * from {{ source('ecommerce_raw', 'order_items') }}
