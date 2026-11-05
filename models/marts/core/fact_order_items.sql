select
    order_item_id,
    order_id,
    customer_id,
    product_id,
    order_status_id,
    order_date,
    quantity,
    unit_price,
    discount_amount,
    tax_amount,
    gross_line_amount,
    net_line_amount
from {{ ref('int_order_items_enriched') }}
