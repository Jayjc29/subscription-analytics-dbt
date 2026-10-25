-- Regression test for the UTC-vs-IST bucketing bug: a signup at or after 18:30 UTC already
-- happened on the next calendar day in IST and must be reported on that day.
with expected as (
    select
        user_id,
        signed_up_at_utc,
        signup_date_ist,
        case
            when extract(hour from signed_up_at_utc) * 60 + extract(minute from signed_up_at_utc) >= 18 * 60 + 30
                then cast({{ dbt.dateadd('day', 1, 'cast(signed_up_at_utc as date)') }} as date)
            else cast(signed_up_at_utc as date)
        end as expected_signup_date_ist
    from {{ ref('stg_users') }}
)

select *
from expected
where signup_date_ist <> expected_signup_date_ist
