select
    id as payment_id,
    order_id,
    payment_method_id,
    cast(processed_at as date) as payment_date,
    amount,
    status,
    transaction_reference
from {{ ref('stg_ecommerce__payments') }}
