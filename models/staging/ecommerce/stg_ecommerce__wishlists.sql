select * from {{ source('ecommerce_raw', 'wishlists') }}
