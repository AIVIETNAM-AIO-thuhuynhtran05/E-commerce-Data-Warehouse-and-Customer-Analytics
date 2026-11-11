-- =============================================================================
-- mart_product_abc
-- =============================================================================
-- Grain: mỗi sản phẩm mỗi năm có bán hàng một dòng (400 sản phẩm x số năm).
--
-- Phân nhóm ABC theo doanh thu ghi nhận trong năm:
--   A: các sản phẩm tạo nên 80% doanh thu đầu tiên (xếp từ cao xuống thấp)
--   B: 15% tiếp theo
--   C: 5% cuối, gồm cả sản phẩm không bán được trong năm
-- Một sản phẩm thuộc nhóm theo phần luỹ kế TRƯỚC nó, nên sản phẩm vắt qua
-- ngưỡng 80% vẫn được tính là A.
--
-- Kèm thứ hạng năm trước và tình trạng tồn kho hiện tại để trang Power BI
-- "Tập trung doanh thu" chỉ cần đọc một bảng. Chú ý: tồn kho là ảnh chụp hiện
-- tại, giống nhau ở mọi năm.
-- =============================================================================

with products as (

    select product_key, product_name, category_name, brand_name, is_active
    from {{ ref('dim_product') }}

),

-- Doanh thu theo sản phẩm và năm.
yearly_sales as (

    select
        dates.year,
        sales.product_key,
        sum(sales.recognized_revenue)   as recognized_revenue,
        sum(sales.quantity)             as units_sold
    from {{ ref('fact_sales') }} as sales
    inner join {{ ref('dim_date') }} as dates
        on sales.order_date_key = dates.date_key
    group by dates.year, sales.product_key

),

-- Chỉ lấy các năm có bán hàng, rồi ghép với mọi sản phẩm để sản phẩm
-- không bán được trong năm vẫn có dòng (doanh thu 0, nhóm C).
years as (

    select distinct year from yearly_sales

),

product_years as (

    select
        years.year,
        products.*,
        coalesce(yearly_sales.recognized_revenue, 0)    as recognized_revenue,
        coalesce(yearly_sales.units_sold, 0)            as units_sold
    from years
    cross join products
    left join yearly_sales
        on yearly_sales.year = years.year
        and yearly_sales.product_key = products.product_key

),

ranked as (

    select
        *,
        row_number() over (
            partition by year order by recognized_revenue desc, product_key
        ) as revenue_rank,
        recognized_revenue
            / nullif(sum(recognized_revenue) over (partition by year), 0)
            as revenue_share
    from product_years

),

cumulative as (

    select
        *,
        sum(revenue_share) over (
            partition by year order by revenue_rank
            rows between unbounded preceding and current row
        ) as cumulative_share
    from ranked

),

-- Tồn kho hiện tại gộp về cấp sản phẩm. Đi qua model intermediate để mỗi kho
-- chỉ được đếm một lần (nguồn có bản ghi trùng cặp sản phẩm và kho).
inventory as (

    select
        product_key,
        count(*)                                as warehouse_count,
        count(*) filter (where needs_reorder)   as warehouses_below_reorder,
        cast(sum(quantity_available) as bigint) as quantity_available
    from {{ ref('int_inventory__product_warehouse') }}
    group by product_key

)

select
    cumulative.year,
    cumulative.product_key,
    cumulative.product_name,
    cumulative.category_name,
    cumulative.brand_name,
    cumulative.is_active,
    cumulative.recognized_revenue,
    cumulative.units_sold,
    cumulative.revenue_rank,
    cumulative.revenue_share,
    cumulative.cumulative_share,
    case
        when cumulative.cumulative_share - cumulative.revenue_share < 0.80 then 'A'
        when cumulative.cumulative_share - cumulative.revenue_share < 0.95 then 'B'
        else 'C'
    end as abc_class,
    previous.revenue_rank                               as previous_year_rank,
    coalesce(inventory.warehouse_count, 0)              as warehouse_count,
    coalesce(inventory.warehouses_below_reorder, 0)     as warehouses_below_reorder,
    coalesce(inventory.quantity_available, 0)           as quantity_available
from cumulative
left join cumulative as previous
    on previous.product_key = cumulative.product_key
    and previous.year = cumulative.year - 1
left join inventory
    on inventory.product_key = cumulative.product_key
