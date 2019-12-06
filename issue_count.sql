(select 'HIGH' as priority,'OVERLAPPING POLYGONS' as Issue, (select count(*) from public.geocheck_adv_overlapping_polygons) as count, 'geocheck_adv_overlapping_polygons' as View )
union all
(select 'HIGH' as priority,'LANDS WITH INVALID POLYGONS' as Issue, (select count(*) from public.geocheck_obj_hazard_invalid_polys) as count, 'geocheck_obj_hazard_invalid_polys' as View )
union all
(select 'MEDIUM' as priority,'LANDS WITH POLYGONS WITH LESS THAN 3 POINTS' as Issue, (select count(*) from public.geocheck_obj_hazard_few_vertices_polys) as count, 'geocheck_obj_hazard_few_vertices_polys' as View )
union all
(select 'HIGH' as priority,'ACTIVITIES WITH INVALID POLYGONS' as Issue, (select count(*) from public.geocheck_obj_hazreduc_invalid_polys) as count, 'geocheck_obj_hazreduc_invalid_polys' as View )
union all
(select 'MEDIUM' as priority,'ACTIVITIES WITH POLYGONS WITH LESS THAN 3 POINTS' as Issue, (select count(*) from public.geocheck_obj_hazreduc_few_vertices_polys) as count, 'geocheck_obj_hazreduc_few_vertices_polys' as View )
union all
(select 'HIGH' as priority,'DUPLICATE POLYGONS' as Issue, (select count(*) from public.geocheck_duplicate_polygons) as count, 'geocheck_duplicate_polygons' as View )
union all
(select 'LOW' as priority,'POLYGONS WITH SAME IDS' as Issue, (select count(*) from public.geocheck_duplicate_polygon_polyid) as count, 'geocheck_duplicate_polygon_polyid' as View )
union all
(select 'HIGH' as priority,'DUPLICATE POINTS IN POLYGONS' as Issue, (select count(*) from public.geocheck_duplicate_polygon_points) as count, 'geocheck_duplicate_polygon_points' as View )
union all
(select 'LOW' as priority,'POLYGON POINTS WITH SAME IDS AND TYPES' as Issue, (select count(*) from public.geocheck_duplicate_polygon_point_localid) as count, 'geocheck_duplicate_polygon_point_localid' as View )
union all
(select 'MEDIUM' as priority,'DUPLICATE SINGLE POINTS' as Issue, (select count(*) from public.geocheck_duplicate_points) as count, 'geocheck_duplicate_points' as View )
union all
(select 'LOW' as priority,'SINGLE POINTS WITH SAME IDS AND TYPES' as Issue, (select count(*) from public.geocheck_duplicate_point_point_localid) as count, 'geocheck_duplicate_point_point_localid' as View )
union all
(select 'MEDIUM' as priority,'OBJECT WITH SAME IDS' as Issue, (select count(*) from public.geocheck_duplicate_localids) as count, 'geocheck_duplicate_localids' as View )
union all
(select 'LOW' as priority,'DUPLICATE DEVICES' as Issue, (select count(*) from public.geocheck_duplicate_devices) as count, 'geocheck_duplicate_devices' as View )
