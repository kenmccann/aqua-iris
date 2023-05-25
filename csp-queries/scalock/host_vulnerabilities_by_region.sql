WITH
host_tags as (
  select hostid,
    cloud_info->>'vm_vendor_name' as cloud,
    cloud_info->>'vm_location' as region
       from agent_details ad
      where cloud_info->>'vm_tags' is not null
  )

SELECT
  cloud,
  region,
  count(distinct host_id) as num_hosts,
  avg(crit_vulns)::int as average_critical_vulns,
  avg(high_vulns)::int as average_high_vulns,
  avg(med_vulns)::int as average_medium_vulns,
  avg(low_vulns)::int as average_low_vulns,
  avg(neg_vulns)::int as average_neg_vulns
FROM host_tags ht
JOIN scans ON ht.hostid = scans.host_id
GROUP by cloud, region
ORDER BY num_hosts DESC, cloud ASC, region ASC

