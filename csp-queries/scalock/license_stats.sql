--License stats
WITH licenses as (
select
  CASE
    WHEN min(enforcers)=-2 THEN -1
    ELSE sum(enforcers)  FILTER (WHERE enforcers != -1)
  END as  licensed_enfrocers,
  CASE
    WHEN min(repositories)=-2 THEN -1
    ELSE sum(repositories)  FILTER (WHERE repositories != -1)
  END as  licensed_repositories,
  CASE
    WHEN min(micro_enforcers)=-2 THEN -1
    ELSE sum(micro_enforcers)  FILTER (WHERE micro_enforcers != -1)
  END as  licensed_micro,
  CASE
    WHEN min(vm_enforcers)=-2 THEN -1
    ELSE sum(vm_enforcers) FILTER (WHERE vm_enforcers != -1)
  END as  licensed_vms
  from license
where status = 'Active'

)
select
  'Repositories' as Metric,
  (SELECT count(DISTINCT repository_id)::numeric from registry_images) as Used,
  licensed_enfrocers::numeric as Licesned,
  TO_CHAR((SELECT count(DISTINCT repository_id)::numeric from registry_images)/licensed_enfrocers::numeric * 100, '990D00%')  as Utilization
  FROM licenses
UNION ALL
select
  'Enforcers' as Metric,
  (select count(*) from hosts where type = 'agent' and status = 'connect') as Used,
  licensed_enfrocers::numeric as Licesned,
  TO_CHAR((select count(*) from hosts where type = 'agent' and status = 'connect')/licensed_enfrocers::numeric * 100, '990D00%')  as Utilization
  FROM licenses