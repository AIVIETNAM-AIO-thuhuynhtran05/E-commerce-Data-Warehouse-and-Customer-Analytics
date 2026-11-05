select * from {{ source('ecommerce_raw', 'audit_logs') }}
