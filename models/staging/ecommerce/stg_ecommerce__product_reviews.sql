with source as (

    select * from {{ source('ecommerce_raw', 'product_reviews') }}

),

renamed as (

    select
        id                            as review_id,
        product_id,
        user_id                       as customer_id,
        rating,
        trim(title)                   as review_title,
        trim(comment)                 as review_comment,
        cast(created_at as timestamp) as reviewed_at
    from source

)

select * from renamed
