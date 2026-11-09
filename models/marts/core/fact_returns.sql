-- =============================================================================
-- fact_returns
-- =============================================================================
-- Grain: mỗi yêu cầu trả hàng một dòng, 2.000 dòng.
--
-- Fact trả hàng, gồm mọi yêu cầu ở mọi trạng thái (requested, approved,
-- rejected, refunded). Dùng để phân tích: lý do trả hàng phổ biến, sản phẩm
-- bị trả nhiều, thời gian xử lý yêu cầu.
--
-- Khác với fact_sales.refunded_amount (chỉ tính yêu cầu đã refunded), bảng này
-- giữ cả yêu cầu đang chờ hoặc bị từ chối. Muốn tính tiền đã hoàn thực tế thì
-- lọc return_status = 'refunded'.
-- =============================================================================

with returns as (

    select * from {{ ref('stg_ecommerce__order_returns') }}

),

-- Lấy thông tin của dòng sản phẩm bị trả: đơn nào, khách nào, sản phẩm gì,
-- và số tiền khách đã trả cho dòng đó.
items as (

    select order_item_id, order_id, product_id, customer_id, quantity, net_amount
    from {{ ref('int_order_items__enriched') }}

),

-- Bảng tra cứu lý do trả hàng: return_reason_id -> tên lý do.
reasons as (

    select * from {{ ref('stg_ecommerce__return_reasons') }}

)

select
    returns.return_id,
    returns.order_item_id,
    items.order_id,

    -- hai mốc ngày: lúc khách yêu cầu và lúc xử lý xong
    {{ date_key('returns.requested_at') }}                         as requested_date_key,
    {{ date_key('returns.processed_at') }}                         as processed_date_key,

    {{ dbt_utils.generate_surrogate_key(['items.customer_id']) }}  as customer_key,
    {{ dbt_utils.generate_surrogate_key(['items.product_id']) }}   as product_key,

    -- lý do được đưa thẳng vào fact (thay vì tạo dim_return_reason) vì bảng
    -- lý do chỉ có một cột mô tả
    reasons.return_reason,
    returns.return_status,
    returns.returned_quantity,

    -- Tiền trả hàng = giá thực trả của một đơn vị × số lượng trả.
    -- Dùng giá sau giảm giá, trước thuế, không gồm phí ship, cùng cách tính với
    -- refunded_amount ở int_order_items__enriched.
    -- Test assert_return_not_above_amount_paid kiểm tra cột này không vượt
    -- số tiền khách đã trả.
    cast(
        items.net_amount / nullif(items.quantity, 0) * returns.returned_quantity
        as decimal(18, 2)
    )                                                              as returned_amount
from returns
left join items
    on returns.order_item_id = items.order_item_id
left join reasons
    on returns.return_reason_id = reasons.return_reason_id
