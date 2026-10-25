{# Monday-start reporting week, computed on the IST date rather than the UTC date. #}
{% macro ist_week_start(utc_column) %}
    cast({{ dbt.date_trunc('week', to_ist(utc_column)) }} as date)
{% endmacro %}
