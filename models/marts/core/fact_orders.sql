select
    id as order_id,
    user_id as customer_id,
    cast(created_at as date) as order_date,
    order_status_id,
    billing_address_id,
    shipping_address_id,
    coupon_id,
    shipping_method_id,
    subtotal,
    discount_amount,
    tax_amount,
    shipping_cost,
    total
from {{ ref('stg_ecommerce__orders') }}
