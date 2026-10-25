-- Weekly trial cohorts (Monday-start IST weeks): how many trials activated and converted, and how
-- conversion differs for activated versus non-activated trials.
with trials as (
    select
        *,
        {{ ist_week_start('trial_started_at_utc') }} as trial_week_ist
    from {{ ref('int_trial_activation') }}
    -- Only trials that have finished; an in-flight trial isn't a lost conversion yet.
    where trial_ended_at_utc <= (select max(event_at_utc) from {{ ref('stg_subscription_events') }})
)

select
    trial_week_ist,
    count(*) as trials,
    sum(case when is_activated then 1 else 0 end) as activated_trials,
    sum(case when is_converted then 1 else 0 end) as conversions,
    round(avg(case when is_converted then 1.0 else 0.0 end), 4) as conversion_rate,
    round(avg(case when is_activated then case when is_converted then 1.0 else 0.0 end end), 4) as activated_conversion_rate,
    round(avg(case when not is_activated then case when is_converted then 1.0 else 0.0 end end), 4) as non_activated_conversion_rate
from trials
group by trial_week_ist
