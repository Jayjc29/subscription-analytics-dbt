with source as (
    select * from {{ source('raw', 'users') }}
)

select
    user_id,
    cast(signup_at_utc as timestamp) as signed_up_at_utc,
    {{ to_ist('cast(signup_at_utc as timestamp)') }} as signed_up_at_ist,
    cast({{ to_ist('cast(signup_at_utc as timestamp)') }} as date) as signup_date_ist,
    upper(country) as country_code,
    lower(acquisition_channel) as acquisition_channel
from source
