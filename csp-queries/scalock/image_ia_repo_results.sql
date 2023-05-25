--Top non-compliance of assurance controls by repository
select rr.name as repository_name, count(distinct ri.id) as num_of_images, 
  count( DISTINCT sar.control) as controls_checked,
  --count(  sar.control) FILTER (where sar.failed is false),
  --count(  sar.control) FILTER (where sar.failed is true) ,
  to_char(count( DISTINCT sar.control) FILTER (where sar.failed is false) / count( DISTINCT sar.control)::real * 100, '990D00%') as pass_rate,
  to_char(count( DISTINCT sar.control) FILTER (where sar.failed is true) / count(DISTINCT sar.control)::real * 100, '990D00%') as fail_rate
from scans
join registry_images ri on ri.id = scans.image_id
join registry_repositories rr on rr.id = ri.repository_id
join scan_assurance_results sar on sar.scan_id = scans.id
where type = 'image'
group by rr.name
order by fail_rate DESC
LIMIT 10
