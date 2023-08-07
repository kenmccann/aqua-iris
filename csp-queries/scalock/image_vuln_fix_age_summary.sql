WITH 
  dim_image_data as (
    SELECT
      ri.id as image_id,
      ri.created::date as create_date,
	  ri.repository_id as repo_id,
	  ri.name as image_name
    FROM registry_images ri
	JOIN image_metadata im ON ri.id = im.image_id
   ),
  fact_repo_vuln as (
    SELECT
	  rr.id as repo_id,
	  krv.name as vuln_name,
	  min(krv.id) as vuln_id,
     (select did.image_id from dim_image_data did WHERE did.create_date =  min(ri.created::date) AND did.repo_id = rr.id ORDER by did.create_date ASC , did.image_id ASC LIMIT 1) first_image_id,
	 (select did.image_id from dim_image_data did WHERE did.create_date =  max(ri.created::date) AND did.repo_id = rr.id ORDER by did.create_date DESC , did.image_id DESC LIMIT 1) last_image_id,
	 (select did.image_id from dim_image_data did WHERE did.create_date >  min(ri.created::date) AND did.repo_id = rr.id ORDER by did.create_date DESC, did.image_id DESC LIMIT 1 OFFSET 1) next_image_id,
	 (select did.image_id from dim_image_data did WHERE did.repo_id = rr.id ORDER by did.create_date DESC, did.image_id DESC LIMIT 1) top_image_id
    FROM registry_repositories rr
    JOIN registry_images ri ON ri.repository_id = rr.id
	JOIN image_metadata im ON im.image_id = ri.id
    JOIN scans ON ri.id = scans.image_id
    JOIN scan_resources sr ON sr.scan_id = scans.id
    JOIN known_resources kr ON sr.resource_id = kr.id
    JOIN known_resource_vulnerabilities krv ON sr.resource_id = krv.resource_id
    WHERE krv.issue_type = 'vulnerability' AND scans.type='image' 
    GROUP BY rr.id, krv.name
    
  ),
  

repo_vulns as (SELECT
  dim_repo.registry_id as registry,
  dim_repo.name AS repo_name,
  frv.vuln_name,
  dim_vuln.resource_name,
  dim_vuln.resource_version,
  dim_vuln.vuln_severity,
  dim_vuln.vuln_score,
  dim_vuln.fix_version,
  first_seen.image_name as first_found_image,
  first_seen.create_date as first_found_image_date,
    CASE
	   WHEN last_seen.image_id = first_seen.image_id THEN (current_date - first_seen.create_date)
	   WHEN last_seen.image_id = last_image.image_id THEN (current_date - first_seen.create_date)
	   WHEN (last_seen.create_date = first_seen.create_date)  THEN (next_image.create_date - first_seen.create_date)
	   ELSE  (last_seen.create_date - first_seen.create_date)
  END as age_in_days,
  CASE  
	    WHEN last_image.image_id = last_seen.image_id THEN false
	    ELSE true
  END as fixed,
  CASE
	   WHEN last_image.image_id = last_seen.image_id THEN ''
	   WHEN (last_seen.create_date = first_seen.create_date) THEN next_image.image_name
	   ELSE  last_seen.image_name
  END as fixed_in_image,
  CASE
	   WHEN last_image.image_id = last_seen.image_id THEN null
	   WHEN (last_seen.create_date = first_seen.create_date) THEN next_image.create_date
	   ELSE  last_seen.create_date
  END as fix_image_date
FROM fact_repo_vuln frv
JOIN dim_image_data first_seen ON first_seen.image_id = frv.first_image_id
JOIN dim_image_data last_seen ON last_seen.image_id = frv.last_image_id 
JOIN dim_image_data next_image ON next_image.image_id = coalesce(frv.next_image_id,frv.top_image_id)
JOIN dim_image_data last_image ON last_image.image_id = frv.top_image_id
JOIN registry_repositories dim_repo ON dim_repo.id = frv.repo_id,
LATERAL (
	    SELECT
		    CASE
              WHEN krv.vendor_cvss3_score > 0 THEN krv.vendor_cvss3_score
              WHEN krv.nvd_cvss3_score > 0 AND krv.vendor_severity = '' THEN krv.nvd_cvss3_score
              WHEN krv.vendor_cvss2_score > 0 THEN krv.vendor_cvss2_score
              WHEN krv.vendor_severity = '' THEN krv.nvd_cvss2_score
              ELSE 0
            END as vuln_score,
            CASE
              WHEN cast(krv.nvd_cvss3_severity as text) != '' AND cast(krv.vendor_severity as text) = '' THEN cast(krv.nvd_cvss3_severity as text)
              ELSE public.aqua_severity((select r from public.known_resource_vulnerabilities r where id=krv.id), true)
            END as vuln_severity,
		    kr.name as resource_name,
		    kr.version as resource_version,
            krv.fix_version as fix_version
		 FROM known_resource_vulnerabilities krv
		 JOIN known_resources kr on kr.id = krv.resource_id
		 WHERE krv.id = frv.vuln_id
		) dim_vuln
ORDER BY fixed ASC, age_in_days DESC, dim_repo.name, vuln_name DESC, vuln_severity ASC) 

--*** For summary of average age of unfixed in repo:
SELECT registry, repo_name, fixed, AVG(age_in_days)::int as avg_age_in_days from repo_vulns GROUP BY registry, repo_name, fixed ORDER BY avg_age_in_days DESC

