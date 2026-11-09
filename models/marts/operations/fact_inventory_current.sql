-- =============================================================================
-- fact_inventory_current
-- =============================================================================
-- Grain: mỗi bản ghi tồn kho một dòng, 1.200 dòng.
--
-- Fact tồn kho tại thời điểm hiện tại (snapshot fact): mỗi sản phẩm ở mỗi kho
-- còn bao nhiêu hàng, có cần nhập thêm không.
--
-- Chỉ có trạng thái hiện tại vì nguồn không lưu lịch sử. Muốn phân tích tồn
-- kho theo thời gian thì phải chụp lại bảng này định kỳ, ví dụ bằng dbt
-- snapshot giống snap_products.
--
-- Chú ý: có 224 cặp sản phẩm và kho xuất hiện ở nhiều bản ghi. Vì vậy khoá
-- của bảng là inventory_id, không phải cặp (sản phẩm, kho).
-- =============================================================================

with inventory as (

    select * from {{ ref('stg_ecommerce__product_inventories') }}

),

warehouses as (

    select * from {{ ref('stg_ecommerce__warehouses') }}

)

select
    inventory.inventory_id,
    {{ dbt_utils.generate_surrogate_key(['inventory.product_id']) }} as product_key,

    -- thông tin kho được gắn thẳng vào fact vì chưa có dim_warehouse
    inventory.warehouse_id,
    warehouses.warehouse_name,
    warehouses.city                                                  as warehouse_city,

    inventory.quantity_on_hand,     -- số lượng đang có trong kho
    inventory.quantity_reserved,    -- số lượng đã giữ cho đơn chưa giao
    -- số lượng còn bán được = tồn kho - đã giữ chỗ
    inventory.quantity_on_hand - inventory.quantity_reserved         as quantity_available,
    inventory.reorder_level,        -- ngưỡng tồn kho tối thiểu

    -- cần nhập thêm khi số còn bán được chạm hoặc dưới ngưỡng.
    -- Hiện có 312 trên 1.200 bản ghi cần nhập thêm.
    inventory.quantity_on_hand - inventory.quantity_reserved
        <= inventory.reorder_level                                   as needs_reorder
from inventory
left join warehouses
    on inventory.warehouse_id = warehouses.warehouse_id
