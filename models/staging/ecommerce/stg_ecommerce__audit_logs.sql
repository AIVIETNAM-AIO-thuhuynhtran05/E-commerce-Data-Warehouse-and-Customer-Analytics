with source as (

    select * from {{ source('ecommerce_raw', 'audit_logs') }}

),

renamed as (

    select
        id                              as audit_log_id,
        user_id                         as performed_by_user_id,
        lower(trim(table_affected))     as table_affected,
        record_id,
        lower(trim(action))             as action,
        cast(performed_at as timestamp) as performed_at
    from source

)

select * from renamed
