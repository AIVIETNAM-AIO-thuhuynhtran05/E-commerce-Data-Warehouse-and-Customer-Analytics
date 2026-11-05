-- Grain: one row per customer.
-- RFM scores use recognized revenue orders only, relative to the last order
-- date in the data (the dataset is historical, so "today" would be misleading).

with customers as (

    select * from {{ ref('dim_customer') }}

),

orders as (

    select
        orders.customer_key,
        dates.date_day as order_date,
        orders.order_total,
        orders.counts_as_revenue
    from {{ ref('fact_orders') }} as orders
    inner join {{ ref('dim_date') }} as dates
        on orders.order_date_key = dates.date_key

),

reference_date as (

    select max(order_date) as as_of_date from orders

),

order_metrics as (

    select
        customer_key,
        count(*)                                                     as order_count,
        count(*) filter (where counts_as_revenue)                    as revenue_order_count,
        sum(order_total)                                             as lifetime_order_value,
        sum(case when counts_as_revenue then order_total else 0 end) as lifetime_revenue,
        min(order_date)                                              as first_order_date,
        max(order_date)                                              as last_order_date,
        max(order_date) filter (where counts_as_revenue)             as last_revenue_order_date
    from orders
    group by customer_key

),

reviews as (

    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
        count(*)    as review_count,
        avg(rating) as average_review_rating
    from {{ ref('stg_ecommerce__product_reviews') }}
    group by 1

),

rfm as (

    select
        order_metrics.customer_key,
        date_diff('day', order_metrics.last_revenue_order_date, reference_date.as_of_date) as recency_days,
        ntile(5) over (order by order_metrics.last_revenue_order_date)                     as recency_score,
        ntile(5) over (order by order_metrics.revenue_order_count)                         as frequency_score,
        ntile(5) over (order by order_metrics.lifetime_revenue)                            as monetary_score
    from order_metrics
    cross join reference_date
    where order_metrics.revenue_order_count > 0

)

select
    customers.customer_key,
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    customers.email,
    customers.signup_date,
    customers.first_order_cohort_month,
    coalesce(order_metrics.order_count, 0)                         as order_count,
    coalesce(order_metrics.revenue_order_count, 0)                 as revenue_order_count,
    coalesce(order_metrics.lifetime_order_value, 0)                as lifetime_order_value,
    coalesce(order_metrics.lifetime_revenue, 0)                    as lifetime_revenue,
    order_metrics.lifetime_revenue
        / nullif(order_metrics.revenue_order_count, 0)             as average_order_value,
    order_metrics.first_order_date,
    order_metrics.last_order_date,
    rfm.recency_days,
    rfm.recency_score,
    rfm.frequency_score,
    rfm.monetary_score,
    case
        when rfm.customer_key is null                                  then 'No revenue orders'
        when rfm.recency_score >= 4 and rfm.frequency_score >= 4       then 'Champions'
        when rfm.frequency_score >= 4                                  then 'Loyal'
        when rfm.recency_score >= 4                                    then 'Recent'
        when rfm.recency_score <= 2 and rfm.frequency_score >= 3       then 'At risk'
        when rfm.recency_score <= 2                                    then 'Hibernating'
        else 'Needs attention'
    end                                                            as rfm_segment,
    coalesce(reviews.review_count, 0)                              as review_count,
    round(reviews.average_review_rating, 2)                        as average_review_rating
from customers
left join order_metrics
    on customers.customer_key = order_metrics.customer_key
left join rfm
    on customers.customer_key = rfm.customer_key
left join reviews
    on customers.customer_key = reviews.customer_key
