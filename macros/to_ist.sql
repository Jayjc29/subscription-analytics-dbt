{#
  Convert a UTC timestamp to IST wall-clock time.
  IST is a fixed UTC+5:30 with no daylight saving, so a fixed offset is exact. For a zone with DST
  this would need a real time-zone conversion instead.
#}
{% macro to_ist(utc_column) %}
    {{ dbt.dateadd('minute', 330, utc_column) }}
{% endmacro %}
