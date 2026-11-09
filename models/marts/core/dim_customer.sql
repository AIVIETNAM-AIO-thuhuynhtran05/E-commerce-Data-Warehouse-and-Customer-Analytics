-- =============================================================================
-- dim_customer
-- =============================================================================
-- Grain: mỗi khách hàng (user) một dòng, 7.000 dòng.
-- Dimension khách hàng trong star schema: các fact (fact_sales, fact_orders,
-- fact_payments...) nối vào đây qua customer_key.
--
-- Gồm 2 nhóm thông tin:
--   - Thông tin hồ sơ: tên, email, ngày đăng ký (từ staging users).
--   - Thông tin mua hàng đầu tiên: ngày mua đầu tiên, cohort tháng
--     (từ int_customers__order_history).
-- =============================================================================

-- Toàn bộ user đã làm sạch ở staging.
with customers as (

    select * from {{ ref('stg_ecommerce__users') }}

),

-- Lịch sử mua hàng, chỉ có dòng cho 6.813 khách đã từng đặt đơn.
order_history as (

    select * from {{ ref('int_customers__order_history') }}

)

select
    -- Surrogate key: băm MD5 từ customer_id. Các fact cũng băm customer_id
    -- theo cùng cách, nên khoá tự khớp mà không cần tra cứu bảng này.
    {{ dbt_utils.generate_surrogate_key(['customers.customer_id']) }} as customer_key,
    customers.customer_id,  -- natural key: id gốc từ hệ thống nguồn

    -- thông tin hồ sơ
    customers.first_name,
    customers.last_name,
    customers.email,
    customers.phone,
    customers.created_at                                      as signed_up_at,
    cast(customers.created_at as date)                        as signup_date,

    -- thông tin mua hàng; null với 187 user chưa đặt đơn nào
    order_history.first_order_date,
    -- cohort: nhóm khách theo tháng mua đầu tiên, ví dụ 2023-03-01.
    -- Dùng để phân tích retention: khách mua lần đầu tháng 3 quay lại bao nhiêu.
    date_trunc('month', order_history.first_order_date)       as first_order_cohort_month,
    order_history.first_order_date is not null                as has_ordered
from customers
-- left join: giữ cả 187 user chưa mua, để dimension đủ mọi khách hàng
left join order_history
    on customers.customer_id = order_history.customer_id
