select
    id as customer_id,
    created_at as customer_created_at,
    updated_at as customer_updated_at,
    first_name,
    last_name,
    email,
    phone
from {{ ref('stg_ecommerce__users') }}
