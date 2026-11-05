-- Grain: one row per support ticket.

with tickets as (

    select * from {{ ref('stg_ecommerce__support_tickets') }}

),

messages as (

    select
        ticket_id,
        count(*)                                        as message_count,
        count(*) filter (where sender_type = 'agent')   as agent_message_count,
        min(sent_at) filter (where sender_type = 'agent') as first_agent_reply_at
    from {{ ref('stg_ecommerce__support_messages') }}
    group by ticket_id

)

select
    tickets.ticket_id,
    {{ dbt_utils.generate_surrogate_key(['tickets.customer_id']) }} as customer_key,
    {{ date_key('tickets.created_at') }}                            as created_date_key,
    tickets.priority,
    tickets.ticket_status,
    tickets.subject,
    coalesce(messages.message_count, 0)                             as message_count,
    coalesce(messages.agent_message_count, 0)                       as agent_message_count,
    date_diff('hour', tickets.created_at, messages.first_agent_reply_at)
                                                                    as hours_to_first_agent_reply
from tickets
left join messages
    on tickets.ticket_id = messages.ticket_id
