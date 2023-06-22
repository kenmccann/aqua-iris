--Image inventory stats
select 'Number of registries' as Metric, count(DISTINCT registry_id)::text as Value from registry_images
UNION ALL
select 'Number of repositories' as Metric, count(DISTINCT repository_id)::text as Value from registry_images
UNION ALL
select 'Number of images' as Metric, count(DISTINCT id)::text as Value from registry_images
UNION ALL
select 'Number of images in running containers' as Metric, count(DISTINCT oci_image_id)::text as Value from containers
UNION ALL
select '% of images scanned that are in use' as Metric, TO_CHAR((SELECT count(DISTINCT oci_image_id) from containers)/(SELECT count(DISTINCT id) from registry_images)::real * 100,'fm990D00%')
