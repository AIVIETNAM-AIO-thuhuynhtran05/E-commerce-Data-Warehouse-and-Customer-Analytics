-- =============================================================================
-- mart_returns
-- =============================================================================
-- Grain: mỗi yêu cầu trả hàng một dòng, 2.000 dòng.
--
-- Bảng rộng cho trang Power BI "Hoàn hàng": gom sẵn lý do, nhóm lý do, sản
-- phẩm, danh mục, phương thức giao hàng và các mốc thời gian, để trang chỉ cần
-- đọc một bảng.
--
-- Nhóm lý do (reason_group) là quy ước của project:
--   seller: lỗi phía bán hoặc vận chuyển (hỏng, gửi nhầm, giao trễ, không
--           đúng mô tả)
--   customer: lý do phía khách (không vừa, đổi ý)
--
-- Chú ý: khi cắt chéo, tỷ trọng lý do gần như không đổi theo danh mục và
-- phương thức giao hàng (ví dụ "Arrived too late" khoảng 9% ở mọi phương thức).
-- Lý do trong dữ liệu nguồn có vẻ được gán ngẫu nhiên, nên bảng này phù hợp để
-- mô tả cơ cấu lý do, không đủ để kết luận danh mục nào hay bị trả vì lý do gì.
-- =============================================================================

with returns as (

    select * from {{ ref('fact_returns') }}

),

source_returns as (

    select return_id, requested_at, processed_at
    from {{ ref('stg_ecommerce__order_returns') }}

),

items as (

    select order_item_id, ordered_at, shipping_method_id, quantity
    from {{ ref('int_order_items__enriched') }}

),

products as (

    select product_key, product_name, category_name, brand_name
    from {{ ref('dim_product') }}

),

shipping_methods as (

    select shipping_method_id, shipping_method_name, carrier
    from {{ ref('stg_ecommerce__shipping_methods') }}

)

select
    returns.return_id,
    returns.order_item_id,
    returns.order_id,
    returns.customer_key,
    returns.product_key,
    returns.requested_date_key,
    returns.processed_date_key,

    cast(date_trunc('month', source_returns.requested_at) as date) as requested_month,

    returns.return_reason,
    case
        when returns.return_reason in ('Does not fit', 'Changed my mind')
            then 'customer'
        else 'seller'
    end                                                            as reason_group,
    returns.return_status,

    -- Yêu cầu ở trạng thái requested vẫn có processed_at trong nguồn, nên chỉ
    -- tính thời gian xử lý cho yêu cầu đã có kết quả.
    returns.return_status in ('approved', 'rejected', 'refunded')  as is_processed,
    case
        when returns.return_status in ('approved', 'rejected', 'refunded')
            then date_diff('day', source_returns.requested_at, source_returns.processed_at)
    end                                                            as days_to_process,
    date_diff('day', items.ordered_at, source_returns.requested_at) as days_from_order_to_request,

    products.product_name,
    products.category_name,
    products.brand_name,
    shipping_methods.shipping_method_name,
    shipping_methods.carrier,

    items.quantity                                                 as ordered_quantity,
    returns.returned_quantity,
    returns.returned_amount,

    -- Tiền đã hoàn thực tế: chỉ tính yêu cầu ở trạng thái refunded, khớp với
    -- refunded_amount ở fact_sales.
    case
        when returns.return_status = 'refunded' then returns.returned_amount
        else 0
    end                                                            as refunded_amount
from returns
inner join source_returns
    on returns.return_id = source_returns.return_id
left join items
    on returns.order_item_id = items.order_item_id
left join products
    on returns.product_key = products.product_key
left join shipping_methods
    on items.shipping_method_id = shipping_methods.shipping_method_id
