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
     )

SELECT
       pf.failed_policy_type as failed_control_type,
           pf.failed_control,
           count(distinct c.id) as container_count,
           count(distinct c.image_name) as image_count,
           count(distinct c.level1) as cluster_count,
           count(distinct c.level2) as namespace_count,
       count(distinct c.level3) as controller_count
FROM containers c
LEFT OUTER JOIN image_metadata im on im.docker_id = c.oci_image_id
LEFT OUTER JOIN scans ON scans.image_id = im.image_id
LEFT OUTER JOIN policy_failures pf ON c.scan_id::text = pf.scan_id OR pf.scan_id = scans.id::text OR pf.scan_id = c.id::text
WHERE c.status = 'running' and failed_control is not null
GROUP BY pf.failed_policy_type, pf.failed_control
