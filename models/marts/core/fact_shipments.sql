-- =============================================================================
-- fact_shipments
-- =============================================================================
-- Grain: mỗi lô hàng một dòng, 34.000 dòng. Trong dữ liệu này mỗi đơn có tối
-- đa một lô hàng.
--
-- Fact vận chuyển. Dùng để phân tích: bao lâu thì gửi hàng, vận chuyển mất
-- bao lâu, tỷ lệ giao đúng hạn theo phương thức vận chuyển.
-- =============================================================================

with shipments as (

    select * from {{ ref('stg_ecommerce__shipments') }}

),

-- Lấy từ đơn hàng: khách hàng, phương thức vận chuyển và ngày đặt
-- (ngày đặt dùng để tính số ngày từ lúc đặt đến lúc gửi).
orders as (

    select order_id, customer_id, shipping_method_id, ordered_at
    from {{ ref('stg_ecommerce__orders') }}

),

-- Số ngày giao dự kiến của từng phương thức, để so với thực tế.
shipping_methods as (

    select shipping_method_id, estimated_days from {{ ref('stg_ecommerce__shipping_methods') }}

)

select
    shipments.shipment_id,
    shipments.order_id,
    {{ date_key('shipments.shipped_at') }}                                as shipped_date_key,
    {{ date_key('shipments.delivered_at') }}                              as delivered_date_key,
    {{ dbt_utils.generate_surrogate_key(['orders.customer_id']) }}        as customer_key,
    {{ dbt_utils.generate_surrogate_key(['orders.shipping_method_id']) }} as shipping_method_key,
    shipments.tracking_number,

    -- số ngày từ lúc đặt đơn đến lúc gửi hàng.
    -- cast về date trước để đếm theo ngày lịch, bỏ phần giờ phút.
    date_diff('day', cast(orders.ordered_at as date), cast(shipments.shipped_at as date))
                                                                          as days_to_ship,

    -- số ngày hàng nằm trên đường vận chuyển
    date_diff('day', cast(shipments.shipped_at as date), cast(shipments.delivered_at as date))
                                                                          as days_in_transit,

    -- giao đúng hạn khi số ngày vận chuyển không vượt số ngày dự kiến.
    -- Hiện có 31.657 trên 34.000 lô giao đúng hạn.
    date_diff('day', cast(shipments.shipped_at as date), cast(shipments.delivered_at as date))
        <= shipping_methods.estimated_days                                as is_delivered_on_time
from shipments
left join orders
    on shipments.order_id = orders.order_id
left join shipping_methods
    on orders.shipping_method_id = shipping_methods.shipping_method_id

-- Chú ý: dữ liệu sinh ngẫu nhiên có lô hàng cho cả đơn cancelled (5.772),
-- pending (4.430) và refunded (3.595), lô nào cũng có ngày gửi và ngày giao.
-- Ngoài thực tế các đơn này không thể có hàng đã giao. Khi phân tích tỷ lệ
-- giao đúng hạn nên chỉ tính đơn shipped và delivered.
