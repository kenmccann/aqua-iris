--Host scans findings in the past 12 months
select
  TO_CHAR(datemonth, 'Mon yy') as Month,
  count( DISTINCT sh.host_id) as host_count,
  count (sh.id) as scans,
  coalesce(sum(sh.malware),0) as malware_found,
  coalesce(sum(sh.sensitive),0) as secrets_found,
  coalesce(sum(sh.crit_vulns),0) as critical_vulns_found
from  generate_series(now() - interval '11 months', now() , '1 month') datemonth
LEFT JOIN scan_history sh ON to_char(sh.date, 'mmyy') = to_char(datemonth, 'mmyy') AND sh.host_id is not null AND sh.status = 'finished'
group by datemonth
order by datemonth desc
