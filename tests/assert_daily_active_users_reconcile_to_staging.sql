-- The incremental table must match a full recompute from staging, day for day. This is what proves
-- the lookback window is wide enough and the delete+insert merge is correct.
with full_recompute as (
    select
        event_date_ist as activity_date_ist,
        count(distinct user_id) as daily_active_users,
        count(*) as events
    from {{ ref('stg_product_events') }}
    group by event_date_ist
)

select
    coalesce(f.activity_date_ist, i.activity_date_ist) as activity_date_ist,
    f.daily_active_users as expected_users,
    i.daily_active_users as actual_users
from full_recompute as f
full outer join {{ ref('fct_daily_active_users') }} as i
    on f.activity_date_ist = i.activity_date_ist
where f.activity_date_ist is null
   or i.activity_date_ist is null
   or f.daily_active_users <> i.daily_active_users
   or f.events <> i.events
