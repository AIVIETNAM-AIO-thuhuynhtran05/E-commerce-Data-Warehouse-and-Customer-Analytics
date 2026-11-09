-- =============================================================================
-- dim_order_status
-- =============================================================================
-- Grain: mỗi trạng thái đơn một dòng, 6 dòng
-- (pending, paid, shipped, delivered, cancelled, refunded).
--
-- Dimension trạng thái đơn, kèm quy tắc nghiệp vụ lấy từ seed
-- order_status_mapping. Người dùng báo cáo có thể lọc "chỉ đơn được tính doanh
-- thu" bằng cột counts_as_revenue mà không cần biết quy tắc nằm ở đâu.
--
-- Quy tắc ở đây lấy cùng một nguồn (seed) với int_orders__enriched, nên
-- dimension và fact luôn khớp nhau.
-- =============================================================================

-- Bảng trạng thái đã làm sạch ở staging.
with statuses as (

    select * from {{ ref('stg_ecommerce__order_statuses') }}

),

-- Quy tắc nghiệp vụ từ seeds/order_status_mapping.csv.
status_rules as (

    select * from {{ ref('order_status_mapping') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['statuses.order_status_id']) }} as order_status_key,
    statuses.order_status_id,
    statuses.status_name,
    statuses.status_description,
    status_rules.fulfillment_stage,   -- giai đoạn xử lý: awaiting_payment, in_transit...
    status_rules.counts_as_revenue    -- true với paid, shipped, delivered
from statuses
left join status_rules
    on statuses.status_name = status_rules.status_name
