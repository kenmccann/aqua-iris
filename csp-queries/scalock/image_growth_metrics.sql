--Growth metrics
select 'Images added this week' as metric, count(*) as value from registry_images ri
where extract (week from ri.created) = extract (week from  CURRENT_DATE) AND extract (year from ri.created) = extract (year from  CURRENT_DATE)
UNION ALL
select 'Images added this month' as metric, count(*) as value from registry_images ri
where extract (month from ri.created) = extract (month from  CURRENT_DATE) AND extract (year from ri.created) = extract (year from  CURRENT_DATE)
