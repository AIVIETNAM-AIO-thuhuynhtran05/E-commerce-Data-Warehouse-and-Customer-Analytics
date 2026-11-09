-- Same rule for every return request, whatever its status: the returned amount
-- is at most what the customer paid for the order item.

select
    returns.return_id,
    returns.order_item_id,
    returns.returned_amount,
    sales.net_amount
from {{ ref('fact_returns') }} as returns
inner join {{ ref('fact_sales') }} as sales
    on returns.order_item_id = sales.order_item_id
where returns.returned_amount > sales.net_amount + 0.01
