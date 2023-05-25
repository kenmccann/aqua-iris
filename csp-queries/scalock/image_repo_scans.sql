--Top repositories by number of scans
select rr.name, count(scans.id) as scans
from scans
join registry_images ri on ri.id = scans.image_id
join registry_repositories rr on rr.id = ri.repository_id
where type = 'image'
group by rr.name
order by scans DESC
LIMIT 10
