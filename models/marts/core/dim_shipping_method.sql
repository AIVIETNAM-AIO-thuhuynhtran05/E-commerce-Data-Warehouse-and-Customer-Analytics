-- =============================================================================
-- dim_shipping_method
-- =============================================================================
-- Grain: mỗi phương thức vận chuyển một dòng, 5 dòng.
-- Dimension cho fact_orders, fact_sales và fact_shipments.
--
-- estimated_days là số ngày giao dự kiến. fact_shipments so sánh số ngày vận
-- chuyển thực tế với cột này để tính is_delivered_on_time.
-- =============================================================================

select
    {{ dbt_utils.generate_surrogate_key(['shipping_method_id']) }} as shipping_method_key,
    shipping_method_id,
    shipping_method_name,
    carrier,          -- đơn vị vận chuyển
    base_cost,        -- phí cơ bản
    estimated_days    -- số ngày giao dự kiến
from {{ ref('stg_ecommerce__shipping_methods') }}
