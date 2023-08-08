--Incidents by detection type
SELECT
  CASE
   WHEN type = 'Runtime' THEN 'Container'
   WHEN type = 'host.runtime' THEN 'VM'
   WHEN type = 'Docker' THEN 'Container'
   ELSE 'VM'
  END as Workload,
  lower(category) as Category, lower(action) as Action,
COALESCE(data ->>'signature_name',data ->>'control') as Control,
 CASE
  WHEN data ->>'result' = '2' THEN 'Blocked'
  ELSE 'Detected'
 END as response,
count(*) as event_count,
max (id) as latest_id,
max(to_timestamp(createtime)) as latest_date
FROM public.audit
where
  (type = 'Runtime' OR
  type = 'host.runtime' OR
  type = 'Malware' OR
  type = 'Docker')
  AND action != 'Scan'
  AND COALESCE(data ->>'signature_name',data ->>'control') is not null
group by type,category, action, Control, response
ORDER BY event_count DESC