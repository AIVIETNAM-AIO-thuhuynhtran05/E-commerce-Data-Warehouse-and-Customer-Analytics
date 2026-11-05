-- Ship-to locations, one row per country / state / city / postal code.

select distinct
    geography_key,
    country_code,
    country_name,
    state_province,
    city,
    postal_code
from {{ ref('int_addresses__geography') }}
