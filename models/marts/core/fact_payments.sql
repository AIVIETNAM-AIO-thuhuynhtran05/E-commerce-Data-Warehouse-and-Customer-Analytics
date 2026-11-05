-- Grain: one row per payment transaction.

with payments as (

    select * from {{ ref('stg_ecommerce__payments') }}

),

orders as (

    select order_id, customer_id from {{ ref('stg_ecommerce__orders') }}

)

select
    payments.payment_id,
    payments.order_id,
    {{ date_key('payments.processed_at') }}                                as payment_date_key,
    {{ dbt_utils.generate_surrogate_key(['orders.customer_id']) }}         as customer_key,
    {{ dbt_utils.generate_surrogate_key(['payments.payment_method_id']) }} as payment_method_key,
    payments.payment_status,
    payments.transaction_reference,
    payments.payment_amount
from payments
left join orders
    on payments.order_id = orders.order_id
