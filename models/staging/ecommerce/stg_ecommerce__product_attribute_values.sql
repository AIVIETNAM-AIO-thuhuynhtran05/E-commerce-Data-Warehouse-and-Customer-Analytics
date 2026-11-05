select * from {{ source('ecommerce_raw', 'product_attribute_values') }}
