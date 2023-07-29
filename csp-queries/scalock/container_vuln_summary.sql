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
)
SELECT
       DISTINCT on (c.id)
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
WHERE c.status = 'running'

