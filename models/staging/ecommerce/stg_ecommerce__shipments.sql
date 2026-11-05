select * from {{ source('ecommerce_raw', 'shipments') }}
