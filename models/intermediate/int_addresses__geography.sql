-- Maps every address to a location (country, state, city, postal code) and
-- its geography_key. Street-level details are dropped, so dim_geography
-- holds locations rather than personal addresses.

with addresses as (

    select * from {{ ref('stg_ecommerce__addresses') }}

),

countries as (

    select * from {{ ref('stg_ecommerce__countries') }}

)

select
    addresses.address_id,
    {{ dbt_utils.generate_surrogate_key([
        'countries.country_code',
        'addresses.state_province',
        'addresses.city',
        'addresses.postal_code'
    ]) }}                  as geography_key,
    countries.country_code,
    countries.country_name,
    addresses.state_province,
    addresses.city,
    addresses.postal_code
from addresses
left join countries
    on addresses.country_id = countries.country_id
