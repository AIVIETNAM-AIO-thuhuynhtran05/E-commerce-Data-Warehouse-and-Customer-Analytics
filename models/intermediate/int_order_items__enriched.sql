-- =============================================================================
-- int_order_items__enriched
-- =============================================================================
-- Grain: mỗi dòng sản phẩm trong đơn (order item) là một dòng.
-- Model này là nguồn của fact_sales.
--
-- Model làm 3 việc:
--   1. Gắn thông tin của đơn (khách hàng, ngày đặt, trạng thái...) vào từng dòng.
--   2. Chia giảm giá của cả đơn về từng dòng sản phẩm.
--   3. Gắn số lượng hàng đã được hoàn tiền và tính tiền hoàn.
--
-- Vì sao phải chia giảm giá?
--   Trong dữ liệu nguồn, giảm giá chỉ nằm ở cấp đơn (orders.discount_amount).
--   Giảm giá ở cấp dòng (line_discount_amount) luôn bằng 0. Nếu không chia,
--   ta không biết mỗi sản phẩm thực sự bán được bao nhiêu tiền sau giảm giá,
--   nên không tính được doanh thu theo sản phẩm hay theo danh mục.
--
-- Ví dụ thật trong dữ liệu, đơn 26606 có 2 dòng:
--
--   dòng | quantity × unit_price | gross_amount | phần giảm giá | net_amount
--   -----+-----------------------+--------------+---------------+-----------
--   A    |  2 × 15,94            |  31,88       |  7,41         | 24,47
--   B    |  1 × 70,76            |  70,76       | 16,45         | 54,31
--   -----+-----------------------+--------------+---------------+-----------
--   đơn  |                       | 102,64       | 23,86         | 78,78
--
--   Dòng A chiếm 31,88 / 102,64 ≈ 31% tiền hàng của đơn, nên nhận khoảng 31%
--   giảm giá: 23,86 × 31,88 / 102,64 ≈ 7,41.
--   Đơn này ở trạng thái không được tính doanh thu, nên recognized_revenue = 0.
-- =============================================================================

-- Bước 1: lấy các bảng đầu vào ------------------------------------------------

-- Các dòng sản phẩm, đã làm sạch ở staging. Mỗi dòng có quantity, unit_price.
with items as (

    select * from {{ ref('stg_ecommerce__order_items') }}

),

-- Thông tin cấp đơn, mỗi đơn một dòng. Model int_orders__enriched đã quyết định
-- sẵn đơn nào được tính doanh thu (cột counts_as_revenue), nên ở đây chỉ dùng
-- lại kết quả đó, không tự định nghĩa lại.
orders as (

    select * from {{ ref('int_orders__enriched') }}

),

-- Số lượng đã được hoàn tiền của mỗi dòng sản phẩm.
-- - Chỉ lấy yêu cầu có trạng thái 'refunded' (đã hoàn tiền xong). Các yêu cầu
--   'requested', 'approved', 'rejected' chưa hoặc không hoàn tiền nên bỏ qua.
-- - group by order_item_id để mỗi dòng sản phẩm chỉ còn một dòng. Nếu join thẳng
--   bảng returns vào items mà một dòng có nhiều yêu cầu hoàn, dòng đó sẽ bị
--   nhân lên (fan-out) và tiền hàng bị cộng trùng.
refunds as (

    select
        order_item_id,
        sum(returned_quantity) as refunded_quantity
    from {{ ref('stg_ecommerce__order_returns') }}
    where return_status = 'refunded'
    group by order_item_id

),

-- Bước 2: ghép thông tin đơn và hoàn tiền vào từng dòng -------------------------

lines as (

    select
        -- khoá và thông tin mô tả
        items.order_item_id,
        items.order_id,
        items.product_id,
        orders.customer_id,
        orders.ordered_at,
        orders.order_date,
        orders.order_status_id,
        orders.counts_as_revenue,
        orders.shipping_address_id,
        orders.shipping_method_id,
        orders.coupon_id,

        -- số liệu của dòng
        items.quantity,
        items.unit_price,
        items.quantity * items.unit_price      as gross_amount,   -- tiền hàng trước giảm giá
        items.line_discount_amount,                               -- luôn = 0 trong dữ liệu này
        items.tax_amount,

        -- số liệu của cả đơn, cần để chia giảm giá ở bước 3
        orders.discount_amount                 as order_discount_amount,
        orders.subtotal                        as order_subtotal, -- = tổng gross_amount của đơn

        -- dòng không có hoàn tiền thì left join trả về null, đổi thành 0
        coalesce(refunds.refunded_quantity, 0) as refunded_quantity
    from items
    -- inner join: mọi dòng sản phẩm đều phải thuộc một đơn có thật
    inner join orders
        on items.order_id = orders.order_id
    -- left join: phần lớn dòng không có hoàn tiền, vẫn phải giữ lại
    left join refunds
        on items.order_item_id = refunds.order_item_id

),

-- Bước 3: chia giảm giá của đơn về từng dòng ----------------------------------

allocated as (

    select
        *,
        -- phần giảm giá của dòng = giảm giá cả đơn × (tiền hàng của dòng / tiền hàng của đơn)
        -- - case when order_subtotal > 0: tránh chia cho 0 với đơn không có tiền hàng.
        -- - cast decimal(18, 2): làm tròn về 2 chữ số như tiền thật. Vì làm tròn
        --   trên từng dòng, tổng các phần có thể lệch giảm giá của đơn tối đa
        --   khoảng 0,02.
        cast(
            line_discount_amount
            + case
                when order_subtotal > 0
                    then order_discount_amount * gross_amount / order_subtotal
                else 0
            end
            as decimal(18, 2)
        ) as discount_amount
    from lines

)

-- Bước 4: tính các số liệu cuối cùng -------------------------------------------

select
    order_item_id,
    order_id,
    product_id,
    customer_id,
    ordered_at,
    order_date,
    order_status_id,
    counts_as_revenue,
    shipping_address_id,
    shipping_method_id,
    coupon_id,
    quantity,
    unit_price,
    gross_amount,
    discount_amount,

    -- tiền khách thực trả cho dòng này: sau giảm giá, chưa gồm thuế và phí ship
    gross_amount - discount_amount                         as net_amount,

    tax_amount,
    refunded_quantity,

    -- Tiền hoàn = giá thực trả của một đơn vị × số lượng hoàn.
    -- Dùng giá sau giảm giá chứ không dùng unit_price, để không hoàn nhiều hơn
    -- số tiền khách đã trả. Trước thuế, không gồm phí ship, cùng cách tính với
    -- doanh thu, nên recognized_revenue - refunded_amount không bao giờ âm.
    -- nullif(quantity, 0): tránh lỗi chia cho 0.
    cast(
        (gross_amount - discount_amount) / nullif(quantity, 0) * refunded_quantity
        as decimal(18, 2)
    )                                                      as refunded_amount,

    -- Doanh thu ghi nhận: chỉ đơn có counts_as_revenue = true
    -- (paid, shipped, delivered, theo seed order_status_mapping) mới có doanh thu.
    -- Đơn pending, cancelled, refunded vẫn có dòng ở đây nhưng doanh thu = 0.
    case
        when counts_as_revenue then gross_amount - discount_amount
        else 0
    end                                                    as recognized_revenue
from allocated
