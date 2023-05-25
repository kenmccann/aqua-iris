--Host audit events by action type
SELECT
action,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '7 days' ) as  Events_7_days,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '30 days' ) as  Events_30_days,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '180 days' ) as  Events_180_days
FROM audit
WHERE type = 'host.runtime' AND category != 'behavioral' AND to_timestamp(createtime) > current_date - interval '180 days' 
GROUP BY action
ORDER BY events_7_days DESC
