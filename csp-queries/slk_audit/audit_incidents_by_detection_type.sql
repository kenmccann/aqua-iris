--Incidents by detection type
SELECT data ->>'signature_name' as Finding,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '7 days' ) as  Events_7_days,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '30 days' ) as  Events_30_days,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '180 days' ) as  Events_180_days
FROM public.audit
where category = 'behavioral' AND  to_timestamp(createtime) > current_date - interval '180 days' 
group by finding
ORDER BY events_7_days DESC
