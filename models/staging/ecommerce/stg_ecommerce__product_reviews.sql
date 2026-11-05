select * from {{ source('ecommerce_raw', 'product_reviews') }}
