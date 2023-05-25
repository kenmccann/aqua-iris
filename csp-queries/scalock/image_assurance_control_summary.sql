--Image Assurance control summary
SELECT sar.control,
       count(DISTINCT scans.image_id) as images_checked,
       to_char(count(DISTINCT scans.image_id) FILTER (where sar.failed is false) / count(DISTINCT scans.image_id)::real * 100, '990D00%') as pass_rate,
	   to_char(count(DISTINCT scans.image_id) FILTER (where sar.failed is true) / count(DISTINCT scans.image_id)::real * 100, '990D00%') as fail_rate

         FROM scan_assurance_results sar
		 join scans on scans.id = sar.scan_id
         JOIN image_assurance ia on sar.policy_id=ia.id
		 WHERE scans.type = 'image'
		 GROUP BY sar.control
		 ORDER by images_checked DESC
