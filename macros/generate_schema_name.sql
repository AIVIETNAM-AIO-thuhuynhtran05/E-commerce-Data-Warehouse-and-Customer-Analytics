{#
    Use the custom schema name as-is (staging, core, sales...) instead of
    dbt's default "<target_schema>_<custom_schema>" naming.
    Models without a custom schema fall back to the target schema.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
