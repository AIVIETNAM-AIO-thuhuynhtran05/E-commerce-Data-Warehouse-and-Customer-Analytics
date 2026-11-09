-- =============================================================================
-- int_orders__enriched
-- =============================================================================
-- Grain: mỗi đơn hàng một dòng (36.000 đơn).
--
-- Đây là model quan trọng nhất của tầng intermediate, vì nó là nơi duy nhất
-- quyết định "đơn này có được tính doanh thu không" (cột counts_as_revenue).
-- Mọi model phía sau (int_order_items__enriched, fact_orders, fact_sales...)
-- chỉ đọc lại cột này, không tự viết lại quy tắc. Nhờ vậy, muốn đổi quy tắc
-- thì chỉ cần sửa seed order_status_mapping, mọi con số phía sau đổi theo.
--
-- Model ghép 4 nguồn vào bảng orders:
--   1. statuses      : đổi order_status_id thành tên trạng thái (paid, cancelled...)
--   2. status_rules  : quy tắc nghiệp vụ của từng trạng thái, lấy từ seed
--   3. items         : số dòng sản phẩm và tổng số lượng của đơn
--   4. payments      : số tiền đã thanh toán, đã gộp sẵn về cấp đơn
--
-- Mọi phép join đều là left join từ orders, và mọi bảng được join đều đã có
-- grain "mỗi đơn một dòng" (hoặc mỗi trạng thái một dòng), nên số dòng đầu ra
-- luôn bằng đúng số đơn. Không có fan-out.
-- =============================================================================

-- Bước 1: lấy các bảng đầu vào ------------------------------------------------

-- Bảng đơn hàng đã làm sạch ở staging.
with orders as (

    select * from {{ ref('stg_ecommerce__orders') }}

),

-- Bảng tra cứu: order_status_id -> status_name. Mỗi trạng thái một dòng.
statuses as (

    select * from {{ ref('stg_ecommerce__order_statuses') }}

),

-- Quy tắc nghiệp vụ, lấy từ seeds/order_status_mapping.csv:
--
--   status_name | fulfillment_stage | counts_as_revenue
--   ------------+-------------------+------------------
--   pending     | awaiting_payment  | false
--   paid        | paid              | true
--   shipped     | in_transit        | true
--   delivered   | completed         | true
--   cancelled   | cancelled         | false
--   refunded    | refunded          | false
--
-- Để quy tắc trong file CSV thay vì viết "case when status in (...)" trong SQL
-- vì: người không viết SQL cũng đọc và sửa được, và thay đổi quy tắc hiện rõ
-- trong Git như một thay đổi dữ liệu.
status_rules as (

    select * from {{ ref('order_status_mapping') }}

),

-- Gộp các dòng sản phẩm về cấp đơn, cùng lý do như int_orders__payments_agg:
-- join thẳng order_items vào orders sẽ nhân mỗi đơn lên theo số dòng sản phẩm.
items as (

    select
        order_id,
        count(*)      as item_line_count,  -- số dòng sản phẩm khác nhau
        sum(quantity) as item_quantity     -- tổng số món hàng
    from {{ ref('stg_ecommerce__order_items') }}
    group by order_id

),

-- Thanh toán đã gộp sẵn về cấp đơn ở model int_orders__payments_agg.
payments as (

    select * from {{ ref('int_orders__payments_agg') }}

)

-- Bước 2: ghép tất cả vào orders -----------------------------------------------

select
    -- khoá và thời gian
    orders.order_id,
    orders.customer_id,
    orders.ordered_at,
    cast(orders.ordered_at as date)                as order_date,  -- để join với dim_date

    -- trạng thái và quy tắc nghiệp vụ
    orders.order_status_id,
    statuses.status_name,
    status_rules.fulfillment_stage,
    status_rules.counts_as_revenue,  -- cột quyết định doanh thu, có test not_null

    -- các khoá ngoại để fact_orders nối tới dimension
    orders.billing_address_id,
    orders.shipping_address_id,
    orders.shipping_method_id,
    orders.coupon_id,

    -- thông tin sản phẩm trong đơn
    -- Đơn không có dòng sản phẩm nào thì left join trả về null, đổi thành 0.
    coalesce(items.item_line_count, 0)             as item_line_count,
    coalesce(items.item_quantity, 0)               as item_quantity,
    -- items.order_id chỉ null khi đơn không có dòng sản phẩm nào.
    -- Có 2.258 đơn như vậy (chỉ có phí ship), được test
    -- warn_orders_without_items báo cảnh báo mỗi lần build.
    items.order_id is not null                     as has_items,

    -- số tiền cấp đơn, giữ nguyên từ nguồn
    -- order_total = subtotal - discount_amount + tax_amount + shipping_cost
    orders.subtotal,
    orders.discount_amount,
    orders.tax_amount,
    orders.shipping_cost,
    orders.order_total,

    -- thanh toán; đơn chưa có payment nào thì đổi null thành 0
    coalesce(payments.payment_count, 0)            as payment_count,
    coalesce(payments.completed_payment_amount, 0) as completed_payment_amount,
    coalesce(payments.refunded_payment_amount, 0)  as refunded_payment_amount,
    payments.last_completed_payment_at
from orders
left join statuses
    on orders.order_status_id = statuses.order_status_id
-- join qua status_name (chữ thường, đã chuẩn hoá ở staging) vì seed dùng tên,
-- không dùng id
left join status_rules
    on statuses.status_name = status_rules.status_name
left join items
    on orders.order_id = items.order_id
left join payments
    on orders.order_id = payments.order_id

-- Chú ý: doanh thu tính theo trạng thái đơn, không đối chiếu với payments.
-- Có 1.429 đơn paid/shipped/delivered nhưng completed_payment_amount = 0, vẫn
-- được tính doanh thu. Đây là giả định của project (README, quyết định số 7),
-- được test warn_revenue_orders_without_completed_payment theo dõi.
