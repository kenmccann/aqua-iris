--Containers overall assurance results
WITH compliance_outcomes as (
    SELECT
 scans.scan_date::timestamptz as scan_date,
  CASE
     WHEN scans.image_id IS NOT NULL THEN scans.image_id::text
	 WHEN scans.host_id IS NOT NULL THEN scans.host_id::text
	 WHEN scans.resource_uid IS NOT NULL THEN scans.resource_uid::text
	 WHEN scans.function_id IS NOT NULL THEN scans.function_id::text
     ELSE null
  END as resource_id,
 scans.type::text as scan_type,
 ia.name::text policy_name,
 sar.control::text as control_name,
 CASE
     WHEN sar.failed IS false THEN 'pass'
     WHEN sar.failed IS true THEN 'fail'
 END as outcome
FROM scan_assurance_results sar
JOIN scans on scans.id = sar.scan_id
JOIN image_assurance ia on ia.id = sar.policy_id


UNION ALL
SELECT
  TO_TIMESTAMP(hs.lastupdate)::timestamptz as scan_date,
  hs.host_id::text as resource_id,
  CASE
     WHEN hs.test_type::text = 'cis' THEN 'dockerbench'
     ELSE hs.test_type::text
  END as scan_type,
--  hs.config_file_name::text as config_file,
  section."desc"::text as policy_name,
  test.test_desc::text as control_name,
  LOWER(test.status) as outcome
FROM
  host_scan hs,
  jsonb_to_recordset(COALESCE(hs.data#>'{result,Controls,0,tests}',hs.data#>'{result,tests,results}')) as section("desc" text, section text, fail numeric, pass numeric, warn numeric, info numeric, results jsonb),
  jsonb_to_recordset(section.results) as test(test_number text, test_desc text, status text)
WHERE test.status = 'PASS' or test.status = 'FAIL'

UNION ALL
	 SELECT 
	       TO_TIMESTAMP(c.create_time)::timestamptz as scan_date,
	       c.id::text resource_id,
		   'container' as scan_type,
           'Default' as policy_name,
		   cc.control_name as control_name,
		   CASE
		    WHEN cc.control_result = true THEN 'fail'
			WHEN cc.control_result = false THEN 'pass'
		   END as outcome
      FROM containers c,
	  LATERAL ( SELECT control_name, control_result
		         FROM (VALUES
				 ('Run as non-root', c.isroot),
				 ('Run as non-privileged', c.isprivileged),
				 ('Image registered', not c.isregistered)
                 ) AS cfp (control_name,control_result) ) cc
     
)

SELECT 
       current_timestamp as query_time,
	   c.name as container_name,
--	   c.id as container_id,
--	   c.hostid as host_id,
       h.display_name::text as host_name,
	   c.full_image_name as image_path,
--	   im.image_id::text,
	   c.registry_id as registry_name,
	   c.level1 as cluster,
	   c.level2 as namespace,
       c.level3 as controller,
       c.level3_type as controller_type,
	   c.level4 as pod_name,
--	   c.audit_block_events + c.audit_detect_events as c_runtime_events,
--	   to_timestamp(c.create_time) as create_time,
--	   k8sr.uid as k8s_resource_id,
	   co.scan_type,
--	   co.policy_name,
	   co.control_name,
	   co.outcome
FROM hosts h
FULL OUTER JOIN containers c on h.id = c.hostid
LEFT JOIN kubernetes_resources k8sr on c.level1 = k8sr.cluster_name AND c.level2 = k8sr.namespace AND c.level3 = k8sr.name and c.level3_type = k8sr.kind
LEFT JOIN image_metadata im on im.docker_id = c.oci_image_id
LEFT JOIN compliance_outcomes co on (co.resource_id = im.image_id::text AND scan_type = 'image') OR co.resource_id = c.hostid or co.resource_id = c.id or co.resource_id = k8sr.uid
ORDER BY  c.level1,  c.level2,  c.level3, c.level4, c.name