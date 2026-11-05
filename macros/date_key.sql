{# Integer date key in YYYYMMDD form, matching dim_date.date_key. #}
{% macro date_key(column_name) -%}
    cast(strftime(cast({{ column_name }} as date), '%Y%m%d') as integer)
{%- endmacro %}
