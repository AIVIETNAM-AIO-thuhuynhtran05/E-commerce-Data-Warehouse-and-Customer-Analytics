-- Calendar dimension, one row per day. The range comes from project vars so
-- it covers every order, payment, shipment and return date.

with days as (

    select cast(date_day as date) as date_day
    from generate_series(
        cast('{{ var("calendar_start_date") }}' as date),
        cast('{{ var("calendar_end_date") }}' as date),
        interval 1 day
    ) as dates (date_day)

)

select
    cast(strftime(date_day, '%Y%m%d') as integer) as date_key,
    date_day,
    year(date_day)                                as year,
    quarter(date_day)                             as quarter,
    month(date_day)                               as month,
    strftime(date_day, '%B')                      as month_name,
    strftime(date_day, '%Y-%m')                   as year_month,
    weekofyear(date_day)                          as iso_week,
    isodow(date_day)                              as day_of_week,
    strftime(date_day, '%A')                      as day_name,
    isodow(date_day) in (6, 7)                    as is_weekend,
    date_trunc('month', date_day)                 as month_start_date
from days
