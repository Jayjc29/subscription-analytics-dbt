{#
  Expose the landing CSVs in data/raw/ as external tables in a `raw` schema, with explicit column
  types so nothing depends on schema inference. Only for the local Spark target: on Databricks the
  raw tables would be loaded separately (see README).
#}
{% macro register_raw_tables() %}
    {% if target.type != 'spark' %}
        {{ return('') }}
    {% endif %}

    {% set raw_tables = {
        'users': 'user_id string, signup_at_utc timestamp, country string, acquisition_channel string',
        'subscription_events': 'event_id string, user_id string, event_type string, plan string, mrr_usd int, event_at_utc timestamp',
        'product_events': 'event_id string, user_id string, event_type string, event_at_utc timestamp, ingested_at_utc timestamp',
    } %}

    {#- Spark resolves a relative path against the warehouse folder, so anchor it at the project root. -#}
    {% set raw_dir = env_var('RAW_DATA_DIR', env_var('PWD') ~ '/data/raw') %}

    {% do run_query('create schema if not exists raw') %}
    {% for name, columns in raw_tables.items() %}
        {#- Re-registered on every run so the table always points at the current files. -#}
        {% do run_query('drop table if exists raw.' ~ name) %}
        {% do run_query(
            'create table raw.' ~ name ~ ' (' ~ columns ~ ') using csv '
            ~ "options (path '" ~ raw_dir ~ "/" ~ name ~ ".csv', header 'true', timestampFormat 'yyyy-MM-dd HH:mm:ss')"
        ) %}
    {% endfor %}
{% endmacro %}
