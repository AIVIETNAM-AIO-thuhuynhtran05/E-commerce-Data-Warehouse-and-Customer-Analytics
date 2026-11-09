-- =============================================================================
-- fact_support_tickets
-- =============================================================================
-- Grain: mỗi yêu cầu hỗ trợ (ticket) một dòng, 1.000 dòng.
--
-- Fact chăm sóc khách hàng. Dùng để phân tích: số ticket theo mức ưu tiên,
-- số tin nhắn trao đổi, thời gian nhân viên phản hồi lần đầu.
-- =============================================================================

with tickets as (

    select * from {{ ref('stg_ecommerce__support_tickets') }}

),

-- Gộp tin nhắn về cấp ticket (mỗi ticket một dòng) trước khi join, để không
-- nhân dòng ticket lên theo số tin nhắn.
messages as (

    select
        ticket_id,
        count(*)                                        as message_count,
        -- chỉ đếm tin nhắn do nhân viên gửi (sender_type = 'agent')
        count(*) filter (where sender_type = 'agent')   as agent_message_count,
        -- thời điểm nhân viên trả lời lần đầu
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

    -- ticket chưa có tin nhắn nào thì đổi null thành 0
    coalesce(messages.message_count, 0)                             as message_count,
    coalesce(messages.agent_message_count, 0)                       as agent_message_count,

    -- số giờ từ lúc tạo ticket đến lúc nhân viên trả lời lần đầu.
    -- null với 279 ticket chưa có phản hồi nào của nhân viên.
    date_diff('hour', tickets.created_at, messages.first_agent_reply_at)
                                                                    as hours_to_first_agent_reply
from tickets
left join messages
    on tickets.ticket_id = messages.ticket_id

-- Chú ý: date_diff('hour', ...) đếm số lần qua mốc giờ, không phải thời gian
-- thực tế. Ví dụ từ 9:59 đến 10:01 được tính là 1 giờ. Nếu cần chính xác thì
-- dùng epoch(first_agent_reply_at - created_at) / 3600.
