select
    id as order_status_id,
    status_name,
    description
from {{ ref('stg_ecommerce__order_statuses') }}
