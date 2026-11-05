select cast(date_day as date) as date_day
from generate_series(
    (select min(cast(created_at as date)) from {{ ref('stg_ecommerce__orders') }}),
    (select max(cast(created_at as date)) from {{ ref('stg_ecommerce__orders') }}),
    interval 1 day
) as dates(date_day)
