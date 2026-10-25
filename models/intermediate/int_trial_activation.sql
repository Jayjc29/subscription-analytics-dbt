-- One row per trial with the two signals that drive conversion analysis: did the user reach the
-- activation bar in their first 7 days, and did they convert to paid.
with users as (
    select user_id, signed_up_at_utc
    from {{ ref('stg_users') }}
),

key_actions as (
    select
        e.user_id,
        count(*) as key_actions_first_7_days
    from {{ ref('stg_product_events') }} as e
    inner join users as u on e.user_id = u.user_id
    where e.event_type in ('create_project', 'upload_file', 'export_report')
      and e.event_at_utc < {{ dbt.dateadd('day', 7, 'u.signed_up_at_utc') }}
    group by e.user_id
),

conversions as (
    select user_id, min(event_at_utc) as converted_at_utc
    from {{ ref('stg_subscription_events') }}
    where event_type = 'converted'
    group by user_id
)

select
    u.user_id,
    u.signed_up_at_utc as trial_started_at_utc,
    {{ dbt.dateadd('day', 14, 'u.signed_up_at_utc') }} as trial_ended_at_utc,
    coalesce(k.key_actions_first_7_days, 0) as key_actions_first_7_days,
    coalesce(k.key_actions_first_7_days, 0) >= {{ var('activation_threshold') }} as is_activated,
    c.converted_at_utc,
    c.converted_at_utc is not null as is_converted
from users as u
left join key_actions as k on u.user_id = k.user_id
left join conversions as c on u.user_id = c.user_id
