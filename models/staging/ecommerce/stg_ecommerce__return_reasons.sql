with source as (

    select * from {{ source('ecommerce_raw', 'return_reasons') }}

),

renamed as (

    select
        id                as return_reason_id,
        trim(reason_text) as return_reason
    from source

)

select * from renamed
