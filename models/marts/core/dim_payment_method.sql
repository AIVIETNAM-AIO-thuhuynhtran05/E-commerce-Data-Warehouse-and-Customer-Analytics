-- =============================================================================
-- dim_payment_method
-- =============================================================================
-- Grain: mỗi phương thức thanh toán một dòng, 5 dòng.
-- Dimension cho fact_payments, dùng để phân tích tỷ lệ dùng từng phương thức
-- hay tỷ lệ thanh toán thất bại theo phương thức.
--
-- Bảng nhỏ và không cần biến đổi gì, nên đọc thẳng từ staging, chỉ thêm
-- surrogate key.
-- =============================================================================

select
    -- băm từ payment_method_id, cùng cách với payment_method_key trong fact_payments
    {{ dbt_utils.generate_surrogate_key(['payment_method_id']) }} as payment_method_key,
    payment_method_id,
    payment_method_name
from {{ ref('stg_ecommerce__payment_methods') }}
