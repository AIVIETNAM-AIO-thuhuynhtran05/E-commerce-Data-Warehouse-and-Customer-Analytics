{# Cast a numeric column to a fixed-precision money type. #}
{% macro to_money(column_name) -%}
    cast({{ column_name }} as decimal(18, 2))
{%- endmacro %}
