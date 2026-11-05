select * from {{ source('ecommerce_raw', 'shopping_carts') }}
