-- =============================================================================
-- fact_sales
-- =============================================================================
-- Grain: mỗi dòng sản phẩm trong đơn một dòng, 100.000 dòng.
-- Fact trung tâm của star schema bán hàng.
--
-- Một fact gồm 2 loại cột:
--   - Khoá (keys): trỏ tới các dimension, để trả lời "bán cho ai, sản phẩm gì,
--     ngày nào, giao đi đâu, có khuyến mãi không...".
--   - Số đo (measures): các con số để cộng lại, ví dụ số lượng, tiền hàng,
--     doanh thu.
--
-- Mọi số đo ở đây đều cộng được ở cấp dòng sản phẩm: cộng theo sản phẩm, theo
-- danh mục, theo tháng... đều ra đúng.
--
-- Chú ý: không đưa số liệu cấp đơn (phí ship, order_total) vào bảng này. Một
-- đơn có nhiều dòng sản phẩm, nên phí ship sẽ bị lặp lại ở mỗi dòng và bị cộng
-- trùng khi sum (fan-out). Trong project, join fact_orders vào fact_sales rồi
-- sum(order_total) cho ra 40,2 triệu thay vì 10,8 triệu, gấp 3,7 lần, mà
-- không có lỗi nào báo ra. Số liệu cấp đơn nằm ở fact_orders.
-- =============================================================================

-- Toàn bộ logic (chia giảm giá, tiền hoàn, doanh thu) đã làm ở intermediate.
-- Fact chỉ việc chọn cột và tạo khoá.
with lines as (

    select * from {{ ref('int_order_items__enriched') }}

),

-- Chỉ lấy 2 cột cần để đổi address_id thành geography_key.
geography as (

    select address_id, geography_key from {{ ref('int_addresses__geography') }}

)

select
    -- khoá ------------------------------------------------------------------
    lines.order_item_id,  -- khoá chính của fact
    lines.order_id,       -- degenerate dimension: khoá không có bảng dimension riêng,
                          -- giữ lại để đếm số đơn hoặc tra ngược về đơn
    -- date_key là macro tự viết (macros/date_key.sql): đổi ngày thành số
    -- YYYYMMDD để join với dim_date
    {{ date_key('lines.order_date') }}                                            as order_date_key,
    -- băm id gốc theo đúng cách các dimension đã làm, nên khoá tự khớp
    {{ dbt_utils.generate_surrogate_key(['lines.customer_id']) }}                 as customer_key,
    {{ dbt_utils.generate_surrogate_key(['lines.product_id']) }}                  as product_key,
    geography.geography_key                                                       as ship_to_geography_key,
    -- đơn không dùng coupon: đổi null thành -1 để trỏ tới dòng "NO PROMOTION"
    {{ dbt_utils.generate_surrogate_key(['coalesce(lines.coupon_id, -1)']) }}     as promotion_key,
    {{ dbt_utils.generate_surrogate_key(['lines.shipping_method_id']) }}          as shipping_method_key,
    {{ dbt_utils.generate_surrogate_key(['lines.order_status_id']) }}             as order_status_key,

    -- số đo -----------------------------------------------------------------
    lines.quantity,
    lines.unit_price,          -- giá lúc bán (khác dim_product.current_price)
    lines.gross_amount,        -- quantity × unit_price
    lines.discount_amount,     -- phần giảm giá của đơn được chia về dòng này
    lines.net_amount,          -- gross_amount - discount_amount
    lines.tax_amount,
    lines.recognized_revenue,  -- = net_amount nếu đơn được tính doanh thu, ngược lại = 0
    lines.refunded_quantity,
    lines.refunded_amount      -- tiền hoàn theo giá khách thực trả
from lines
-- left join: giữ dòng bán hàng kể cả khi không tìm được địa chỉ giao
left join geography
    on lines.shipping_address_id = geography.address_id
