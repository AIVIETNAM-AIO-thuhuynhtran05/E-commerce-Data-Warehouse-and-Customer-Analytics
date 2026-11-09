-- =============================================================================
-- dim_geography
-- =============================================================================
-- Grain: mỗi vị trí (quốc gia / bang / thành phố / mã bưu chính) một dòng,
-- 2.536 vị trí.
--
-- Dimension địa lý nơi giao hàng. fact_orders và fact_sales nối vào đây qua
-- ship_to_geography_key.
--
-- int_addresses__geography có mỗi địa chỉ một dòng (9.000 dòng), và nhiều địa
-- chỉ dùng chung một geography_key. select distinct gom các dòng trùng lại
-- để mỗi vị trí chỉ còn một dòng, tức đúng grain của dimension này.
-- Test unique trên geography_key đảm bảo việc gom này đúng.
-- =============================================================================

select distinct
    geography_key,
    country_code,
    country_name,
    state_province,
    city,
    postal_code
from {{ ref('int_addresses__geography') }}
