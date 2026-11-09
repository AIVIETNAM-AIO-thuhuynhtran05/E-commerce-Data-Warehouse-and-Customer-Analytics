-- =============================================================================
-- fact_orders
-- =============================================================================
-- Grain: mỗi đơn hàng một dòng, 36.000 dòng.
--
-- Fact ở cấp đơn, chứa các số liệu không chia nhỏ về từng dòng sản phẩm được:
-- phí ship, thuế, tổng tiền đơn, số tiền đã thanh toán.
--
-- Khi nào dùng fact_orders, khi nào dùng fact_sales?
--   - Hỏi về đơn: "có bao nhiêu đơn", "giá trị đơn trung bình", "phí ship
--     trung bình" -> fact_orders.
--   - Hỏi về sản phẩm: "doanh thu theo danh mục", "sản phẩm bán chạy"
--     -> fact_sales.
--   Không join hai bảng này rồi sum số liệu cấp đơn: mỗi đơn sẽ bị lặp lại theo
--   số dòng sản phẩm (fan-out). Xem chú ý ở đầu fact_sales.
-- =============================================================================

with orders as (

    select * from {{ ref('int_orders__enriched') }}

),

geography as (

    select address_id, geography_key from {{ ref('int_addresses__geography') }}

)

select
    -- khoá ------------------------------------------------------------------
    -- Cùng bộ khoá với fact_sales (trừ product_key, vì một đơn có nhiều sản
    -- phẩm). Hai fact dùng chung dimension nên báo cáo có thể đặt cạnh nhau:
    -- đây gọi là conformed dimension.
    orders.order_id,
    {{ date_key('orders.order_date') }}                                           as order_date_key,
    {{ dbt_utils.generate_surrogate_key(['orders.customer_id']) }}                as customer_key,
    geography.geography_key                                                       as ship_to_geography_key,
    {{ dbt_utils.generate_surrogate_key(['coalesce(orders.coupon_id, -1)']) }}    as promotion_key,
    {{ dbt_utils.generate_surrogate_key(['orders.shipping_method_id']) }}         as shipping_method_key,
    {{ dbt_utils.generate_surrogate_key(['orders.order_status_id']) }}            as order_status_key,

    -- cờ (flags) --------------------------------------------------------------
    orders.counts_as_revenue,  -- đơn có được tính doanh thu không
    orders.has_items,          -- false với 2.258 đơn chỉ có phí ship

    -- số đo -----------------------------------------------------------------
    orders.item_line_count,
    orders.item_quantity,
    orders.subtotal,
    orders.discount_amount,
    orders.tax_amount,
    orders.shipping_cost,
    -- order_total = subtotal - discount_amount + tax_amount + shipping_cost
    orders.order_total,
    orders.completed_payment_amount
from orders
left join geography
    on orders.shipping_address_id = geography.address_id
