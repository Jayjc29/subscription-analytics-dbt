with users as (
    select * from {{ ref('stg_users') }}
),

trials as (
    select * from {{ ref('int_trial_activation') }}
),

current_subscription as (
    select user_id, plan, status, mrr_usd
    from {{ ref('int_subscription_history') }}
    where is_current
)

select
    u.user_id,
    u.signed_up_at_utc,
    u.signup_date_ist,
    {{ ist_week_start('u.signed_up_at_utc') }} as signup_week_ist,
    u.country_code,
    u.acquisition_channel,
    t.is_activated,
    t.is_converted,
    t.converted_at_utc,
    coalesce(s.status, 'free') as subscription_status,
    s.plan as current_plan,
    coalesce(s.mrr_usd, 0) as current_mrr_usd
from users as u
left join trials as t on u.user_id = t.user_id
left join current_subscription as s on u.user_id = s.user_id
