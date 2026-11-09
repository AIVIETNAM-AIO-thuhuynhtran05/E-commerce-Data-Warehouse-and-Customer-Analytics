-- =============================================================================
-- int_customers__order_history
-- =============================================================================
-- Grain: mỗi khách hàng đã từng đặt ít nhất một đơn là một dòng.
-- Có 6.813 khách như vậy, trên tổng 7.000 user. 187 user chưa đặt đơn nào nên
-- không có dòng ở đây; dim_customer dùng left join để vẫn giữ họ lại.
--
-- Model tóm tắt lịch sử mua hàng của từng khách để dim_customer dùng
-- (ví dụ first_order_date để chia cohort theo tháng mua đầu tiên).
--
-- Đọc từ int_orders__enriched, không đọc thẳng từ staging, để dùng lại cột
-- counts_as_revenue đã được quyết định ở đó.
-- =============================================================================

with orders as (

    select * from {{ ref('int_orders__enriched') }}

)

select
    customer_id,

    -- ngày đặt đơn đầu tiên và gần nhất, tính trên mọi đơn kể cả đơn huỷ
    min(order_date)                                              as first_order_date,
    max(order_date)                                              as last_order_date,

    -- tổng số đơn, kể cả pending, cancelled, refunded
    count(*)                                                     as order_count,

    -- chỉ đếm đơn được tính doanh thu (paid, shipped, delivered)
    count(*) filter (where counts_as_revenue)                    as revenue_order_count,

    -- tổng giá trị mọi đơn đã đặt, kể cả đơn huỷ
    sum(order_total)                                             as lifetime_order_value,

    -- tổng giá trị các đơn được tính doanh thu
    sum(case when counts_as_revenue then order_total else 0 end) as lifetime_revenue
from orders
group by customer_id

-- Chú ý: lifetime_revenue đang cộng order_total, tức đã gồm thuế và phí ship.
-- Trong khi đó recognized_revenue ở fact_sales là tiền hàng sau giảm giá,
-- không gồm thuế và phí ship. Hai con số mang cùng tên "doanh thu" nhưng tính
-- khác nhau (tổng 6,35 triệu so với 5,49 triệu). Đây là điểm cần sửa: tính
-- lifetime_revenue từ recognized_revenue của int_order_items__enriched.
