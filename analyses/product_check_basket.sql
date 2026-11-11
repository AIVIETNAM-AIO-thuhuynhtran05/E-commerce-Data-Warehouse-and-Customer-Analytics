-- Are some products bought together more often than chance? Result: no.
-- Lift of a pair = orders with both x total orders / (orders with A x orders with B).
-- Lift 1 means the pair appears together as often as chance predicts.
-- The same statistics are computed on a shuffled copy of fact_sales, where each
-- order line gets a product from a random other line (same order sizes, same
-- product popularity, no real association). If real and shuffled look alike,
-- the pairs carry no signal.

with real_lines as (

    select order_id, product_key from {{ ref('fact_sales') }}

),

-- Deterministic shuffle: sort order ids and product keys by two different hashes
-- and pair them by position.
shuffled_lines as (

    select orders.order_id, products.product_key
    from (
        select order_id, row_number() over (order by hash(order_item_id, 'a')) as position
        from {{ ref('fact_sales') }}
    ) as orders
    inner join (
        select product_key, row_number() over (order by hash(order_item_id, 'b')) as position
        from {{ ref('fact_sales') }}
    ) as products
        on orders.position = products.position

),

lines as (

    select distinct 'real' as dataset, order_id, product_key from real_lines
    union all
    select distinct 'shuffled', order_id, product_key from shuffled_lines

),

order_counts as (

    select dataset, count(distinct order_id) as orders from lines group by dataset

),

product_counts as (

    select dataset, product_key, count(*) as orders_with_product
    from lines group by dataset, product_key

),

pairs as (

    select a.dataset, a.product_key as product_a, b.product_key as product_b,
           count(*) as orders_with_both
    from lines as a
    inner join lines as b
        on a.dataset = b.dataset
        and a.order_id = b.order_id
        and a.product_key < b.product_key
    group by a.dataset, a.product_key, b.product_key

),

lift as (

    select
        pairs.dataset,
        pairs.orders_with_both,
        pairs.orders_with_both * order_counts.orders * 1.0
            / (count_a.orders_with_product * count_b.orders_with_product) as lift
    from pairs
    inner join order_counts on pairs.dataset = order_counts.dataset
    inner join product_counts as count_a
        on pairs.dataset = count_a.dataset and pairs.product_a = count_a.product_key
    inner join product_counts as count_b
        on pairs.dataset = count_b.dataset and pairs.product_b = count_b.product_key

)

-- Only pairs bought together in at least 20 orders, so lift is not driven by
-- one or two orders.
select
    dataset,
    count(*)                                as pairs_with_20_plus_orders,
    round(avg(lift), 3)                     as avg_lift,
    round(max(lift), 2)                     as max_lift,
    count(*) filter (where lift > 1.5)      as pairs_lift_above_1_5,
    count(*) filter (where lift < 0.67)     as pairs_lift_below_0_67
from lift
where orders_with_both >= 20
group by dataset
order by dataset
