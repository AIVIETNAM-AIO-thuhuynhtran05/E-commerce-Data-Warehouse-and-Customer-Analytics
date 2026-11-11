-- =============================================================================
-- mart_inventory_warehouse
-- =============================================================================
-- Grain: mỗi cặp sản phẩm và kho một dòng (tồn kho hiện tại).
--
-- Dùng cho trang Power BI "Kho hàng": tồn kho theo kho, sản phẩm cần nhập lại,
-- và số ngày tồn kho còn đủ bán.
--
-- Số ngày đủ bán (days of cover) tính ở cấp sản phẩm, không phải cấp kho, vì
-- đơn hàng không ghi kho xuất:
--   tổng tồn khả dụng của sản phẩm ở mọi kho / số lượng bán trung bình mỗi ngày
--   trong 90 ngày cuối có dữ liệu
-- Các cột cấp sản phẩm (product_*, avg_daily_units_90d, days_of_cover,
-- cover_bucket) lặp lại trên mỗi kho của sản phẩm đó, không được cộng dồn.
-- =============================================================================

with inventory as (

    select * from {{ ref('int_inventory__product_warehouse') }}

),

products as (

    select product_key, product_name, category_name, brand_name
    from {{ ref('dim_product') }}

),

-- Nhóm ABC và thứ hạng của năm gần nhất có dữ liệu.
latest_abc as (

    select product_key, abc_class, revenue_rank
    from {{ ref('mart_product_abc') }}
    where year = (select max(year) from {{ ref('mart_product_abc') }})

),

sales as (

    select
        sales.product_key,
        dates.date_day,
        sales.quantity
    from {{ ref('fact_sales') }} as sales
    inner join {{ ref('dim_date') }} as dates
        on sales.order_date_key = dates.date_key
    where sales.recognized_revenue > 0

),

-- Tốc độ bán: số lượng bán trung bình mỗi ngày trong 90 ngày cuối.
velocity as (

    select
        product_key,
        sum(quantity) / 90.0 as avg_daily_units_90d
    from sales
    where date_day > (select max(date_day) from sales) - interval 90 day
    group by product_key

),

product_stock as (

    select product_key, sum(quantity_available) as product_quantity_available
    from inventory
    group by product_key

),

cover as (

    select
        product_stock.product_key,
        product_stock.product_quantity_available,
        coalesce(velocity.avg_daily_units_90d, 0)   as avg_daily_units_90d,
        product_stock.product_quantity_available
            / nullif(velocity.avg_daily_units_90d, 0) as days_of_cover
    from product_stock
    left join velocity
        on velocity.product_key = product_stock.product_key

)

select
    inventory.product_key,
    products.product_name,
    products.category_name,
    products.brand_name,
    coalesce(latest_abc.abc_class, 'C')     as abc_class,
    latest_abc.revenue_rank,
    inventory.warehouse_id,
    inventory.warehouse_name,
    inventory.warehouse_city,
    inventory.record_count,
    inventory.quantity_on_hand,
    inventory.quantity_reserved,
    inventory.quantity_available,
    inventory.reorder_level,
    inventory.needs_reorder,
    inventory.is_out_of_stock,
    cover.product_quantity_available,
    round(cover.avg_daily_units_90d, 3)     as avg_daily_units_90d,
    round(cover.days_of_cover, 1)           as days_of_cover,
    case
        when cover.days_of_cover is null then '5. Không bán trong 90 ngày'
        when cover.days_of_cover < 30 then '1. Dưới 30 ngày'
        when cover.days_of_cover < 90 then '2. 30 đến 90 ngày'
        when cover.days_of_cover < 180 then '3. 90 đến 180 ngày'
        else '4. Trên 180 ngày'
    end                                     as cover_bucket
from inventory
inner join products
    on products.product_key = inventory.product_key
left join latest_abc
    on latest_abc.product_key = inventory.product_key
left join cover
    on cover.product_key = inventory.product_key
