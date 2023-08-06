--Incidents by detection type
SELECT
  CASE
   WHEN type = 'Runtime' THEN 'Container'
   WHEN type = 'host.runtime' THEN 'VM'
   ELSE 'VM'
  END as Workload,
  lower(category) as Category, lower(action) as Action,
COALESCE(data ->>'signature_name',data ->>'control') as Control,
 CASE
  WHEN data ->>'result' = '2' THEN 'Blocked'
  ELSE 'Detected'
 END as response,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '7 days' ) as  Events_7_days,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '30 days' ) as  Events_30_days,
count(*) FILTER (WHERE to_timestamp(createtime) > current_date - interval '180 days' ) as  Events_180_days
FROM public.audit
where
  (type = 'Runtime' OR
  type = 'host.runtime' OR
  type = 'Malware')
  AND action != 'Scan'
group by type,category, action, Control, response
ORDER BY events_7_days DESC