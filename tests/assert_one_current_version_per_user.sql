select user_id, count(*) as current_versions
from {{ ref('int_subscription_history') }}
where is_current
group by user_id
having count(*) <> 1
