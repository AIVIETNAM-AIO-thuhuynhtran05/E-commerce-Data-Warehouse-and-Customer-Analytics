-- Customers with the same input value must get the same RFM score. Scores come
-- from fixed thresholds (F) and percentile cut-offs (R, M), so a tie can never
-- be split across two scores, and the result is the same on every run.
-- Returns every input value that maps to more than one score.

with scored as (

    select recency_days, revenue_order_count, lifetime_revenue,
           recency_score, frequency_score, monetary_score
    from {{ ref('mart_customer_360') }}
    where recency_score is not null

)

select 'recency' as score, cast(recency_days as varchar) as input_value
from scored group by recency_days having count(distinct recency_score) > 1

union all

select 'frequency', cast(revenue_order_count as varchar)
from scored group by revenue_order_count having count(distinct frequency_score) > 1

union all

select 'monetary', cast(lifetime_revenue as varchar)
from scored group by lifetime_revenue having count(distinct monetary_score) > 1
