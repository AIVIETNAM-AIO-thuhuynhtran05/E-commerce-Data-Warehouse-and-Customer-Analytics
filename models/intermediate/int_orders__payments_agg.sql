-- =============================================================================
-- int_orders__payments_agg
-- =============================================================================
-- Grain: mỗi đơn hàng một dòng.
-- Gộp các lần thanh toán (payments) về cấp đơn để join vào int_orders__enriched.
--
-- Vì sao phải gộp trước khi join?
--   Một đơn có thể có nhiều lần thanh toán: lần đầu thất bại, lần sau thành
--   công, sau đó bị hoàn tiền... Nếu join thẳng bảng payments vào orders, mỗi
--   đơn sẽ bị nhân lên thành nhiều dòng (fan-out), và khi sum(order_total)
--   tiền của đơn bị cộng trùng nhiều lần.
--
--   Gộp payments về đúng grain của orders (mỗi đơn một dòng) thì phép join sau
--   đó là 1-1, không làm thay đổi số dòng.
--
-- Trong dữ liệu hiện tại:
--   - 35.000 payment cho 35.000 đơn, tức mỗi đơn đúng một lần thanh toán.
--     Bước gộp vẫn cần thiết vì code không được dựa vào điều may mắn đó: chỉ
--     cần nguồn có thêm một lần thanh toán lại là fan-out xảy ra ngay.
--   - Trạng thái: completed 33.595, failed 727, refunded 678.
--   - 1.000 đơn không có payment nào. Các đơn này sẽ không có dòng ở đây, và
--     int_orders__enriched dùng coalesce để đổi null thành 0.
-- =============================================================================

with payments as (

    select * from {{ ref('stg_ecommerce__payments') }}

)

select
    order_id,

    -- tổng số lần thanh toán của đơn, gồm cả thành công, thất bại và hoàn tiền
    count(*)                                                                    as payment_count,

    -- "sum có điều kiện": chỉ cộng các lần thanh toán thành công,
    -- các lần khác cộng 0
    sum(case when payment_status = 'completed' then payment_amount else 0 end) as completed_payment_amount,

    -- tương tự, chỉ cộng các lần đã hoàn tiền
    sum(case when payment_status = 'refunded' then payment_amount else 0 end)  as refunded_payment_amount,

    -- count(*) filter (where ...): cách viết khác của sum có điều kiện,
    -- đếm số lần thanh toán thất bại
    count(*) filter (where payment_status = 'failed')                          as failed_payment_count,

    -- thời điểm thanh toán thành công gần nhất; null nếu chưa có lần nào thành công
    max(processed_at) filter (where payment_status = 'completed')              as last_completed_payment_at
from payments
group by order_id
