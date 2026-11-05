-- Every order should contain at least one product. The generated source has
-- shipping-only orders (subtotal 0, total = shipping), so this is a warning:
-- it reports the issue on every build without blocking the pipeline.

{{ config(severity = 'warn') }}

select
    order_id,
    subtotal,
    shipping_cost,
    order_total
from {{ ref('fact_orders') }}
where not has_items
