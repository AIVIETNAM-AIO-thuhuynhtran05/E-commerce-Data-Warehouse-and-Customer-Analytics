select * from {{ source('ecommerce_raw', 'order_statuses') }}
