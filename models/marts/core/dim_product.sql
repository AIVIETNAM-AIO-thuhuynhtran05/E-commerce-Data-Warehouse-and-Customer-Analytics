-- Current product attributes (SCD type 1). Price history is kept separately
-- in the snap_products snapshot.

with products as (

    select * from {{ ref('stg_ecommerce__products') }}

),

categories as (

    select * from {{ ref('stg_ecommerce__categories') }}

),

brands as (

    select * from {{ ref('stg_ecommerce__brands') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['products.product_id']) }} as product_key,
    products.product_id,
    products.sku,
    products.product_name,
    products.product_slug,
    categories.category_id,
    categories.category_name,
    brands.brand_id,
    brands.brand_name,
    products.price                                          as current_price,
    products.compare_at_price,
    products.is_active,
    products.created_at                                     as product_created_at
from products
left join categories
    on products.category_id = categories.category_id
left join brands
    on products.brand_id = brands.brand_id
