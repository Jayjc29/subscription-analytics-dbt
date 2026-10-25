-- Type 2 history of each paid subscription, derived from the event log: one row per state,
-- valid from the event that started it until the next event for the same user.
with paid_events as (
    select user_id, event_type, plan, mrr_usd, event_at_utc
    from {{ ref('stg_subscription_events') }}
    where event_type in ('converted', 'plan_changed', 'canceled')
),

windowed as (
    select
        *,
        lead(event_at_utc) over (partition by user_id order by event_at_utc) as next_event_at_utc
    from paid_events
)

select
    {{ dbt.hash(dbt.concat(["user_id", "'|'", "cast(event_at_utc as " ~ dbt.type_string() ~ ")"])) }} as subscription_version_id,
    user_id,
    plan,
    case when event_type = 'canceled' then 'canceled' else 'active' end as status,
    case when event_type = 'canceled' then cast(0 as decimal(10, 2)) else mrr_usd end as mrr_usd,
    event_at_utc as valid_from_utc,
    next_event_at_utc as valid_to_utc,
    next_event_at_utc is null as is_current
from windowed
