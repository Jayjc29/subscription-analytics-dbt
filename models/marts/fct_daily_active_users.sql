{{
    config(
        materialized='incremental',
        unique_key='activity_date_ist',
        incremental_strategy='delete+insert',
        on_schema_change='fail'
    )
}}

-- Events can land up to a few days late, so each incremental run recomputes the most recent days
-- already in the table instead of only appending new dates. Older days are never touched.
with events as (
    select user_id, event_date_ist
    from {{ ref('stg_product_events') }}
    {% if is_incremental() %}
    where event_date_ist >= (
        select {{ dbt.dateadd('day', -1 * var('late_arrival_days'), 'max(activity_date_ist)') }}
        from {{ this }}
    )
    {% endif %}
)

select
    event_date_ist as activity_date_ist,
    count(distinct user_id) as daily_active_users,
    count(*) as events
from events
group by event_date_ist
