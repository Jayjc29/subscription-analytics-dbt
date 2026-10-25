{#
  Type 2 history check: within each key, a row's validity window must end at or before the next
  row starts, and only the latest row may be open-ended.
#}
{% test no_overlapping_windows(model, partition_by, valid_from, valid_to) %}
with ordered as (
    select
        {{ partition_by }} as entity_key,
        {{ valid_from }} as valid_from,
        {{ valid_to }} as valid_to,
        lead({{ valid_from }}) over (partition by {{ partition_by }} order by {{ valid_from }}) as next_valid_from
    from {{ model }}
)
select *
from ordered
where next_valid_from is not null
  and (valid_to is null or valid_to > next_valid_from)
{% endtest %}
