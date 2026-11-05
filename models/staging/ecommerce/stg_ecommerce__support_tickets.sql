select * from {{ source('ecommerce_raw', 'support_tickets') }}
