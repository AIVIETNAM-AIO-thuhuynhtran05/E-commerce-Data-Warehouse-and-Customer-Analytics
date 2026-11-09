-- =============================================================================
-- dim_date
-- =============================================================================
-- Grain: mỗi ngày một dòng, 2.922 ngày (2019-01-01 đến 2026-12-31).
--
-- Dimension lịch. Đây là dimension duy nhất không đọc từ dữ liệu nguồn mà tự
-- sinh ra. Mọi fact lưu ngày dưới dạng số nguyên date_key (ví dụ 20240315)
-- rồi nối vào đây để lấy năm, quý, tháng, thứ trong tuần...
--
-- Vì sao cần bảng lịch riêng thay vì dùng thẳng cột ngày?
--   - Báo cáo thường cần "doanh thu theo quý", "cuối tuần so với ngày thường".
--     Tính sẵn ở đây thì mọi báo cáo dùng chung, không ai phải tự viết lại.
--   - Ngày không có đơn nào vẫn có dòng trong bảng lịch, nên biểu đồ theo ngày
--     không bị mất ngày.
--
-- Khoảng ngày lấy từ biến calendar_start_date, calendar_end_date trong
-- dbt_project.yml. Khoảng này phải bao hết mọi ngày trong các fact (đơn hàng
-- hiện nằm trong 2021 đến 2025), nếu không phép join với dim_date sẽ mất dòng.
-- =============================================================================

-- Sinh dãy ngày liên tục, mỗi ngày một dòng.
-- var(...) là hàm Jinja đọc biến trong dbt_project.yml lúc compile.
with days as (

    select cast(date_day as date) as date_day
    from generate_series(
        cast('{{ var("calendar_start_date") }}' as date),
        cast('{{ var("calendar_end_date") }}' as date),
        interval 1 day
    ) as dates (date_day)

)

select
    -- khoá dạng số YYYYMMDD, ví dụ 2024-03-15 -> 20240315.
    -- Macro date_key trong các fact tạo đúng định dạng này để join được.
    cast(strftime(date_day, '%Y%m%d') as integer) as date_key,
    date_day,
    year(date_day)                                as year,
    quarter(date_day)                             as quarter,       -- 1 đến 4
    month(date_day)                               as month,         -- 1 đến 12
    strftime(date_day, '%B')                      as month_name,    -- 'March'
    strftime(date_day, '%Y-%m')                   as year_month,    -- '2024-03'
    weekofyear(date_day)                          as iso_week,
    isodow(date_day)                              as day_of_week,   -- 1 = thứ Hai, 7 = Chủ nhật
    strftime(date_day, '%A')                      as day_name,      -- 'Friday'
    isodow(date_day) in (6, 7)                    as is_weekend,    -- thứ Bảy, Chủ nhật
    date_trunc('month', date_day)                 as month_start_date
from days
