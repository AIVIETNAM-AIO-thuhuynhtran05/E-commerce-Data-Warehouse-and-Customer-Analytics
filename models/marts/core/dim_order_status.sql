with statuses as (

    select * from {{ ref('stg_ecommerce__order_statuses') }}

),

status_rules as (

    select * from {{ ref('order_status_mapping') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['statuses.order_status_id']) }} as order_status_key,
    statuses.order_status_id,
    statuses.status_name,
    statuses.status_description,
    status_rules.fulfillment_stage,
    status_rules.counts_as_revenue
from statuses
left join status_rules
    on statuses.status_name = status_rules.status_name
