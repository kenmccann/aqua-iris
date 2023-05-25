--Hosts added over time
select
TO_CHAR(datemonth, 'Mon yy') as Month,
count(first_scans.host_id) as hosts_added
from  generate_series(now() - interval '11 months', now() , '1 month') datemonth
LEFT JOIN
 (
   select distinct on (sh.host_id) sh.host_id, sh.id, sh.date, TO_CHAR(sh.date, 'mmyy') as month_scanned
   from scan_history sh
   where host_id is not null
   order by sh.host_id, sh.date ASC
 ) as first_scans on first_scans.month_scanned = to_char(datemonth, 'mmyy')
group by datemonth
order by datemonth desc
