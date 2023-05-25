--Vulnerability severity distribution in images
WITH  image_vuln_summary as (
	SELECT
     DISTINCT im.image_id,
     ri.name,
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
   JOIN scans on scans.image_id = im.image_id AND scans.type = 'image'
)

select
  CASE
    WHEN containers_exist = 1 THEN 'In running containers'
	WHEN containers_exist = 0 THEN 'In other scanned images'
  END as images,
  TO_CHAR(SUM(crit_vulns) / sum(total_vulns)::real *100, '99D00%') as critical,
  TO_CHAR(SUM(high_vulns) / sum(total_vulns)::real *100, '99D00%') as high,
  TO_CHAR(SUM(med_vulns) / sum(total_vulns)::real *100, '99D00%') as medium,
  TO_CHAR(SUM(low_vulns) / sum(total_vulns)::real *100, '99D00%') as low,
  TO_CHAR(SUM(neg_vulns) / sum(total_vulns)::real *100, '99D00%') as negligible
  
  from image_vuln_summary
GROUP by containers_exist
ORDER by containers_exist DESC
