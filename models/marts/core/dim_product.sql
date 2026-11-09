-- =============================================================================
-- dim_product
-- =============================================================================
-- Grain: mỗi sản phẩm một dòng, 400 sản phẩm.
--
-- Dimension sản phẩm, gộp sẵn tên danh mục (22 danh mục) và tên thương hiệu
-- (40 thương hiệu) vào cùng một bảng.
--
-- Vì sao gộp category và brand vào đây thay vì để thành dimension riêng?
--   Đây là cách làm của star schema (Kimball): dimension được "làm phẳng"
--   (denormalize), để người dùng báo cáo chỉ cần join fact_sales với một bảng
--   dim_product là có đủ sản phẩm, danh mục, thương hiệu. Nếu tách riêng thành
--   nhiều tầng bảng (snowflake schema), câu truy vấn sẽ dài hơn và khó dùng hơn.
--
-- SCD type 1: bảng chỉ giữ giá trị hiện tại. Khi giá sản phẩm đổi, dòng cũ bị
-- ghi đè, không còn giá cũ. Lịch sử giá được lưu riêng ở snapshot snap_products
-- (SCD type 2).
-- =============================================================================

with products as (

    select * from {{ ref('stg_ecommerce__products') }}

),

categories as (

    select * from {{ ref('stg_ecommerce__categories') }}

),

brands as (

    select * from {{ ref('stg_ecommerce__brands') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['products.product_id']) }} as product_key,
    products.product_id,
    products.sku,
    products.product_name,
    products.product_slug,

    -- thông tin danh mục và thương hiệu, gộp sẵn vào dimension
    categories.category_id,
    categories.category_name,
    brands.brand_id,
    brands.brand_name,

    -- đặt tên current_price để nhắc rằng đây là giá hiện tại, không phải giá
    -- lúc bán. Giá lúc bán nằm ở fact_sales.unit_price.
    products.price                                          as current_price,
    products.compare_at_price,  -- giá gạch ngang (giá trước khuyến mãi) hiển thị trên web
    products.is_active,
    products.created_at                                     as product_created_at
from products
-- left join: sản phẩm thiếu danh mục hoặc thương hiệu vẫn được giữ lại
left join categories
    on products.category_id = categories.category_id
left join brands
    on products.brand_id = brands.brand_id
