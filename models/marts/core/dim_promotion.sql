-- =============================================================================
-- dim_promotion
-- =============================================================================
-- Grain: mỗi mã giảm giá một dòng, cộng thêm một dòng "NO PROMOTION".
-- Tổng 81 dòng (80 coupon + 1 dòng đặc biệt).
--
-- Vì sao cần dòng "NO PROMOTION"?
--   Phần lớn đơn không dùng coupon (30.517 trên 36.000 đơn), nên coupon_id của
--   các đơn này là null. Nếu để khoá null trong fact:
--     - inner join với dim_promotion sẽ làm mất các đơn đó;
--     - báo cáo "doanh thu theo khuyến mãi" có một nhóm trống không tên.
--   Cách làm chuẩn của Kimball là thêm một dòng đại diện cho "không có", với
--   coupon_id = -1. Các fact đổi coupon_id null thành -1 bằng
--   coalesce(coupon_id, -1) trước khi tạo khoá, nên mọi đơn đều nối được vào
--   dimension này.
-- =============================================================================

-- Các mã giảm giá thật từ staging. Liệt kê rõ cột (không select *) để thứ tự
-- cột khớp với CTE no_promotion bên dưới, vì union all ghép theo vị trí cột.
with coupons as (

    select
        coupon_id,
        coupon_code,
        discount_type,
        discount_value,
        min_purchase_amount,
        is_active,
        starts_at,
        ends_at
    from {{ ref('stg_ecommerce__discount_coupons') }}

),

-- Dòng đặc biệt cho đơn không dùng coupon. Kiểu dữ liệu của từng cột phải
-- giống bảng coupons (decimal, timestamp...) để union all không lỗi.
no_promotion as (

    select
        -1                         as coupon_id,
        'NO PROMOTION'             as coupon_code,
        'none'                     as discount_type,
        cast(0 as decimal(18, 2))  as discount_value,
        cast(0 as decimal(18, 2))  as min_purchase_amount,
        false                      as is_active,
        cast(null as timestamp)    as starts_at,
        cast(null as timestamp)    as ends_at

),

-- union all: nối hai bảng theo chiều dọc (cộng dòng), giữ nguyên mọi dòng.
unioned as (

    select * from coupons
    union all
    select * from no_promotion

)

select
    {{ dbt_utils.generate_surrogate_key(['coupon_id']) }} as promotion_key,
    *,
    -- cờ tiện cho báo cáo: lọc nhanh đơn có và không có khuyến mãi
    coupon_id <> -1                                       as has_promotion
from unioned
