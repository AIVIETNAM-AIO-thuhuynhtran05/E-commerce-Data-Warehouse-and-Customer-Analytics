-- =============================================================================
-- fact_payments
-- =============================================================================
-- Grain: mỗi lần thanh toán một dòng, 35.000 dòng.
--
-- Fact giao dịch thanh toán, gồm cả lần thành công, thất bại và đã hoàn tiền.
-- Dùng để phân tích: phương thức nào được dùng nhiều, tỷ lệ thanh toán thất
-- bại theo phương thức, tiền thu theo ngày.
--
-- Khác với int_orders__payments_agg (đã gộp về cấp đơn), bảng này giữ từng
-- lần thanh toán riêng lẻ.
-- =============================================================================

with payments as (

    select * from {{ ref('stg_ecommerce__payments') }}

),

-- Bảng payments không có customer_id, nên phải lấy qua bảng orders.
orders as (

    select order_id, customer_id from {{ ref('stg_ecommerce__orders') }}

)

select
    payments.payment_id,
    payments.order_id,
    -- ngày thanh toán (processed_at), không phải ngày đặt đơn
    {{ date_key('payments.processed_at') }}                                as payment_date_key,
    {{ dbt_utils.generate_surrogate_key(['orders.customer_id']) }}         as customer_key,
    {{ dbt_utils.generate_surrogate_key(['payments.payment_method_id']) }} as payment_method_key,
    payments.payment_status,         -- completed, failed hoặc refunded
    payments.transaction_reference,  -- mã giao dịch bên cổng thanh toán
    payments.payment_amount
from payments
-- mỗi payment thuộc đúng một đơn, nên join này không làm nhân dòng
left join orders
    on payments.order_id = orders.order_id

-- Chú ý: muốn tính tiền đã thu thì phải lọc payment_status = 'completed'.
-- sum(payment_amount) trên cả bảng sẽ cộng cả lần thất bại và đã hoàn tiền.
