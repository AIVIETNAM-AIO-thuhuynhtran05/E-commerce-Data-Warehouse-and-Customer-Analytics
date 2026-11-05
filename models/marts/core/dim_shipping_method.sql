select
    {{ dbt_utils.generate_surrogate_key(['shipping_method_id']) }} as shipping_method_key,
    shipping_method_id,
    shipping_method_name,
    carrier,
    base_cost,
    estimated_days
from {{ ref('stg_ecommerce__shipping_methods') }}
