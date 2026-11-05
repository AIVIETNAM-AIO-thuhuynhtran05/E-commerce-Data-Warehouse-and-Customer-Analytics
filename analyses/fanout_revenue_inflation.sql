-- Fan-out: summing an order-level column after joining to order-item grain.
-- Compile with `dbt compile` and run the SQL in target/compiled/.
--
-- order_total lives at order grain. Joining to fact_sales repeats each order
-- once per line, so the "joined" figure is inflated (about 3.7x in this data).

select
    (select sum(order_total) from {{ ref('fact_orders') }})          as correct_total,
    (
        select sum(orders.order_total)
        from {{ ref('fact_orders') }} as orders
        inner join {{ ref('fact_sales') }} as sales
            on orders.order_id = sales.order_id
    )                                                               as fanned_out_total
