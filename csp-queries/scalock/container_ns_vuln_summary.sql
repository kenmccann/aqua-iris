WITH  image_vuln_summary as (
   SELECT
     im.image_id,
     im.docker_id,
     ri.name as image_name,
     rr.name as repo_name,
     scans.crit_vulns,
     scans.high_vulns,
     scans.med_vulns,
     scans.low_vulns,
     scans.neg_vulns,
     scans.crit_vulns + scans.high_vulns + scans.med_vulns + scans.low_vulns + scans.neg_vulns as total_vulns
   FROM registry_images ri
   JOIN image_metadata im  ON ri.id = im.image_id
   JOIN registry_repositories rr ON ri.repository_id = rr.id
   JOIN scans on scans.image_id = im.image_id AND scans.type = 'image'
),
container_vuln_summary as
(SELECT
       DISTINCT on (c.id)
           c.id,
           c.name as container_name,
           c.level1 as cluster,
           c.level2 as namespace,
       c.level3 as controller,
       c.level3_type as controller_type,
           c.level4 as pod_name,
           to_timestamp(c.create_time) as create_time,
           ivs.*
FROM containers c
JOIN image_vuln_summary ivs on ivs.docker_id = c.oci_image_id
WHERE c.status = 'running')

select
  namespace,
  controller,
  count(distinct cluster) as cluster_count,
  count(distinct id) as container_count,
  count(distinct docker_id) as image_count,
  avg(crit_vulns)::int as avg_crit_vulns,
  avg(high_vulns)::int as avg_high_vulns,
  avg(med_vulns)::int as avg_med_vulns,
  avg(low_vulns)::int as avg_low_vulns,
  avg(neg_vulns)::int as avg_neg_vulns,
  avg(total_vulns)::int as avg_total_vulns
FROM container_vuln_summary cvs
GROUP by namespace, controller

