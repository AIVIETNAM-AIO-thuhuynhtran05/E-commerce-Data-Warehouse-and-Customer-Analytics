-- Payments rolled up to order grain, so they can be joined to orders
-- without multiplying rows.

with payments as (

    select * from {{ ref('stg_ecommerce__payments') }}

)

select
    order_id,
    count(*)                                                                    as payment_count,
    sum(case when payment_status = 'completed' then payment_amount else 0 end) as completed_payment_amount,
    sum(case when payment_status = 'refunded' then payment_amount else 0 end)  as refunded_payment_amount,
    count(*) filter (where payment_status = 'failed')                          as failed_payment_count,
    max(processed_at) filter (where payment_status = 'completed')              as last_completed_payment_at
from payments
group by order_id
