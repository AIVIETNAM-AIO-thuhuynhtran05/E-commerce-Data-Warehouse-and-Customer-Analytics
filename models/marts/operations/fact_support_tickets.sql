select
    id as support_ticket_id,
    user_id as customer_id,
    cast(created_at as date) as created_date,
    priority,
    status,
    subject
from {{ ref('stg_ecommerce__support_tickets') }}
