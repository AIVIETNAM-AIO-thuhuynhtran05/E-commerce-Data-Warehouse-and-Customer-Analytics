-- Can sales since product launch be measured? Result: no.
-- Many products have sales dated before their created_at, so created_at is not
-- a launch date. Grouped by the year the product was created.

select
    year(products.product_created_at)                                   as created_year,
    count(distinct products.product_id)                                 as products,
    count(*)                                                            as order_lines,
    count(*) filter (where items.ordered_at < products.product_created_at) as lines_before_created,
    round(100.0 * count(*) filter (where items.ordered_at < products.product_created_at)
          / count(*), 1)                                                as pct_before_created
from {{ ref('dim_product') }} as products
inner join {{ ref('int_order_items__enriched') }} as items
    on products.product_id = items.product_id
group by 1
order by 1
