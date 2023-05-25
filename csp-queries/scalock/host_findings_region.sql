--Host findings by region
select
  cloud_info->>'vm_vendor_name' as cloud,
  cloud_info->>'vm_location' as region,
  count(hosts.id) as host_count,
  coalesce(sum(scans.malware),0) as malware_found,
  coalesce(sum(scans.sensitive),0) as secrets_found,
  coalesce(sum(scans.crit_vulns),0) as critical_vulns_found
from hosts
join agent_details ad on hosts.id = ad.hostid
join scans on scans.host_id = hosts.id
where scans.type = 'host'
group by cloud, region
ORDER by cloud, region
