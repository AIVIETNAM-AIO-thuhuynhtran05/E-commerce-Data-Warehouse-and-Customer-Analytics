with source as (

    select * from {{ source('ecommerce_raw', 'tax_rates') }}

),

renamed as (

    select
        id                          as tax_rate_id,
        country_id,
        upper(trim(state_province)) as state_province,
        cast(rate as decimal(8, 4)) as tax_rate
    from source

)

select * from renamed
