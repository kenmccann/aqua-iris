--Host bench results details
WITH bench_results AS (
SELECT
  TO_TIMESTAMP(hs.lastupdate) as scan_date,
  hs.host_id::text as host_id,
  CASE
     WHEN hs.test_type::text = 'cis' THEN 'dockerbench'
     ELSE hs.test_type::text
  END as category,
  hs.config_file_name::text as config_file,
  section."desc" as section,
  section.section as section_number,
  test.test_number,
  test.test_desc,
  test.status as test_result,
  position('WARN' in test.status) as test_warn,
  position('FAIL' in test.status) as test_fail,
  position('INFO' in test.status) as test_info,
  position('PASS' in test.status) as test_pass
FROM
  host_scan hs,
  jsonb_to_recordset(COALESCE(hs.data#>'{result,Controls,0,tests}',hs.data#>'{result,tests}')) as section("desc" text, section text, fail numeric, pass numeric, warn numeric, info numeric, results jsonb),
  jsonb_to_recordset(section.results) as test(test_number text, test_desc text, status text)
  
  )

SELECT
  br.scan_date,
  br.host_id,
  br.category,
  br.config_file,
  br.section,
  br.section_number,
  br.test_number,
  br.test_desc,
  br.test_result,
  br.test_warn,
  br.test_fail,
  br.test_info,
  br.test_pass,
  round( host_totals.pass / host_totals.tests,2) * 100 as host_pass_pct,
  round( host_totals.fail / host_totals.tests,2) * 100 as host_fail_pct,
  round( host_totals.info / host_totals.tests,2) * 100 as host_info_pct,
  round( host_totals.warn / host_totals.tests,2) * 100 as host_warn_pct,

  round( category_totals.pass / category_totals.tests,2) * 100 as category_pass_pct,
  round( category_totals.fail / category_totals.tests,2) * 100 as category_fail_pct,
  round( category_totals.info / category_totals.tests,2) * 100 as category_info_pct,
  round( category_totals.warn / category_totals.tests,2) * 100 as category_warn_pct,

  round( section_totals.pass / section_totals.tests,2) * 100 as section_pass_pct,
  round( section_totals.fail / section_totals.tests,2) * 100 as section_fail_pct,
  round( section_totals.info / section_totals.tests,2) * 100 as section_info_pct,
  round( section_totals.warn / section_totals.tests,2) * 100 as section_warn_pct
FROM
  bench_results br
    JOIN hosts ON hosts.id = br.host_id,
  LATERAL ( SELECT count(test_result)::numeric as tests, sum(test_warn)::numeric as warn, sum(test_info)::numeric as info, sum(test_pass)::numeric as pass, sum(test_fail)::numeric as fail 
            FROM bench_results tmp WHERE tmp.host_id=br.host_id) host_totals,
  LATERAL ( SELECT count(test_result)::numeric as tests, sum(test_warn)::numeric as warn, sum(test_info)::numeric as info, sum(test_pass)::numeric as pass, sum(test_fail)::numeric as fail 
            FROM bench_results tmp WHERE tmp.host_id=br.host_id AND tmp.category = br.category) category_totals,
  LATERAL ( SELECT count(test_result)::numeric as tests, sum(test_warn)::numeric as warn, sum(test_info)::numeric as info, sum(test_pass)::numeric as pass, sum(test_fail)::numeric as fail 
            FROM bench_results tmp WHERE tmp.host_id=br.host_id AND tmp.category = br.category AND tmp.section = br.section) section_totals
  
