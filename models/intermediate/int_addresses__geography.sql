-- =============================================================================
-- int_addresses__geography
-- =============================================================================
-- Grain: mỗi địa chỉ một dòng (9.000 địa chỉ).
--
-- Model gắn mỗi địa chỉ với một "vị trí địa lý" (quốc gia, bang, thành phố,
-- mã bưu chính) và tạo khoá geography_key cho vị trí đó.
--   - fact_orders và fact_sales dùng address_id -> geography_key để biết đơn
--     được giao tới đâu.
--   - dim_geography lấy các vị trí khác nhau từ model này làm dimension.
--
-- Vì sao bỏ số nhà, tên đường?
--   Dimension địa lý dùng để phân tích theo khu vực, không cần biết nhà cụ
--   thể của ai. Bỏ phần đường phố đi thì dim_geography chứa vị trí, không chứa
--   địa chỉ cá nhân. Nhiều địa chỉ ở cùng một khu sẽ dùng chung một
--   geography_key: 9.000 địa chỉ được gom lại còn 2.536 vị trí.
--   Ví dụ: 19 địa chỉ cùng thuộc US / CA / Los Angeles / 90016 chung một khoá.
-- =============================================================================

-- Địa chỉ đã làm sạch ở staging (state_province đã viết hoa, đã trim).
with addresses as (

    select * from {{ ref('stg_ecommerce__addresses') }}

),

-- Bảng quốc gia, để đổi country_id thành mã và tên quốc gia.
countries as (

    select * from {{ ref('stg_ecommerce__countries') }}

)

select
    addresses.address_id,

    -- Surrogate key: macro dbt_utils.generate_surrogate_key nối 4 cột lại rồi
    -- băm MD5 thành một chuỗi, ví dụ 'b99e18ef36112d52eae3a2f5f2625a5f'.
    -- Cùng 4 giá trị thì luôn ra cùng một khoá, nên các địa chỉ cùng vị trí
    -- tự động dùng chung khoá. Macro cũng xử lý null, nên cột nào rỗng vẫn
    -- tạo được khoá.
    {{ dbt_utils.generate_surrogate_key([
        'countries.country_code',
        'addresses.state_province',
        'addresses.city',
        'addresses.postal_code'
    ]) }}                  as geography_key,

    -- các thuộc tính của vị trí, đưa sang dim_geography
    countries.country_code,
    countries.country_name,
    addresses.state_province,
    addresses.city,
    addresses.postal_code
from addresses
-- left join để giữ địa chỉ dù không tìm thấy quốc gia
-- (hiện tại mọi địa chỉ đều có quốc gia)
left join countries
    on addresses.country_id = countries.country_id
