-- Month-end MRR from the subscription history, plus the month's new and churned subscriptions.
-- Months are IST calendar months, like every other reporting model.
with months as (
    {{ dbt.date_spine(
        datepart="month",
        start_date="cast('" ~ var('reporting_start') ~ "' as date)",
        end_date="cast('" ~ var('reporting_end') ~ "' as date)"
    ) }}
),

month_bounds as (
    select
        cast(date_month as date) as revenue_month,
        {{ dbt.dateadd('month', 1, 'cast(date_month as date)') }} as next_month_start
    from months
),

history as (
    select
        user_id,
        status,
        mrr_usd,
        {{ to_ist('valid_from_utc') }} as valid_from_ist,
        {{ to_ist('valid_to_utc') }} as valid_to_ist
    from {{ ref('int_subscription_history') }}
),

-- A subscription counts towards a month if the version in force at the end of that month is active.
month_end_state as (
    select
        m.revenue_month,
        count(case when h.status = 'active' then h.user_id end) as active_subscriptions,
        coalesce(sum(case when h.status = 'active' then h.mrr_usd end), 0) as mrr_usd
    from month_bounds as m
    left join history as h
        on h.valid_from_ist < m.next_month_start
        and (h.valid_to_ist is null or h.valid_to_ist >= m.next_month_start)
    group by m.revenue_month
),

movements as (
    select
        cast({{ dbt.date_trunc('month', to_ist('event_at_utc')) }} as date) as revenue_month,
        sum(case when event_type = 'converted' then 1 else 0 end) as new_subscriptions,
        sum(case when event_type = 'canceled' then 1 else 0 end) as churned_subscriptions
    from {{ ref('stg_subscription_events') }}
    group by 1
)

select
    s.revenue_month,
    s.active_subscriptions,
    s.mrr_usd,
    coalesce(m.new_subscriptions, 0) as new_subscriptions,
    coalesce(m.churned_subscriptions, 0) as churned_subscriptions
from month_end_state as s
left join movements as m on s.revenue_month = m.revenue_month
