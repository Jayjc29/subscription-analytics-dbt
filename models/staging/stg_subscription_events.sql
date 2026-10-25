with source as (
    select * from {{ source('raw', 'subscription_events') }}
)

select
    event_id as subscription_event_id,
    user_id,
    lower(event_type) as event_type,
    lower(plan) as plan,
    cast(mrr_usd as decimal(10, 2)) as mrr_usd,
    cast(event_at_utc as timestamp) as event_at_utc
from source
