with source as (
    select * from {{ source('raw', 'product_events') }}
),

-- Clients occasionally re-send an event. Keep the first copy that was ingested.
deduplicated as (
    select
        *,
        row_number() over (
            partition by event_id
            order by cast(ingested_at_utc as timestamp)
        ) as copy_number
    from source
)

select
    event_id,
    user_id,
    lower(event_type) as event_type,
    cast(event_at_utc as timestamp) as event_at_utc,
    cast(ingested_at_utc as timestamp) as ingested_at_utc,
    cast({{ to_ist('cast(event_at_utc as timestamp)') }} as date) as event_date_ist
from deduplicated
where copy_number = 1
