select * from {{ source('ecommerce_raw', 'wishlist_items') }}
