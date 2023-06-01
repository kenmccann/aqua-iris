--Running containers with findings summary
with policy_failures as (
     SELECT
       sar.scan_id::text as scan_id,
       sar.control as failed_control,
       ia.name as failed_policy,
	   scans.type as failed_policy_type
     FROM scan_assurance_results sar
     JOIN image_assurance ia on sar.policy_id=ia.id
	 JOIN scans on sar.scan_id = scans.id
     WHERE sar.failed=true
	 UNION ALL
	 SELECT 
	       c.id::text scan_id,
           cr.control_name as failed_control,
           'Default' as failed_policy,
	       'container' as failed_policy_type
      FROM containers c,
	  LATERAL ( SELECT control_name
		         FROM (VALUES
				 ('root', c.isroot),
				 ('privileged', c.isprivileged),
				 ('not_registered', not c.isregistered)
                 ) AS cfp (control_name,control_result) WHERE control_result = true) cr 
     ),
     image_risk as (
     SELECT 
		 scans.id as ir_scan_id,
		 im.docker_id as docker_id,
		 scans.malware as i_malware,
		 scans.crit_vulns as i_critical_vulns,
         scans.high_vulns as i_high_vulns,
         scans.med_vulns as i_med_vulns,
         scans.low_vulns as i_low_vulns,
         scans.neg_vulns as i_nelg_vulns,
         scans.crit_vulns + scans.high_vulns + scans.med_vulns + scans.low_vulns + scans.neg_vulns as i_total_vulns,
		 row_number() OVER (partition BY im.docker_id ORDER BY scans.scan_date DESC) scan_entry
     FROM image_metadata im
     JOIN scans ON scans.image_id = im.image_id
     ),
	 host_risk as (
	 SELECT
		 scans.id as hr_scan_id,
		 scans.host_id as host_id,
		 scans.malware as h_malware,
		 scans.crit_vulns as h_critical_i_vulns,
         scans.high_vulns as h_high_vulns,
         scans.med_vulns as h_med_vulns,
         scans.low_vulns as h_low_vulns,
         scans.neg_vulns as h_nelg_vulns,
         scans.crit_vulns + scans.high_vulns + scans.med_vulns + scans.low_vulns + scans.neg_vulns as h_total_vulns,
		 row_number() OVER (partition BY scans.host_id ORDER BY scans.scan_date DESC) scan_entry
     FROM scans
	 )
   
SELECT 
       current_timestamp as query_time,
	   c.name as container_name,
	   row_number() OVER (partition BY c.id) container_entry,
	   c.id as container_id,
	   c.image_name as image_name,
	   c.registry_id as registry_name,
	   c.level1 as cluster,
	   c.level2 as namespace,
       c.level3 as controller,
       c.level3_type as controller_type,
	   c.level4 as pod_name,
	   c.audit_block_events + c.audit_detect_events as c_runtime_events,
	   to_timestamp(c.create_time) as create_time,
	   ir.*,
	   hr.*,
       pf.failed_control,
	   pf.failed_policy,
	   pf.failed_policy_type
FROM containers c
LEFT OUTER JOIN image_risk ir on ir.docker_id = c.oci_image_id AND ir.scan_entry = 1
LEFT OUTER JOIN host_risk hr on hr.host_id = c.hostid AND hr.scan_entry = 1
LEFT OUTER JOIN policy_failures pf ON c.scan_id::text = pf.scan_id OR pf.scan_id = ir.ir_scan_id::text OR pf.scan_id = hr.hr_scan_id::text OR pf.scan_id = c.id::text
WHERE c.status = 'running' 