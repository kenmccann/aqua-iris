--Image count growth over 12 months
select  
TO_CHAR(datemonth, 'Mon yy') as Month,
(SELECT count(id) from registry_images where registry_images.created <= datemonth) as running_count,
count(id) as added
from  generate_series(now() - interval '11 months', now() , '1 month') datemonth
LEFT join registry_images ri on to_char(ri.created, 'mmyy') = to_char(datemonth, 'mmyy')
group by datemonth
order by datemonth desc
