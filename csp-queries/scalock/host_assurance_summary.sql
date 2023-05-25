--Host Assurance control summary
SELECT sar.control,
       count(DISTINCT scans.host_id) as hosts_scanned,
       count(DISTINCT scans.host_id) FILTER (where sar.failed is true) as hosts_failed,
       to_char(count(DISTINCT scans.host_id) FILTER (where sar.failed is false) / count(DISTINCT scans.host_id)::real * 100, '990D00%') as pass_rate
--     ,to_char(count(DISTINCT scans.host_id) FILTER (where sar.failed is true) / count(DISTINCT scans.host_id)::real * 100, '990D00%') as fail_rate
FROM scan_assurance_results sar
JOIN scans on scans.id = sar.scan_id
JOIN image_assurance ia on sar.policy_id=ia.id
WHERE scans.type = 'host'
GROUP BY sar.control
ORDER by hosts_scanned DESC
