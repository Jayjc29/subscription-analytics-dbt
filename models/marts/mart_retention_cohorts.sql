-- Share of each signup-month cohort that was active N months after signing up (IST months).
with users as (
    select
        user_id,
        cast({{ dbt.date_trunc('month', 'signup_date_ist') }} as date) as cohort_month
    from {{ ref('stg_users') }}
),

activity as (
    select distinct
        user_id,
        cast({{ dbt.date_trunc('month', 'event_date_ist') }} as date) as activity_month
    from {{ ref('stg_product_events') }}
),

cohort_sizes as (
    select cohort_month, count(*) as cohort_size
    from users
    group by cohort_month
),

active_by_month as (
    select
        u.cohort_month,
        {{ dbt.datediff('u.cohort_month', 'a.activity_month', 'month') }} as months_since_signup,
        count(distinct a.user_id) as active_users
    from users as u
    inner join activity as a on u.user_id = a.user_id
    group by 1, 2
)

select
    a.cohort_month,
    a.months_since_signup,
    s.cohort_size,
    a.active_users,
    round(cast(a.active_users as decimal(10, 4)) / s.cohort_size, 4) as retention_rate
from active_by_month as a
inner join cohort_sizes as s on a.cohort_month = s.cohort_month
