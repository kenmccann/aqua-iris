WITH
host_tags as (
  select hostid,
  split_part(tag_string, ',',1) as tag_name,
  split_part(tag_string, ',',2) as tag_value
  from
     (select
        hostid, 
        regexp_replace(split_part(jsonb_array_elements_text(cloud_info->'vm_tags'), ',',1),':(?!.*:)',',') as tag_string
      from agent_details ad
      where cloud_info->>'vm_tags' is not null) as tag_table
  )

SELECT
  tag_name,
  tag_value,
  count(distinct host_id) as num_hosts,
  avg(crit_vulns)::int as average_critical_vulns,
  avg(high_vulns)::int as average_high_vulns,
  avg(med_vulns)::int as average_medium_vulns,
  avg(low_vulns)::int as average_low_vulns,
  avg(neg_vulns)::int as average_neg_vulns
FROM host_tags ht
JOIN scans ON ht.hostid = scans.host_id
GROUP by tag_name, tag_value
HAVING count(distinct host_id) > 1
ORDER BY num_hosts DESC, tag_name ASC, tag_value ASC

