--Top 10 repos by Vulnerability severity distirbution
WITH  image_vuln_summary as (
        SELECT
     DISTINCT im.image_id,
	 ri.name as image_name,
     rr.name as repo_name,
     CASE
       WHEN c.image_name is null THEN 0
       ELSE 1
     END as containers_exist,
     scans.crit_vulns,
     scans.high_vulns,
     scans.med_vulns,
     scans.low_vulns,
     scans.neg_vulns,
     scans.crit_vulns + scans.high_vulns + scans.med_vulns + scans.low_vulns + scans.neg_vulns as total_vulns
   FROM containers c
   FULL OUTER JOIN image_metadata im  ON im.docker_id = c.oci_image_id
   JOIN registry_images ri ON ri.id = im.image_id
   JOIN registry_repositories rr ON ri.repository_id = rr.id
   JOIN scans on scans.image_id = im.image_id AND scans.type = 'image'
)

select
  repo_name,
  count(image_name) as num_images,
  sum(total_vulns)::int as total_vulns,
  TO_CHAR(SUM(crit_vulns) / (sum(total_vulns)+0.1)::real *100, '990D00%') as critical,
  TO_CHAR(SUM(high_vulns) / (sum(total_vulns)+0.1)::real *100, '990D00%') as high,
  TO_CHAR(SUM(med_vulns) / (sum(total_vulns)+0.1)::real *100, '990D00%') as medium,
  TO_CHAR(SUM(low_vulns) / (sum(total_vulns)+0.1)::real *100, '990D00%') as low,
  TO_CHAR(SUM(neg_vulns) / (sum(total_vulns)+0.1)::real *100, '990D00%') as negligible

  from image_vuln_summary
GROUP by repo_name
ORDER by total_vulns DESC
LIMIT 10
