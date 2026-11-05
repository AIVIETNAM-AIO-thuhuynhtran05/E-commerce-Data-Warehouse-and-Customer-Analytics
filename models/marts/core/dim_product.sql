select
    p.id as product_id,
    p.sku,
    p.slug,
    p.name as product_name,
    p.description,
    p.is_active,
    p.price,
    p.compare_at_price,
    p.category_id,
    c.name as category_name,
    c.parent_category_id,
    p.brand_id,
    b.name as brand_name
from {{ ref('stg_ecommerce__products') }} as p
left join {{ ref('stg_ecommerce__categories') }} as c
    on p.category_id = c.id
left join {{ ref('stg_ecommerce__brands') }} as b
    on p.brand_id = b.id
