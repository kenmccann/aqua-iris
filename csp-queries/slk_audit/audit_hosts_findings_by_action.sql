SELECT
 type,
 category,
 action,
 COALESCE(data ->>'signature_name',data ->>'control') as Control,
 CASE
  WHEN data ->>'result' = '2' THEN 'Blocked'
  ELSE 'Detected'
 END as response,
count(*) as event_count,
max (id) as latest_id,
max(to_timestamp(createtime)) as latest_date
FROM public.audit
group by type,category, action, Control, response
ORDER BY event_count DESC
