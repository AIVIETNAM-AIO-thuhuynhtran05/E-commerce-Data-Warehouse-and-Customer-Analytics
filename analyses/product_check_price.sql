-- Can price or discount effects be measured? Result: no.
-- Every product sells at a single unit price over 2021-2025, and discounted
-- lines have the same quantity as full-price lines.

select 'Products' as metric, count(*) * 1.0 as value
from (select distinct product_key from {{ ref('fact_sales') }})
union all
select 'Products with one unit_price over all orders', count(*)
from (
    select product_key from {{ ref('fact_sales') }}
    group by product_key having count(distinct unit_price) = 1
)
union all
select 'Avg quantity per line, discounted', round(avg(quantity), 3)
from {{ ref('fact_sales') }} where discount_amount > 0
union all
select 'Avg quantity per line, not discounted', round(avg(quantity), 3)
from {{ ref('fact_sales') }} where discount_amount = 0
union all
select 'Avg discount % on discounted lines', round(100 * avg(discount_amount / nullif(gross_amount, 0)), 1)
from {{ ref('fact_sales') }} where discount_amount > 0
