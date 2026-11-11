-- =============================================================================
-- int_inventory__product_warehouse
-- =============================================================================
-- Grain: mỗi cặp sản phẩm và kho một dòng.
--
-- Nguồn tồn kho có 224 cặp sản phẩm và kho xuất hiện ở nhiều bản ghi (có cặp
-- tới 30 bản ghi). Model này gộp các bản ghi đó lại:
--   - số lượng tồn, giữ chỗ, khả dụng: cộng lại, coi mỗi bản ghi là một lô hàng
--     trong cùng kho
--   - ngưỡng nhập lại: lấy giá trị lớn nhất, cách tính thận trọng
-- Doanh nghiệp thật thường có đúng một dòng cho mỗi sản phẩm ở mỗi kho, nên
-- đây là giả định để xử lý dữ liệu sinh ngẫu nhiên.
-- =============================================================================

select
    product_key,
    warehouse_id,
    warehouse_name,
    warehouse_city,
    count(*)                    as record_count,
    sum(quantity_on_hand)       as quantity_on_hand,
    sum(quantity_reserved)      as quantity_reserved,
    sum(quantity_available)     as quantity_available,
    max(reorder_level)          as reorder_level,
    sum(quantity_available) <= max(reorder_level)   as needs_reorder,
    sum(quantity_available) = 0                     as is_out_of_stock
from {{ ref('fact_inventory_current') }}
group by product_key, warehouse_id, warehouse_name, warehouse_city
