-- This queries are based on geopoints for only fieldreport in the workbench
-- only hazard and hazreduc section done for the moment

-------------------------------
-- Begin hazard section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_hazard_pts CASCADE; 
create or replace view public.wb_geocheck_zint_hazard_pts as

   select
	hazardinfoversion.hazard_guid,
	hazardinfoversion.hazard_localid,
	hazardinfoversion.fieldreport_guid,
	hazardinfoversion_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join hazardinfoversion_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazardinfoversion_has_geospatialinfo.geospatialinfo_guid
	inner join hazardinfoversion on hazardinfoversion_has_geospatialinfo.hazardinfoversion_guid = hazardinfoversion.hazardinfoversion_guid
	inner join fieldreport on fieldreport.fieldreport_guid = hazardinfoversion.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_hazard_polys CASCADE;
create or replace view public.wb_geocheck_zint_hazard_polys as
	select hazard_guid, hazard_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_hazard_pts where shapeenum = 'Polygon' 
		order by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid having count(*) > 2
	order by hazard_guid;
						
-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_hazard_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_hazard_few_vertices_polys as
	select hazard_guid, hazard_localid, shape_id, count(*) as pointcount
	from (select hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_hazard_pts where shapeenum = 'Polygon' 
		order by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid having count(*) < 3
	order by hazard_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_hazard_valid_polys CASCADE;
create view public.wb_geocheck_zint_hazard_valid_polys as
	select hazard_guid, hazard_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_hazard_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_hazard_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_hazard_valid_singlepart_polys as
	select
	hazard_guid,
	hazard_localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_hazard_polys
	where ST_IsValid(shape) = 't'
		and hazard_guid in
			(select
			hazard_guid 
			from public.wb_geocheck_zint_hazard_pts 
			where shapeenum = 'Polygon' 
			group by hazard_guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
			
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_hazard_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_hazard_valid_multipart_polys as
	select
	hazard_guid,
	hazard_localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_hazard_valid_polys 
	group by hazard_guid, hazard_localid
	having hazard_guid in
		(select
		hazard_guid 
		from public.wb_geocheck_zint_hazard_pts 
		where shapeenum = 'Polygon' 
		group by hazard_guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_hazard_all_object_polys CASCADE;
create view public.wb_geocheck_zint_hazard_all_object_polys as
	select * from wb_geocheck_zint_hazard_valid_singlepart_polys
	union all
	select * from wb_geocheck_zint_hazard_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_hazard_invalid_polys CASCADE;
create view public.wb_geocheck_obj_hazard_invalid_polys as
	select hazard_guid, hazard_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_hazard_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin hazreduc section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_hazreduc_pts CASCADE; 
create or replace view public.wb_geocheck_zint_hazreduc_pts as

   select
	hazreducinfoversion.hazreduc_guid,
	hazreducinfoversion.hazreduc_localid,
	hazreducinfoversion.fieldreport_guid,
	hazreducinfoversion_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join hazreducinfoversion_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreducinfoversion_has_geospatialinfo.geospatialinfo_guid
	inner join hazreducinfoversion on hazreducinfoversion_has_geospatialinfo.hazreducinfoversion_guid = hazreducinfoversion.hazreducinfoversion_guid
	inner join fieldreport on fieldreport.fieldreport_guid = hazreducinfoversion.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;


-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_hazreduc_polys CASCADE;
create or replace view public.wb_geocheck_zint_hazreduc_polys as
	select hazreduc_guid, hazreduc_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_hazreduc_pts where shapeenum = 'Polygon' 
		order by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by hazreduc_guid;

-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_hazreduc_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_hazreduc_few_vertices_polys as
    select hazreduc_guid, hazreduc_localid, shape_id, count(*) as pointcount
    from (select hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
        from public.wb_geocheck_zint_hazreduc_pts where shapeenum = 'Polygon' 
        order by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno) as values 
    group by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid  having count(*) < 3
    order by hazreduc_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_hazreduc_valid_polys CASCADE;
create view public.wb_geocheck_zint_hazreduc_valid_polys as
select hazreduc_guid, hazreduc_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_hazreduc_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_hazreduc_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_hazreduc_valid_singlepart_polys as
	select
	hazreduc_guid,
	hazreduc_localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_hazreduc_polys
	where ST_IsValid(shape) = 't'
		and hazreduc_guid in
			(select
			hazreduc_guid 
			from public.wb_geocheck_zint_hazreduc_pts 
			where shapeenum = 'Polygon' 
			group by hazreduc_guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
			
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_hazreduc_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_hazreduc_valid_multipart_polys as
	select
	hazreduc_guid,
	hazreduc_localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_hazreduc_valid_polys 
	group by hazreduc_guid, hazreduc_localid
	having hazreduc_guid in
		(select
		hazreduc_guid 
		from public.wb_geocheck_zint_hazreduc_pts 
		where shapeenum = 'Polygon' 
		group by hazreduc_guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_hazreduc_all_object_polys CASCADE;
create view public.wb_geocheck_zint_hazreduc_all_object_polys as
	select * from wb_geocheck_zint_hazreduc_valid_singlepart_polys
	union all
	select * from wb_geocheck_zint_hazreduc_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_hazreduc_invalid_polys CASCADE;
create view public.wb_geocheck_obj_hazreduc_invalid_polys as
	select hazreduc_guid, hazreduc_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_hazreduc_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin accident section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_accident_pts CASCADE; 
create or replace view public.wb_geocheck_zint_accident_pts as

   select
	accidentinfoversion.accident_guid,
	accidentinfoversion.accident_localid,
	accidentinfoversion.fieldreport_guid,
	accidentinfoversion_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join accidentinfoversion_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accidentinfoversion_has_geospatialinfo.geospatialinfo_guid
	inner join accidentinfoversion on accidentinfoversion_has_geospatialinfo.accidentinfoversion_guid = accidentinfoversion.accidentinfoversion_guid
	inner join fieldreport on fieldreport.fieldreport_guid = accidentinfoversion.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_accident_polys CASCADE;
create or replace view public.wb_geocheck_zint_accident_polys as
	select accident_guid, accident_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_accident_pts where shapeenum = 'Polygon' 
		order by accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno)	as values 
	group by accident_guid, accident_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by accident_guid;

-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_accident_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_accident_few_vertices_polys as
	select accident_guid, accident_localid, shape_id, count(*) as pointcount
	from (select accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_accident_pts where shapeenum = 'Polygon' 
		order by accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by accident_guid, accident_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by accident_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_accident_valid_polys CASCADE;
create view public.wb_geocheck_zint_accident_valid_polys as
	select accident_guid, accident_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_accident_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_accident_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_accident_valid_singlepart_polys as
	select
	accident_guid,
	accident_localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_accident_polys
	where ST_IsValid(shape) = 't'
		and accident_guid in
			(select
			accident_guid 
			from public.wb_geocheck_zint_accident_pts 
			where shapeenum = 'Polygon' 
			group by accident_guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
			
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_accident_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_accident_valid_multipart_polys as
	select
	accident_guid,
	accident_localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_accident_valid_polys 
	group by accident_guid, accident_localid
	having accident_guid in
		(select
		accident_guid 
		from public.wb_geocheck_zint_accident_pts 
		where shapeenum = 'Polygon' 
		group by accident_guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_accident_all_object_polys CASCADE;
create view public.wb_geocheck_zint_accident_all_object_polys as
select * from wb_geocheck_zint_accident_valid_singlepart_polys
union all
select * from wb_geocheck_zint_accident_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_accident_invalid_polys CASCADE;
create view public.wb_geocheck_obj_accident_invalid_polys as
	select accident_guid, accident_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_accident_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin mre section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_mre_pts CASCADE; 
create or replace view public.wb_geocheck_zint_mre_pts as

   select
	mreinfoversion.mre_guid,
	mreinfoversion.mre_localid,
	mreinfoversion.fieldreport_guid,
	mreinfoversion_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join mreinfoversion_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mreinfoversion_has_geospatialinfo.geospatialinfo_guid
	inner join mreinfoversion on mreinfoversion_has_geospatialinfo.mreinfoversion_guid = mreinfoversion.mreinfoversion_guid
	inner join fieldreport on fieldreport.fieldreport_guid = mreinfoversion.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_mre_polys CASCADE;
create or replace view public.wb_geocheck_zint_mre_polys as
	select mre_guid, mre_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_mre_pts where shapeenum = 'Polygon' 
		order by mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by mre_guid, mre_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by mre_guid;

-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_mre_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_mre_few_vertices_polys as
	select mre_guid, mre_localid, shape_id, count(*) as pointcount
	from (select mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_mre_pts where shapeenum = 'Polygon' 
		order by mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by mre_guid, mre_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by mre_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_mre_valid_polys CASCADE;
create view public.wb_geocheck_zint_mre_valid_polys as
	select mre_guid, mre_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_mre_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_mre_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_mre_valid_singlepart_polys as
	select
	mre_guid,
	mre_localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_mre_polys
	where ST_IsValid(shape) = 't'
		and mre_guid in
			(select
			mre_guid 
			from public.wb_geocheck_zint_mre_pts 
			where shapeenum = 'Polygon' 
			group by mre_guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
			
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_mre_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_mre_valid_multipart_polys as
	select
	mre_guid,
	mre_localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_mre_valid_polys 
	group by mre_guid, mre_localid
	having mre_guid in
		(select
		mre_guid 
		from public.wb_geocheck_zint_mre_pts 
		where shapeenum = 'Polygon' 
		group by mre_guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_mre_all_object_polys CASCADE;
create view public.wb_geocheck_zint_mre_all_object_polys as
	select * from wb_geocheck_zint_mre_valid_singlepart_polys
	union all
	select * from wb_geocheck_zint_mre_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_mre_invalid_polys CASCADE;
create view public.wb_geocheck_obj_mre_invalid_polys as
	select mre_guid, mre_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_mre_polys where ST_IsValid(shape) = 'f';
	
-------------------------------
-- Begin qa section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_qa_pts CASCADE; 
create or replace view public.wb_geocheck_zint_qa_pts as

   select
	qainfoversion.qa_guid,
	qainfoversion.qa_localid,
	qainfoversion.fieldreport_guid,
	qainfoversion_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join qainfoversion_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qainfoversion_has_geospatialinfo.geospatialinfo_guid
	inner join qainfoversion on qainfoversion_has_geospatialinfo.qainfoversion_guid = qainfoversion.qainfoversion_guid
	inner join fieldreport on fieldreport.fieldreport_guid = qainfoversion.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_qa_polys CASCADE;
create or replace view public.wb_geocheck_zint_qa_polys as
	select qa_guid, qa_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_qa_pts where shapeenum = 'Polygon' 
		order by qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by qa_guid, qa_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by qa_guid;

-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_qa_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_qa_few_vertices_polys as
	select qa_guid, qa_localid, shape_id, count(*) as pointcount
	from (select qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_qa_pts where shapeenum = 'Polygon' 
		order by qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by qa_guid, qa_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by qa_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_qa_valid_polys CASCADE;
create view public.wb_geocheck_zint_qa_valid_polys as
	select qa_guid, qa_localid, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_qa_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_qa_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_qa_valid_singlepart_polys as
	select
	qa_guid,
	qa_localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_qa_polys
	where ST_IsValid(shape) = 't'
		and qa_guid in
			(select
			qa_guid 
			from public.wb_geocheck_zint_qa_pts 
			where shapeenum = 'Polygon' 
			group by qa_guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
			
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_qa_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_qa_valid_multipart_polys as
	select
	qa_guid,
	qa_localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_qa_valid_polys 
	group by qa_guid, qa_localid
	having qa_guid in
		(select
		qa_guid 
		from public.wb_geocheck_zint_qa_pts 
		where shapeenum = 'Polygon' 
		group by qa_guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_qa_all_object_polys CASCADE;
create view public.wb_geocheck_zint_qa_all_object_polys as
	select * from wb_geocheck_zint_qa_valid_singlepart_polys
	union all
	select * from wb_geocheck_zint_qa_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_qa_invalid_polys CASCADE;
create view public.wb_geocheck_obj_qa_invalid_polys as
	select qa_guid, qa_localid, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_qa_polys where ST_IsValid(shape) = 'f';
	
-------------------------------
-- Begin victim section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_victim_pts CASCADE; 
create or replace view public.wb_geocheck_zint_victim_pts as

   select
	victiminfoversion.victim_guid,
	victiminfoversion.victim_localid,
	victiminfoversion.fieldreport_guid,
	victiminfoversion_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join victiminfoversion_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victiminfoversion_has_geospatialinfo.geospatialinfo_guid
	inner join victiminfoversion on victiminfoversion_has_geospatialinfo.victiminfoversion_guid = victiminfoversion.victiminfoversion_guid
	inner join fieldreport on fieldreport.fieldreport_guid = victiminfoversion.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_victim_polys CASCADE;
create or replace view public.wb_geocheck_zint_victim_polys as
	select victim_guid, victim_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_victim_pts where shapeenum = 'Polygon' 
		order by victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by victim_guid, victim_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by victim_guid;

-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_victim_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_victim_few_vertices_polys as
	select victim_guid, victim_localid, shape_id, count(*) as pointcount
	from (select victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_victim_pts where shapeenum = 'Polygon' 
		order by victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by victim_guid, victim_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by victim_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_victim_valid_polys CASCADE;
create view public.wb_geocheck_zint_victim_valid_polys as
	select victim_guid, victim_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_victim_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_victim_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_victim_valid_singlepart_polys as
	select
	victim_guid,
	victim_localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_victim_polys
	where ST_IsValid(shape) = 't'
		and victim_guid in
			(select
			victim_guid 
			from public.wb_geocheck_zint_victim_pts 
			where shapeenum = 'Polygon' 
			group by victim_guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
			
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_victim_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_victim_valid_multipart_polys as
	select
	victim_guid,
	victim_localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_victim_valid_polys 
	group by victim_guid, victim_localid
	having victim_guid in
		(select
		victim_guid 
		from public.wb_geocheck_zint_victim_pts 
		where shapeenum = 'Polygon' 
		group by victim_guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_victim_all_object_polys CASCADE;
create view public.wb_geocheck_zint_victim_all_object_polys as
	select * from wb_geocheck_zint_victim_valid_singlepart_polys
	union all
	select * from wb_geocheck_zint_victim_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_victim_invalid_polys CASCADE;
create view public.wb_geocheck_obj_victim_invalid_polys as
	select victim_guid, victim_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_victim_polys where ST_IsValid(shape) = 'f';

-------------------------------
-- Begin victim_assistance section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_victim_assistance_pts CASCADE; 
create or replace view public.wb_geocheck_zint_victim_assistance_pts as

   select
	victim_assistance_version.guid,
	victim_assistance_version.localid,
	victim_assistance_version.fieldreport_guid,
	victim_assistance_version_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join victim_assistance_version_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_version_has_geospatialinfo.geospatialinfo_guid
	inner join victim_assistance_version on victim_assistance_version_has_geospatialinfo.victim_assistance_version_guid = victim_assistance_version.guid
	inner join fieldreport on fieldreport.fieldreport_guid = victim_assistance_version.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_victim_assistance_polys CASCADE;
create or replace view public.wb_geocheck_zint_victim_assistance_polys as
	select guid, localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select guid, localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_victim_assistance_pts where shapeenum = 'Polygon' 
		order by guid, localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by guid, localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by guid;

-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_victim_assistance_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_victim_assistance_few_vertices_polys as
	select guid, localid, shape_id, count(*) as pointcount
	from (select guid, localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_victim_assistance_pts where shapeenum = 'Polygon' 
		order by guid, localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by guid, localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_victim_assistance_valid_polys CASCADE;
create view public.wb_geocheck_zint_victim_assistance_valid_polys as
	select guid, localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_victim_assistance_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_victim_assistance_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_victim_assistance_valid_singlepart_polys as
	select
	guid,
	localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_victim_assistance_polys
	where ST_IsValid(shape) = 't'
		and guid in
			(select
			guid 
			from public.wb_geocheck_zint_victim_assistance_pts 
			where shapeenum = 'Polygon' 
			group by guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
			
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_victim_assistance_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_victim_assistance_valid_multipart_polys as
	select
	guid,
	localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_victim_assistance_valid_polys 
	group by guid, localid
	having guid in
		(select
		guid 
		from public.wb_geocheck_zint_victim_assistance_pts 
		where shapeenum = 'Polygon' 
		group by guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_victim_assistance_all_object_polys CASCADE;
create view public.wb_geocheck_zint_victim_assistance_all_object_polys as
	select * from wb_geocheck_zint_victim_assistance_valid_singlepart_polys
	union all
	select * from wb_geocheck_zint_victim_assistance_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_victim_assistance_invalid_polys CASCADE;
create view public.wb_geocheck_obj_victim_assistance_invalid_polys as
	select guid, localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_victim_assistance_polys where ST_IsValid(shape) = 'f';
	

-------------------------------
-- Begin location section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.wb_geocheck_zint_location_pts CASCADE; 
create or replace view public.wb_geocheck_zint_location_pts as

   select
	locationinfoversion.location_guid,
	locationinfoversion.location_localid,
	locationinfoversion.fieldreport_guid,
	locationinfoversion_has_geospatialinfo.geospatialinfo_guid,
	ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
	geospatialinfo.shape_id,
	geospatialinfo.isactive,
	geospatialinfo.dataentrydate as g_dataentrydate,
	geospatialinfo.dataenterer as g_dataenterer,
	geospatialinfo.poly_prop_enum_guid,
	geopoint.geopoint_guid,
	-- geopoint.geospatialinfo_guid,
	geopoint.pointlocal_id,
	geopoint.pointno,
	ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
	geopoint.pointdescription,
	geopoint.latitude,
	geopoint.longitude,
	geopoint.coordrefsys,
	geopoint.fixedby_guid,
	geopoint.bearing,
	geopoint.distance,
	geopoint.frompoint_guid,
	geopoint.frompointinput,
	geopoint.userinputformat,
	geopoint.coordformat,
	geopoint.dataentrydate,
	geopoint.dataenterer,
	geopoint.elevation,
	geopoint.user_entered_x,
	geopoint.user_entered_y,
	geopoint.user_entered_mgrs,
	ST_SetSRID(ST_MakePoint(geopoint.longitude, geopoint.latitude),4326) as shape -- create shape column
 from geopoint
	inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
	inner join locationinfoversion_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = locationinfoversion_has_geospatialinfo.geospatialinfo_guid
	inner join locationinfoversion on locationinfoversion_has_geospatialinfo.locationinfoversion_guid = locationinfoversion.locationinfoversion_guid
	inner join fieldreport on fieldreport.fieldreport_guid = locationinfoversion.fieldreport_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where fieldreport.workbenchstatusenum_guid != '{BaseData-WorkbenchStatus-00000-00004}'
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.wb_geocheck_zint_location_polys CASCADE;
create or replace view public.wb_geocheck_zint_location_polys as
	select location_guid, location_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select location_guid, location_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_location_pts where shapeenum = 'Polygon' 
		order by location_guid, location_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by location_guid, location_localid, shape_id, geospatialinfo_guid having count(*) > 2
	order by location_guid;
						
-- create view to list only low-vertex polygons
drop view if exists public.wb_geocheck_obj_location_few_vertices_polys CASCADE;
create or replace view public.wb_geocheck_obj_location_few_vertices_polys as
	select location_guid, location_localid, shape_id, count(*) as pointcount
	from (select location_guid, location_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.wb_geocheck_zint_location_pts where shapeenum = 'Polygon' 
		order by location_guid, location_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by location_guid, location_localid, shape_id, geospatialinfo_guid having count(*) < 3
	order by location_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_location_valid_polys CASCADE;
create view public.wb_geocheck_zint_location_valid_polys as
	select location_guid, location_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_summary(shape) from public.wb_geocheck_zint_location_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid single-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_location_valid_singlepart_polys CASCADE;
create view public.wb_geocheck_zint_location_valid_singlepart_polys as
	select
	location_guid,
	location_localid,
	st_removerepeatedpoints(shape) as shape,
	substr(st_asewkt(st_exteriorring(st_removerepeatedpoints(shape))),11) as wkt,
	st_summary(st_removerepeatedpoints(shape)) as summary
	from public.wb_geocheck_zint_location_polys
	where ST_IsValid(shape) = 't'
		and location_guid in
			(select
			location_guid 
			from public.wb_geocheck_zint_location_pts 
			where shapeenum = 'Polygon' 
			group by location_guid 
			having count(distinct(geospatialinfo_guid)) = 1 
			order by 1);
	
-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.wb_geocheck_zint_location_valid_multipart_polys CASCADE;
create view public.wb_geocheck_zint_location_valid_multipart_polys as
	select
	location_guid,
	location_localid,
	st_collect(st_removerepeatedpoints(shape)) as shape,
	substr(st_asewkt(st_collect(st_exteriorring(st_removerepeatedpoints(shape)))),11) as wkt,
	st_summary(st_collect(st_removerepeatedpoints(shape))) as summary
	from public.wb_geocheck_zint_location_valid_polys 
	group by location_guid, location_localid
	having location_guid in
		(select
		location_guid 
		from public.wb_geocheck_zint_location_pts 
		where shapeenum = 'Polygon' 
		group by location_guid 
		having count(distinct(geospatialinfo_guid)) > 1 
		order by 1);
		
-- Create a subsidiary view of all polygons (single-part and multi-part) for each IMSMA object
drop view if exists public.wb_geocheck_zint_location_all_object_polys CASCADE;
create view public.wb_geocheck_zint_location_all_object_polys as
	select * from wb_geocheck_zint_location_valid_singlepart_polys
	union all
	select * from wb_geocheck_zint_location_valid_multipart_polys;

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.wb_geocheck_obj_location_invalid_polys CASCADE;
create view public.wb_geocheck_obj_location_invalid_polys as
	select location_guid, location_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11) as wkt, st_isvalidreason(shape), st_summary(shape) from public.wb_geocheck_zint_location_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin distance between consecutive points section
-------------------------------
-- This query calculates the distance between consecutive points in a Polygon
-- and returns the object type, the local id, the polygon id and the distance.
-- It is set to returns distances above 2000m (This value can be changed for each object type in the query).


drop view if exists public.wb_geocheck_adv_distance_polygon_points CASCADE; 
create or replace view public.wb_geocheck_adv_distance_polygon_points as

	(select 'HAZARD' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select hazard.hazard_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.hazard_has_geospatialinfo ON public.hazard_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.hazard on "public".hazard.hazard_guid = public.hazard_has_geospatialinfo.hazard_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- HAZARD REDUCTION
	(select 'HAZARD REDUCTION' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select hazreduc.hazreduc_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.hazreduc_has_geospatialinfo ON public.hazreduc_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.hazreduc on "public".hazreduc.hazreduc_guid = public.hazreduc_has_geospatialinfo.hazreduc_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- ACCIDENT
	(select 'ACCIDENT' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select accident.accident_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.accident_has_geospatialinfo ON public.accident_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.accident on "public".accident.accident_guid = public.accident_has_geospatialinfo.accident_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- MRE
	(select 'MRE' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select mre.mre_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.mre_has_geospatialinfo ON public.mre_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.mre on "public".mre.mre_guid = public.mre_has_geospatialinfo.mre_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- QA
	(select 'QA' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select qa.qa_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.qa_has_geospatialinfo ON public.qa_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.qa on "public".qa.qa_guid = public.qa_has_geospatialinfo.qa_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- VICTIM
	(select 'VICTIM' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select victim.victim_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.victim_has_geospatialinfo ON public.victim_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.victim on "public".victim.victim_guid = public.victim_has_geospatialinfo.victim_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- LOCATION
	(select 'LOCATION' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select location.location_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.location_has_geospatialinfo ON public.location_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.location on "public".location.location_guid = public.location_has_geospatialinfo.location_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- VICTIM ASSISTANCE
	(select 'VICTIM ASSISTANCE' as object_type, name1 as localid, shape1 as shapeid, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select victim_assistance.localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.victim_assistance_has_geospatialinfo ON public.victim_assistance_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.victim_assistance on "public".victim_assistance.guid = public.victim_assistance_has_geospatialinfo.victim_assistance_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	order by 1, 2;


-------------------------------
-- Begin duplicate polyID section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_polygon_polyid CASCADE; 
create or replace view public.wb_geocheck_duplicate_polygon_polyid as

	(select
		'HAZARD' as object_type,
		hazard.hazard_guid,
		hazard.hazard_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazard.hazard_guid, hazard.hazard_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident.accident_guid,
		accident.accident_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by accident.accident_guid, accident.accident_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre.mre_guid,
		mre.mre_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by mre.mre_guid, mre.mre_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa.qa_guid,
		qa.qa_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by qa.qa_guid, qa.qa_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim.victim_guid,
		victim.victim_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim.victim_guid, victim.victim_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location.location_guid,
		location.location_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by location.location_guid, location.location_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		victim_assistance.guid,
		victim_assistance.localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

	-------------------------------
-- Begin duplicate polyID trimmed section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_polygon_polyid_trimmed CASCADE; 
create or replace view public.wb_geocheck_duplicate_polygon_polyid_trimmed as

	(select
		'HAZARD' as object_type,
		hazard.hazard_guid,
		hazard.hazard_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazard.hazard_guid, hazard.hazard_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident.accident_guid,
		accident.accident_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by accident.accident_guid, accident.accident_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre.mre_guid,
		mre.mre_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by mre.mre_guid, mre.mre_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa.qa_guid,
		qa.qa_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by qa.qa_guid, qa.qa_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim.victim_guid,
		victim.victim_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim.victim_guid, victim.victim_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location.location_guid,
		location.location_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by location.location_guid, location.location_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		victim_assistance.guid,
		victim_assistance.localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id) as shape_id,
		count(*)
	from geospatialinfo
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;
	
-------------------------------
-- Begin duplicate pointlocal_id section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_point_point_localid CASCADE; 
create or replace view public.wb_geocheck_duplicate_point_point_localid as

	(select
		'HAZARD' as object_type,
		hazard.hazard_guid,
		hazard.hazard_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by hazard.hazard_guid, hazard.hazard_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident.accident_guid,
		accident.accident_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by accident.accident_guid, accident.accident_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre.mre_guid,
		mre.mre_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by mre.mre_guid, mre.mre_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa.qa_guid,
		qa.qa_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by qa.qa_guid, qa.qa_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim.victim_guid,
		victim.victim_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by victim.victim_guid, victim.victim_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location.location_guid,
		location.location_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by location.location_guid, location.location_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		victim_assistance.guid,
		victim_assistance.localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate pointlocal_id trimmed section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_point_point_localid_trimmed CASCADE; 
create or replace view public.wb_geocheck_duplicate_point_point_localid_trimmed as

	(select
		'HAZARD' as object_type,
		hazard.hazard_guid,
		hazard.hazard_localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by hazard.hazard_guid, hazard.hazard_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident.accident_guid,
		accident.accident_localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by accident.accident_guid, accident.accident_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre.mre_guid,
		mre.mre_localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by mre.mre_guid, mre.mre_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa.qa_guid,
		qa.qa_localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by qa.qa_guid, qa.qa_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim.victim_guid,
		victim.victim_localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by victim.victim_guid, victim.victim_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location.location_guid,
		location.location_localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by location.location_guid, location.location_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		victim_assistance.guid,
		victim_assistance.localid,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate pointlocal_id in Polygon section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_polygon_point_localid CASCADE; 
create or replace view public.wb_geocheck_duplicate_polygon_point_localid as

	(select
		'HAZARD' as object_type,
		hazard.hazard_guid,
		hazard.hazard_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazard.hazard_guid, hazard.hazard_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident.accident_guid,
		accident.accident_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by accident.accident_guid, accident.accident_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre.mre_guid,
		mre.mre_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by mre.mre_guid, mre.mre_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa.qa_guid,
		qa.qa_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by qa.qa_guid, qa.qa_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim.victim_guid,
		victim.victim_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim.victim_guid, victim.victim_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location.location_guid,
		location.location_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by location.location_guid, location.location_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		victim_assistance.guid,
		victim_assistance.localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate pointlocal_id in Polygon trimmed section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_polygon_point_localid_trimmed CASCADE; 
create or replace view public.wb_geocheck_duplicate_polygon_point_localid_trimmed as

	(select
		'HAZARD' as object_type,
		hazard.hazard_guid,
		hazard.hazard_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazard.hazard_guid, hazard.hazard_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident.accident_guid,
		accident.accident_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by accident.accident_guid, accident.accident_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre.mre_guid,
		mre.mre_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by mre.mre_guid, mre.mre_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa.qa_guid,
		qa.qa_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by qa.qa_guid, qa.qa_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim.victim_guid,
		victim.victim_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim.victim_guid, victim.victim_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location.location_guid,
		location.location_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by location.location_guid, location.location_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		victim_assistance.guid,
		victim_assistance.localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id) as pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate polygon section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_polygons CASCADE; 
create or replace view public.wb_geocheck_duplicate_polygons as

	(select
		'HAZARD' as object_type,
		hazard_guid,
		hazard_localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_hazard_polys
	group by hazard_guid, hazard_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc_guid,
		hazreduc_localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_hazreduc_polys
	group by hazreduc_guid, hazreduc_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident_guid,
		accident_localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_accident_polys
	group by accident_guid, accident_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre_guid,
		mre_localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_mre_polys
	group by mre_guid, mre_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa_guid,
		qa_localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_qa_polys
	group by qa_guid, qa_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim_guid,
		victim_localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_victim_polys
	group by victim_guid, victim_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location_guid,
		location_localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_location_polys
	group by location_guid, location_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		guid,
		localid,
		string_agg(shape_id :: TEXT,', ') as dup_shape_ids
	from wb_geocheck_zint_victim_assistance_polys
	group by guid, localid, shape
	having count(*) > 1
	order by 3)
	order by 1, 3;
	
-------------------------------
-- Begin duplicate points in polygon section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_polygon_points CASCADE; 
create or replace view public.wb_geocheck_duplicate_polygon_points as
	(select
		'HAZARD' as object_type,
		hazard_guid,
		hazard_localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_hazard_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by hazard_guid, hazard_localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	union
	(	select
		'HAZARD REDUCTION' as object_type,
		hazreduc_guid,
		hazreduc_localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_hazreduc_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by hazreduc_guid, hazreduc_localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	union
	(select
		'ACCIDENT' as object_type,
		accident_guid,
		accident_localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_accident_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by accident_guid, accident_localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	union
	(select
		'MRE' as object_type,
		mre_guid,
		mre_localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_mre_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by mre_guid, mre_localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	union
	(select
		'QA' as object_type,
		qa_guid,
		qa_localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_qa_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by qa_guid, qa_localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	union
	(select
		'VICTIM' as object_type,
		victim_guid,
		victim_localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_victim_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by victim_guid, victim_localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	union
	(select
		'LOCATION' as object_type,
		location_guid,
		location_localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_location_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by location_guid, location_localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		guid,
		localid,
		shape_id,
		string_agg(pointno :: TEXT,', ') as dup_point_numbers
	from wb_geocheck_zint_victim_assistance_pts
	where shapeenum = 'Polygon' or shapeenum = 'Polyline'
	group by guid, localid, shape_id, shape
	having count(*) > 1
	order by 3,4)
	order by 1, 3;
	
-------------------------------
-- Begin duplicate points section
-------------------------------

drop view if exists public.wb_geocheck_duplicate_points CASCADE; 
create or replace view public.wb_geocheck_duplicate_points as
	(select
		'HAZARD' as object_type,
		hazard.hazard_guid,
		hazard.hazard_localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_hazard_pts
		inner join geospatialinfo on wb_geocheck_zint_hazard_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by hazard.hazard_guid, hazard.hazard_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION' as object_type,
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_hazreduc_pts
		inner join geospatialinfo on wb_geocheck_zint_hazreduc_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid,  shape
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT' as object_type,
		accident.accident_guid,
		accident.accident_localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_accident_pts
		inner join geospatialinfo on wb_geocheck_zint_accident_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by accident.accident_guid, accident.accident_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE' as object_type,
		mre.mre_guid,
		mre.mre_localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_mre_pts
		inner join geospatialinfo on wb_geocheck_zint_mre_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by mre.mre_guid, mre.mre_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'QA' as object_type,
		qa.qa_guid,
		qa.qa_localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_qa_pts
		inner join geospatialinfo on wb_geocheck_zint_qa_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by qa.qa_guid, qa.qa_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM' as object_type,
		victim.victim_guid,
		victim.victim_localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_victim_pts
		inner join geospatialinfo on wb_geocheck_zint_victim_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by victim.victim_guid, victim.victim_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION' as object_type,
		location.location_guid,
		location.location_localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_location_pts
		inner join geospatialinfo on wb_geocheck_zint_location_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by location.location_guid, location.location_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE' as object_type,
		victim_assistance.guid,
		victim_assistance.localid,
		string_agg(pointlocal_id,', ') as dup_point_ids
	from wb_geocheck_zint_victim_assistance_pts
		inner join geospatialinfo on wb_geocheck_zint_victim_assistance_pts.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, shape
	having count(*) > 1
	order by 3)
	order by 1, 3;

-------------------------------
-- Begin overlapping polygon section
-------------------------------

drop view if exists public.wb_geocheck_adv_overlapping_polygons CASCADE; 
create or replace view public.wb_geocheck_adv_overlapping_polygons as
	(select 'HAZARD' as object_type, hazard_localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_hazard_valid_polys.hazard_localid,
		st_collect(wb_geocheck_zint_hazard_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_hazard_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_hazard_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_hazard_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_hazard_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_hazard_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_hazard_valid_polys
		GROUP BY wb_geocheck_zint_hazard_valid_polys.hazard_localid
		HAVING ((wb_geocheck_zint_hazard_valid_polys.hazard_localid)::text IN
			(SELECT wb_geocheck_zint_hazard_pts.hazard_localid FROM wb_geocheck_zint_hazard_pts WHERE ((wb_geocheck_zint_hazard_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_hazard_pts.hazard_localid HAVING (count(DISTINCT wb_geocheck_zint_hazard_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_hazard_pts.	hazard_localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc)
	union all
	(select 'HAZARD REDUCTION' as object_type, hazreduc_localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_hazreduc_valid_polys.hazreduc_localid,
		st_collect(wb_geocheck_zint_hazreduc_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_hazreduc_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_hazreduc_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_hazreduc_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_hazreduc_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_hazreduc_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_hazreduc_valid_polys
		GROUP BY wb_geocheck_zint_hazreduc_valid_polys.hazreduc_localid
		HAVING ((wb_geocheck_zint_hazreduc_valid_polys.hazreduc_localid)::text IN
			(SELECT wb_geocheck_zint_hazreduc_pts.hazreduc_localid FROM wb_geocheck_zint_hazreduc_pts WHERE ((wb_geocheck_zint_hazreduc_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_hazreduc_pts.hazreduc_localid HAVING (count(DISTINCT wb_geocheck_zint_hazreduc_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_hazreduc_pts.	hazreduc_localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc)
	union all
	(select 'ACCIDENT' as object_type, accident_localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_accident_valid_polys.accident_localid,
		st_collect(wb_geocheck_zint_accident_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_accident_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_accident_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_accident_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_accident_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_accident_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_accident_valid_polys
		GROUP BY wb_geocheck_zint_accident_valid_polys.accident_localid
		HAVING ((wb_geocheck_zint_accident_valid_polys.accident_localid)::text IN
			(SELECT wb_geocheck_zint_accident_pts.accident_localid FROM wb_geocheck_zint_accident_pts WHERE ((wb_geocheck_zint_accident_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_accident_pts.accident_localid HAVING (count(DISTINCT wb_geocheck_zint_accident_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_accident_pts.	accident_localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc)
	union all
	(select 'MRE' as object_type, mre_localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_mre_valid_polys.mre_localid,
		st_collect(wb_geocheck_zint_mre_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_mre_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_mre_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_mre_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_mre_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_mre_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_mre_valid_polys
		GROUP BY wb_geocheck_zint_mre_valid_polys.mre_localid
		HAVING ((wb_geocheck_zint_mre_valid_polys.mre_localid)::text IN
			(SELECT wb_geocheck_zint_mre_pts.mre_localid FROM wb_geocheck_zint_mre_pts WHERE ((wb_geocheck_zint_mre_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_mre_pts.mre_localid HAVING (count(DISTINCT wb_geocheck_zint_mre_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_mre_pts.	mre_localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc)
	union all
	(select 'QA' as object_type, qa_localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_qa_valid_polys.qa_localid,
		st_collect(wb_geocheck_zint_qa_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_qa_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_qa_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_qa_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_qa_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_qa_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_qa_valid_polys
		GROUP BY wb_geocheck_zint_qa_valid_polys.qa_localid
		HAVING ((wb_geocheck_zint_qa_valid_polys.qa_localid)::text IN
			(SELECT wb_geocheck_zint_qa_pts.qa_localid FROM wb_geocheck_zint_qa_pts WHERE ((wb_geocheck_zint_qa_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_qa_pts.qa_localid HAVING (count(DISTINCT wb_geocheck_zint_qa_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_qa_pts.	qa_localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc)
	union all
	(select 'VICTIM' as object_type, victim_localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_victim_valid_polys.victim_localid,
		st_collect(wb_geocheck_zint_victim_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_victim_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_victim_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_victim_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_victim_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_victim_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_victim_valid_polys
		GROUP BY wb_geocheck_zint_victim_valid_polys.victim_localid
		HAVING ((wb_geocheck_zint_victim_valid_polys.victim_localid)::text IN
			(SELECT wb_geocheck_zint_victim_pts.victim_localid FROM wb_geocheck_zint_victim_pts WHERE ((wb_geocheck_zint_victim_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_victim_pts.victim_localid HAVING (count(DISTINCT wb_geocheck_zint_victim_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_victim_pts.	victim_localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc)
	union all
	(select 'LOCATION' as object_type, location_localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_location_valid_polys.location_localid,
		st_collect(wb_geocheck_zint_location_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_location_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_location_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_location_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_location_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_location_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_location_valid_polys
		GROUP BY wb_geocheck_zint_location_valid_polys.location_localid
		HAVING ((wb_geocheck_zint_location_valid_polys.location_localid)::text IN
			(SELECT wb_geocheck_zint_location_pts.location_localid FROM wb_geocheck_zint_location_pts WHERE ((wb_geocheck_zint_location_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_location_pts.location_localid HAVING (count(DISTINCT wb_geocheck_zint_location_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_location_pts.	location_localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc)
	union all
	(select 'VICTIM ASSISTANCE' as object_type, localid as localid, wkt, overlap from 
		(SELECT wb_geocheck_zint_victim_assistance_valid_polys.localid,
		st_collect(wb_geocheck_zint_victim_assistance_valid_polys.shape) AS st_collect,
		st_union(wb_geocheck_zint_victim_assistance_valid_polys.shape) AS st_union,
		substr(st_asewkt(st_collect(st_exteriorring(wb_geocheck_zint_victim_assistance_valid_polys.shape))), 11) AS wkt,
		to_number(to_char((st_area(st_transform(st_collect(wb_geocheck_zint_victim_assistance_valid_polys.shape),3395)) - st_area(st_transform(st_union(wb_geocheck_zint_victim_assistance_valid_polys.shape),3395)))/st_area(st_transform(st_union(wb_geocheck_zint_victim_assistance_valid_polys.shape),3395))*100,'999D99'),'999D99')  as overlap
		FROM wb_geocheck_zint_victim_assistance_valid_polys
		GROUP BY wb_geocheck_zint_victim_assistance_valid_polys.localid
		HAVING ((wb_geocheck_zint_victim_assistance_valid_polys.localid)::text IN
			(SELECT wb_geocheck_zint_victim_assistance_pts.localid FROM wb_geocheck_zint_victim_assistance_pts WHERE ((wb_geocheck_zint_victim_assistance_pts.shapeenum)::text = 'Polygon'::text)
			GROUP BY wb_geocheck_zint_victim_assistance_pts.localid HAVING (count(DISTINCT wb_geocheck_zint_victim_assistance_pts.geospatialinfo_guid) > 1) ORDER BY wb_geocheck_zint_victim_assistance_pts.	localid))) as tmp
	where (st_collect::TEXT != st_union::TEXT) and overlap > 0.9
	order by overlap  desc);