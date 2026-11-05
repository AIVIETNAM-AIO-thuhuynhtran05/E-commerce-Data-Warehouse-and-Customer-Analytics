with customers as (

    select * from {{ ref('stg_ecommerce__users') }}

),

order_history as (

    select * from {{ ref('int_customers__order_history') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['customers.customer_id']) }} as customer_key,
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    customers.email,
    customers.phone,
    customers.created_at                                      as signed_up_at,
    cast(customers.created_at as date)                        as signup_date,
    order_history.first_order_date,
    date_trunc('month', order_history.first_order_date)       as first_order_cohort_month,
    order_history.first_order_date is not null                as has_ordered
from customers
left join order_history
    on customers.customer_id = order_history.customer_id
