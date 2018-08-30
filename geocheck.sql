-- To change the distance between points for the distance check query:
--  do a replace all on "5000 -- CHANGE MIN"

-- V2
--	Change name to geocheck
--	The views are now created in the public schema
--	Shape_id added to all the invalid polygon views
--	Integration of Polygon_Distance_Check.sql (5000m), the results are in geocheck_distance_polygon_points
--	Queries added for Task, Gazetteer, Location, Place and Organisation
--	Duplicate polygon ID can be found in geocheck_duplicate_polygon_polyid
--	Duplicate point localid can be found in geocheck_duplicate_point_point_localid
--	Duplicate polygons can be found in geocheck_duplicate_polygons

-- V2.1
--	Duplicate polygon ID with trimmed ID can be found in geocheck_duplicate_polygon_polyid_trimmed
--	Duplicate point localid with trimmed ID can be found in geocheck_duplicate_point_point_localid_trimmed
--	Duplicate point localid in polygon can be found in geocheck_duplicate_polygon_point_localid
--	Duplicate point localid in polygon with trimmed ID can be found in geocheck_duplicate_polygon_point_localid_trimmed
--	Duplicate point localid in polygon (Dist and Bearing only) can be found in geocheck_duplicate_polygon_point_localid_dist_and_bear
--	Duplicate point localid in polygon (Dist and Bearing only) with trimmed ID can be found in geocheck_duplicate_polygon_point_localid_dist_and_bear_trimmed

-- V2.2
--	Duplicate points in polygon can be found in geocheck_duplicate_points_in_polygons

-- V2.3
--	Add geocheck_**_geo_valid_multipart_polys to identify features with multiple polygons defined for one object.
--	Remove SRID information in wkt string to simplify copy/paste

-------------------------------
-- Begin hazard section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_hazard_geo_pts CASCADE; 
create or replace view public.geocheck_hazard_geo_pts as

   select
	hazard.hazard_guid,
	hazard.hazard_localid,
	hazard_has_geospatialinfo.geospatialinfo_guid,
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
	inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
	inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_hazard_geo_polys CASCADE;
create or replace view public.geocheck_hazard_geo_polys as
	select hazard_guid, hazard_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_hazard_geo_pts where shapeenum = 'Polygon' 
		order by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid having count(*) > 2
	order by hazard_guid;
						
-- create view to list only low-vertex polygons
drop view if exists public.geocheck_hazard_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_hazard_geo_polys_few_vertices as
	select hazard_guid, hazard_localid, shape_id, count(*) as pointcount
	from (select hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_hazard_geo_pts where shapeenum = 'Polygon' 
		order by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by hazard_guid, hazard_localid, shape_id, geospatialinfo_guid having count(*) < 3
	order by hazard_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_hazard_geo_valid_polys CASCADE;
create view public.geocheck_hazard_geo_valid_polys as
	select hazard_guid, hazard_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_hazard_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_hazard_geo_valid_multipart_polys CASCADE;
create view public.geocheck_hazard_geo_valid_multipart_polys as
	select hazard_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_hazard_geo_polys 
        group by hazard_localid
        having hazard_localid in (  select hazard_localid 
                                    from public.geocheck_hazard_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by hazard_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);

    
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_hazard_geo_invalid_polys CASCADE;
create view public.geocheck_hazard_geo_invalid_polys as
	select hazard_guid, hazard_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_hazard_geo_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin hazreduc section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_hazreduc_geo_pts CASCADE; 
create or replace view public.geocheck_hazreduc_geo_pts as

   select
	hazreduc.hazreduc_guid,
	hazreduc.hazreduc_localid,
	hazreduc_has_geospatialinfo.geospatialinfo_guid,
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
	inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
	inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;


-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_hazreduc_geo_polys CASCADE;
create or replace view public.geocheck_hazreduc_geo_polys as
	select hazreduc_guid, hazreduc_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_hazreduc_geo_pts where shapeenum = 'Polygon' 
		order by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by hazreduc_guid;

-- create view to list only low-vertex polygons
drop view if exists public.geocheck_hazreduc_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_hazreduc_geo_polys_few_vertices as
    select hazreduc_guid, hazreduc_localid, shape_id, count(*) as pointcount
    from (select hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
        from public.geocheck_hazreduc_geo_pts where shapeenum = 'Polygon' 
        order by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid, pointno) as values 
    group by hazreduc_guid, hazreduc_localid, shape_id, geospatialinfo_guid  having count(*) < 3
    order by hazreduc_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_hazreduc_geo_valid_polys CASCADE;
create view public.geocheck_hazreduc_geo_valid_polys as
select hazreduc_guid, hazreduc_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_hazreduc_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_hazreduc_geo_valid_multipart_polys CASCADE;
create view public.geocheck_hazreduc_geo_valid_multipart_polys as
    select hazreduc_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_hazreduc_geo_polys 
        group by hazreduc_localid
        having hazreduc_localid in (  select hazreduc_localid 
                                    from public.geocheck_hazreduc_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by hazreduc_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
    
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_hazreduc_geo_invalid_polys CASCADE;
create view public.geocheck_hazreduc_geo_invalid_polys as
	select hazreduc_guid, hazreduc_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_hazreduc_geo_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin accident section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_accident_geo_pts CASCADE; 
create or replace view public.geocheck_accident_geo_pts as

   select
	accident.accident_guid,
	accident.accident_localid,
	accident_has_geospatialinfo.geospatialinfo_guid,
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
	inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
	inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_accident_geo_polys CASCADE;
create or replace view public.geocheck_accident_geo_polys as
	select accident_guid, accident_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_accident_geo_pts where shapeenum = 'Polygon' 
		order by accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno)	as values 
	group by accident_guid, accident_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by accident_guid;

-- create view to list only low-vertex polygons
drop view if exists public.geocheck_accident_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_accident_geo_polys_few_vertices as
	select accident_guid, accident_localid, shape_id, count(*) as pointcount
	from (select accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_accident_geo_pts where shapeenum = 'Polygon' 
		order by accident_guid, accident_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by accident_guid, accident_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by accident_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_accident_geo_valid_polys CASCADE;
create view public.geocheck_accident_geo_valid_polys as
	select accident_guid, accident_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_accident_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_accident_geo_valid_multipart_polys CASCADE;
create view public.geocheck_accident_geo_valid_multipart_polys as
    select accident_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_accident_geo_polys 
        group by accident_localid
        having accident_localid in (  select accident_localid 
                                    from public.geocheck_accident_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by accident_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_accident_geo_invalid_polys CASCADE;
create view public.geocheck_accident_geo_invalid_polys as
	select accident_guid, accident_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_accident_geo_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin mre section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_mre_geo_pts CASCADE; 
create or replace view public.geocheck_mre_geo_pts as

   select
	mre.mre_guid,
	mre.mre_localid,
	mre_has_geospatialinfo.geospatialinfo_guid,
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
	inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
	inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_mre_geo_polys CASCADE;
create or replace view public.geocheck_mre_geo_polys as
	select mre_guid, mre_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_mre_geo_pts where shapeenum = 'Polygon' 
		order by mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by mre_guid, mre_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by mre_guid;

-- create view to list only low-vertex polygons
drop view if exists public.geocheck_mre_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_mre_geo_polys_few_vertices as
	select mre_guid, mre_localid, shape_id, count(*) as pointcount
	from (select mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_mre_geo_pts where shapeenum = 'Polygon' 
		order by mre_guid, mre_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by mre_guid, mre_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by mre_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_mre_geo_valid_polys CASCADE;
create view public.geocheck_mre_geo_valid_polys as
	select mre_guid, mre_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_mre_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_mre_geo_valid_multipart_polys CASCADE;
create view public.geocheck_mre_geo_valid_multipart_polys as
    select mre_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_mre_geo_polys 
        group by mre_localid
        having mre_localid in (  select mre_localid 
                                    from public.geocheck_mre_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by mre_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_mre_geo_invalid_polys CASCADE;
create view public.geocheck_mre_geo_invalid_polys as
	select mre_guid, mre_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_mre_geo_polys where ST_IsValid(shape) = 'f';
	
-------------------------------
-- Begin qa section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_qa_geo_pts CASCADE; 
create or replace view public.geocheck_qa_geo_pts as

   select
	qa.qa_guid,
	qa.qa_localid,
	qa_has_geospatialinfo.geospatialinfo_guid,
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
	inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
	inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_qa_geo_polys CASCADE;
create or replace view public.geocheck_qa_geo_polys as
	select qa_guid, qa_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_qa_geo_pts where shapeenum = 'Polygon' 
		order by qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by qa_guid, qa_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by qa_guid;

-- create view to list only low-vertex polygons
drop view if exists public.geocheck_qa_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_qa_geo_polys_few_vertices as
	select qa_guid, qa_localid, shape_id, count(*) as pointcount
	from (select qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_qa_geo_pts where shapeenum = 'Polygon' 
		order by qa_guid, qa_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by qa_guid, qa_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by qa_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_qa_geo_valid_polys CASCADE;
create view public.geocheck_qa_geo_valid_polys as
	select qa_guid, qa_localid, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_qa_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_qa_geo_valid_multipart_polys CASCADE;
create view public.geocheck_qa_geo_valid_multipart_polys as
    select qa_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_qa_geo_polys 
        group by qa_localid
        having qa_localid in (  select qa_localid 
                                    from public.geocheck_qa_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by qa_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_qa_geo_invalid_polys CASCADE;
create view public.geocheck_qa_geo_invalid_polys as
	select qa_guid, qa_localid, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_qa_geo_polys where ST_IsValid(shape) = 'f';
	
-------------------------------
-- Begin victim section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_victim_geo_pts CASCADE; 
create or replace view public.geocheck_victim_geo_pts as

   select
	victim.victim_guid,
	victim.victim_localid,
	victim_has_geospatialinfo.geospatialinfo_guid,
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
	inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
	inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_victim_geo_polys CASCADE;
create or replace view public.geocheck_victim_geo_polys as
	select victim_guid, victim_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_victim_geo_pts where shapeenum = 'Polygon' 
		order by victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by victim_guid, victim_localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by victim_guid;

-- create view to list only low-vertex polygons
drop view if exists public.geocheck_victim_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_victim_geo_polys_few_vertices as
	select victim_guid, victim_localid, shape_id, count(*) as pointcount
	from (select victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_victim_geo_pts where shapeenum = 'Polygon' 
		order by victim_guid, victim_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by victim_guid, victim_localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by victim_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_victim_geo_valid_polys CASCADE;
create view public.geocheck_victim_geo_valid_polys as
	select victim_guid, victim_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_victim_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_victim_geo_valid_multipart_polys CASCADE;
create view public.geocheck_victim_geo_valid_multipart_polys as
    select victim_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_victim_geo_polys 
        group by victim_localid
        having victim_localid in (  select victim_localid 
                                    from public.geocheck_victim_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by victim_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_victim_geo_invalid_polys CASCADE;
create view public.geocheck_victim_geo_invalid_polys as
	select victim_guid, victim_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_victim_geo_polys where ST_IsValid(shape) = 'f';

-------------------------------
-- Begin victim_assistance section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_victim_assistance_geo_pts CASCADE; 
create or replace view public.geocheck_victim_assistance_geo_pts as

   select
	victim_assistance.guid,
	victim_assistance.localid,
	victim_assistance_has_geospatialinfo.geospatialinfo_guid,
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
	inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
	inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_victim_assistance_geo_polys CASCADE;
create or replace view public.geocheck_victim_assistance_geo_polys as
	select guid, localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select guid, localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_victim_assistance_geo_pts where shapeenum = 'Polygon' 
		order by guid, localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by guid, localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by guid;

-- create view to list only low-vertex polygons
drop view if exists public.geocheck_victim_assistance_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_victim_assistance_geo_polys_few_vertices as
	select guid, localid, shape_id, count(*) as pointcount
	from (select guid, localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_victim_assistance_geo_pts where shapeenum = 'Polygon' 
		order by guid, localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by guid, localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_victim_assistance_geo_valid_polys CASCADE;
create view public.geocheck_victim_assistance_geo_valid_polys as
	select guid, localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_victim_assistance_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_victim_assistance_geo_valid_multipart_polys CASCADE;
create view public.geocheck_victim_assistance_geo_valid_multipart_polys as
    select localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_victim_assistance_geo_polys 
        group by localid
        having localid in (  select localid 
                                    from public.geocheck_victim_assistance_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_victim_assistance_geo_invalid_polys CASCADE;
create view public.geocheck_victim_assistance_geo_invalid_polys as
	select guid, localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_victim_assistance_geo_polys where ST_IsValid(shape) = 'f';
	

-------------------------------
-- Begin task section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_task_geo_pts CASCADE; 
create or replace view public.geocheck_task_geo_pts as

   select
	task.guid,
	task.localid,
	task_has_geospatialinfo.geospatialinfo_guid,
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
	inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
	inner join task on task_has_geospatialinfo.task_guid = task.guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_task_geo_polys CASCADE;
create or replace view public.geocheck_task_geo_polys as
	select guid, localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select guid, localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_task_geo_pts where shapeenum = 'Polygon' 
		order by guid, localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by guid, localid, shape_id, geospatialinfo_guid  having count(*) > 2
	order by guid;

-- create view to list only low-vertex polygons
drop view if exists public.geocheck_task_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_task_geo_polys_few_vertices as
	select guid, localid, shape_id, count(*) as pointcount
	from (select guid, localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_task_geo_pts where shapeenum = 'Polygon' 
		order by guid, localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by guid, localid, shape_id, geospatialinfo_guid  having count(*) < 3
	order by guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_task_geo_valid_polys CASCADE;
create view public.geocheck_task_geo_valid_polys as
	select guid, localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_task_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_task_geo_valid_multipart_polys CASCADE;
create view public.geocheck_task_geo_valid_multipart_polys as
    select localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_task_geo_polys 
        group by localid
        having localid in (  select localid 
                                    from public.geocheck_task_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_task_geo_invalid_polys CASCADE;
create view public.geocheck_task_geo_invalid_polys as
	select guid, localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_task_geo_polys where ST_IsValid(shape) = 'f';

-------------------------------
-- Begin gazetteer section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_gazetteer_geo_pts CASCADE; 
create or replace view public.geocheck_gazetteer_geo_pts as

   select
	gazetteer.gazetteer_guid,
	gazetteer.gazetteer_localid,
	gazetteer_has_geospatialinfo.geospatialinfo_guid,
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
	inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
	inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_gazetteer_geo_polys CASCADE;
create or replace view public.geocheck_gazetteer_geo_polys as
	select gazetteer_guid, gazetteer_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select gazetteer_guid, gazetteer_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_gazetteer_geo_pts where shapeenum = 'Polygon' 
		order by gazetteer_guid, gazetteer_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by gazetteer_guid, gazetteer_localid, shape_id, geospatialinfo_guid having count(*) > 2
	order by gazetteer_guid;
						
-- create view to list only low-vertex polygons
drop view if exists public.geocheck_gazetteer_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_gazetteer_geo_polys_few_vertices as
	select gazetteer_guid, gazetteer_localid, shape_id, count(*) as pointcount
	from (select gazetteer_guid, gazetteer_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_gazetteer_geo_pts where shapeenum = 'Polygon' 
		order by gazetteer_guid, gazetteer_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by gazetteer_guid, gazetteer_localid, shape_id, geospatialinfo_guid having count(*) < 3
	order by gazetteer_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_gazetteer_geo_valid_polys CASCADE;
create view public.geocheck_gazetteer_geo_valid_polys as
	select gazetteer_guid, gazetteer_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_gazetteer_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_gazetteer_geo_valid_multipart_polys CASCADE;
create view public.geocheck_gazetteer_geo_valid_multipart_polys as
    select gazetteer_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_gazetteer_geo_polys 
        group by gazetteer_localid
        having gazetteer_localid in (  select gazetteer_localid 
                                    from public.geocheck_gazetteer_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by gazetteer_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_gazetteer_geo_invalid_polys CASCADE;
create view public.geocheck_gazetteer_geo_invalid_polys as
	select gazetteer_guid, gazetteer_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_gazetteer_geo_polys where ST_IsValid(shape) = 'f';

-------------------------------
-- Begin location section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_location_geo_pts CASCADE; 
create or replace view public.geocheck_location_geo_pts as

   select
	location.location_guid,
	location.location_localid,
	location_has_geospatialinfo.geospatialinfo_guid,
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
	inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
	inner join location on location_has_geospatialinfo.location_guid = location.location_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_location_geo_polys CASCADE;
create or replace view public.geocheck_location_geo_polys as
	select location_guid, location_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select location_guid, location_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_location_geo_pts where shapeenum = 'Polygon' 
		order by location_guid, location_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by location_guid, location_localid, shape_id, geospatialinfo_guid having count(*) > 2
	order by location_guid;
						
-- create view to list only low-vertex polygons
drop view if exists public.geocheck_location_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_location_geo_polys_few_vertices as
	select location_guid, location_localid, shape_id, count(*) as pointcount
	from (select location_guid, location_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_location_geo_pts where shapeenum = 'Polygon' 
		order by location_guid, location_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by location_guid, location_localid, shape_id, geospatialinfo_guid having count(*) < 3
	order by location_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_location_geo_valid_polys CASCADE;
create view public.geocheck_location_geo_valid_polys as
	select location_guid, location_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_location_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_location_geo_valid_multipart_polys CASCADE;
create view public.geocheck_location_geo_valid_multipart_polys as
    select location_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_location_geo_polys 
        group by location_localid
        having location_localid in (  select location_localid 
                                    from public.geocheck_location_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by location_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_location_geo_invalid_polys CASCADE;
create view public.geocheck_location_geo_invalid_polys as
	select location_guid, location_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_location_geo_polys where ST_IsValid(shape) = 'f';

-------------------------------
-- Begin place section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_place_geo_pts CASCADE; 
create or replace view public.geocheck_place_geo_pts as

   select
	place.place_guid,
	place.place_localid,
	place_has_geospatialinfo.geospatialinfo_guid,
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
	inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
	inner join place on place_has_geospatialinfo.place_guid = place.place_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_place_geo_polys CASCADE;
create or replace view public.geocheck_place_geo_polys as
	select place_guid, place_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select place_guid, place_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_place_geo_pts where shapeenum = 'Polygon' 
		order by place_guid, place_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by place_guid, place_localid, shape_id, geospatialinfo_guid having count(*) > 2
	order by place_guid;
						
-- create view to list only low-vertex polygons
drop view if exists public.geocheck_place_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_place_geo_polys_few_vertices as
	select place_guid, place_localid, shape_id, count(*) as pointcount
	from (select place_guid, place_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_place_geo_pts where shapeenum = 'Polygon' 
		order by place_guid, place_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by place_guid, place_localid, shape_id, geospatialinfo_guid having count(*) < 3
	order by place_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_place_geo_valid_polys CASCADE;
create view public.geocheck_place_geo_valid_polys as
	select place_guid, place_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_place_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_place_geo_valid_multipart_polys CASCADE;
create view public.geocheck_place_geo_valid_multipart_polys as
    select place_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_place_geo_polys 
        group by place_localid
        having place_localid in (  select place_localid 
                                    from public.geocheck_place_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by place_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_place_geo_invalid_polys CASCADE;
create view public.geocheck_place_geo_invalid_polys as
	select place_guid, place_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_place_geo_polys where ST_IsValid(shape) = 'f';

-------------------------------
-- Begin organisation section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists public.geocheck_organisation_geo_pts CASCADE; 
create or replace view public.geocheck_organisation_geo_pts as

   select
	organisation.org_guid,
	organisation.org_localid,
	organisation_has_geospatialinfo.geospatialinfo_guid,
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
	inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
	inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
	left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
   order by geopoint.geospatialinfo_guid, geopoint.pointno;
   
 
-- Create a spatial view based on the points from the previous view, built into polygons and ordered by pointno.
-- This view can be materialized in PostgreSQL 9.3+
drop view if exists public.geocheck_organisation_geo_polys CASCADE;
create or replace view public.geocheck_organisation_geo_polys as
	select org_guid, org_localid, shape_id,
		ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
		count(*) as pointcount
	from (select org_guid, org_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_organisation_geo_pts where shapeenum = 'Polygon' 
		order by org_guid, org_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by org_guid, org_localid, shape_id, geospatialinfo_guid having count(*) > 2
	order by org_guid;
						
-- create view to list only low-vertex polygons
drop view if exists public.geocheck_organisation_geo_polys_few_vertices CASCADE;
create or replace view public.geocheck_organisation_geo_polys_few_vertices as
	select org_guid, org_localid, shape_id, count(*) as pointcount
	from (select org_guid, org_localid, shape_id, geospatialinfo_guid, pointno, longitude, latitude
		from public.geocheck_organisation_geo_pts where shapeenum = 'Polygon' 
		order by org_guid, org_localid, shape_id, geospatialinfo_guid, pointno) as values 
	group by org_guid, org_localid, shape_id, geospatialinfo_guid having count(*) < 3
	order by org_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_organisation_geo_valid_polys CASCADE;
create view public.geocheck_organisation_geo_valid_polys as
	select org_guid, org_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_summary(shape) from public.geocheck_organisation_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all valid multi-part polygons within that view (extracts valid polygons only)
drop view if exists public.geocheck_organisation_geo_valid_multipart_polys CASCADE;
create view public.geocheck_organisation_geo_valid_multipart_polys as
    select org_localid, st_collect(shape), substr(st_asewkt(st_collect(st_exteriorring(shape))),11), st_summary(st_collect(shape))
        from public.geocheck_organisation_geo_polys 
        group by org_localid
        having org_localid in (  select org_localid 
                                    from public.geocheck_organisation_geo_pts 
                                    where shapeenum = 'Polygon' 
                                    group by org_localid 
                                    having count(distinct(geospatialinfo_guid)) > 1 
                                    order by 1);
									
-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists public.geocheck_organisation_geo_invalid_polys CASCADE;
create view public.geocheck_organisation_geo_invalid_polys as
	select org_guid, org_localid, shape_id, shape, substr(st_asewkt(st_exteriorring(shape)),11), st_isvalidreason(shape), st_summary(shape) from public.geocheck_organisation_geo_polys where ST_IsValid(shape) = 'f';

-------------------------------
-- Begin distance between consecutive points section
-------------------------------
-- This query calculates the distance between consecutive points in a Polygon
-- and returns the object type, the local id, the polygon id and the distance.
-- It is set to returns distances above 2000m (This value can be changed for each object type in the query).


drop view if exists public.geocheck_distance_polygon_points CASCADE; 
create or replace view public.geocheck_distance_polygon_points as

	(select 'HAZARD', name1, shape1, distance from
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
	(select 'HAZARD REDUCTION', name1, shape1, distance from
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
	(select 'ACCIDENT', name1, shape1, distance from
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
	(select 'MRE', name1, shape1, distance from
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
	(select 'QA', name1, shape1, distance from
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
	(select 'VICTIM', name1, shape1, distance from
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
	-- GAZETTEER
	(select 'GAZETTEER', name1, shape1, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select gazetteer.gazetteer_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.gazetteer_has_geospatialinfo ON public.gazetteer_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.gazetteer on "public".gazetteer.gazetteer_guid = public.gazetteer_has_geospatialinfo.gazetteer_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- LOCATION
	(select 'LOCATION', name1, shape1, distance from
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
	-- PLACE
	(select 'PLACE', name1, shape1, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select place.place_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.place_has_geospatialinfo ON public.place_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.place on "public".place.place_guid = public.place_has_geospatialinfo.place_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- VICTIM ASSISTANCE
	(select 'VICTIM ASSISTANCE', name1, shape1, distance from
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
	union
	-- TASK
	(select 'TASK', name1, shape1, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select task.localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.task_has_geospatialinfo ON public.task_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.task on "public".task.guid = public.task_has_geospatialinfo.task_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	union
	-- ORGANISATION
	(select 'ORGANISATION', name1, shape1, distance from
	(select name as name1, shape_id as shape1, lead(name) over (order by name, shape_id, pointno) as name2,
	lead(shape_id) over (order by name, shape_id, pointno) as shape2,
	st_distance_sphere(point, lead(point) over(order by name, shape_id, pointno)) as distance from (
	select organisation.org_localid as name, geospatialinfo.shape_id as shape_id, st_setsrid(st_makepoint(longitude,latitude),4326) as point, pointno
	FROM public.geopoint
	INNER JOIN public.geospatialinfo ON public.geopoint.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.imsmaenum ON public.geospatialinfo.shapeenum_guid = public.imsmaenum.imsmaenum_guid
	INNER JOIN public.organisation_has_geospatialinfo ON public.organisation_has_geospatialinfo.geospatialinfo_guid = public.geospatialinfo.geospatialinfo_guid
	INNER JOIN public.organisation on "public".organisation.org_guid = public.organisation_has_geospatialinfo.org_guid
	WHERE public.imsmaenum.enumvalue LIKE 'Polygon'
	order by name, shape_id, pointno ) as tmptable) as tmptable2
	where name1 = name2 and shape1 = shape2 and distance > 5000 -- CHANGE MIN VALUE BETWEEN 2 POINTS HERE
	order by name1, shape1)
	order by 1, 2;


-------------------------------
-- Begin duplicate polyID section
-------------------------------

drop view if exists public.geocheck_duplicate_polygon_polyid CASCADE; 
create or replace view public.geocheck_duplicate_polygon_polyid as

	(select
		'HAZARD',
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
		'HAZARD REDUCTION',
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
		'ACCIDENT',
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
		'MRE',
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
		'QA',
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
		'VICTIM',
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
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
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
		'PLACE',
		place.place_guid,
		place.place_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by place.place_guid, place.place_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
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
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by task.guid, task.localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		geospatialinfo.shape_id,
		count(*)
	from geospatialinfo
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by organisation.org_guid, organisation.org_localid, geospatialinfo.shape_id, ime01.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

	-------------------------------
-- Begin duplicate polyID trimmed section
-------------------------------

drop view if exists public.geocheck_duplicate_polygon_polyid_trimmed CASCADE; 
create or replace view public.geocheck_duplicate_polygon_polyid_trimmed as

	(select
		'HAZARD',
		hazard.hazard_guid,
		hazard.hazard_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
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
		'HAZARD REDUCTION',
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
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
		'ACCIDENT',
		accident.accident_guid,
		accident.accident_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
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
		'MRE',
		mre.mre_guid,
		mre.mre_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
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
		'QA',
		qa.qa_guid,
		qa.qa_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
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
		'VICTIM',
		victim.victim_guid,
		victim.victim_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
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
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
		count(*)
	from geospatialinfo
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location.location_guid,
		location.location_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
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
		'PLACE',
		place.place_guid,
		place.place_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
		count(*)
	from geospatialinfo
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by place.place_guid, place.place_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		victim_assistance.guid,
		victim_assistance.localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
		count(*)
	from geospatialinfo
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by victim_assistance.guid, victim_assistance.localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
		count(*)
	from geospatialinfo
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by task.guid, task.localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		ime01.enumvalue as shapeenum, -- geospatialinfo.shapeenum
		trim(geospatialinfo.shape_id),
		count(*)
	from geospatialinfo
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by organisation.org_guid, organisation.org_localid, trim(geospatialinfo.shape_id), ime01.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;
	
-------------------------------
-- Begin duplicate pointlocal_id section
-------------------------------

drop view if exists public.geocheck_duplicate_point_point_localid CASCADE; 
create or replace view public.geocheck_duplicate_point_point_localid as

	(select
		'HAZARD',
		hazard.hazard_guid,
		hazard.hazard_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'HAZARD REDUCTION',
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'ACCIDENT',
		accident.accident_guid,
		accident.accident_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'MRE',
		mre.mre_guid,
		mre.mre_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'QA',
		qa.qa_guid,
		qa.qa_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'VICTIM',
		victim.victim_guid,
		victim.victim_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location.location_guid,
		location.location_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'PLACE',
		place.place_guid,
		place.place_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by place.place_guid, place.place_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		victim_assistance.guid,
		victim_assistance.localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by task.guid, task.localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by organisation.org_guid, organisation.org_localid, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate pointlocal_id trimmed section
-------------------------------

drop view if exists public.geocheck_duplicate_point_point_localid_trimmed CASCADE; 
create or replace view public.geocheck_duplicate_point_point_localid_trimmed as

	(select
		'HAZARD',
		hazard.hazard_guid,
		hazard.hazard_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'HAZARD REDUCTION',
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'ACCIDENT',
		accident.accident_guid,
		accident.accident_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'MRE',
		mre.mre_guid,
		mre.mre_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'QA',
		qa.qa_guid,
		qa.qa_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'VICTIM',
		victim.victim_guid,
		victim.victim_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location.location_guid,
		location.location_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'PLACE',
		place.place_guid,
		place.place_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by place.place_guid, place.place_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		victim_assistance.guid,
		victim_assistance.localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by task.guid, task.localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue != 'Polygon' and ime01.enumvalue != 'Polyline'
	group by organisation.org_guid, organisation.org_localid, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate pointlocal_id in Polygon section
-------------------------------

drop view if exists public.geocheck_duplicate_polygon_point_localid CASCADE; 
create or replace view public.geocheck_duplicate_polygon_point_localid as

	(select
		'HAZARD',
		hazard.hazard_guid,
		hazard.hazard_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'HAZARD REDUCTION',
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'ACCIDENT',
		accident.accident_guid,
		accident.accident_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'MRE',
		mre.mre_guid,
		mre.mre_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'QA',
		qa.qa_guid,
		qa.qa_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'VICTIM',
		victim.victim_guid,
		victim.victim_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location.location_guid,
		location.location_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'PLACE',
		place.place_guid,
		place.place_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by place.place_guid, place.place_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		victim_assistance.guid,
		victim_assistance.localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by task.guid, task.localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by organisation.org_guid, organisation.org_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate pointlocal_id in Polygon (distance and bearing only) section
-------------------------------

drop view if exists public.geocheck_duplicate_polygon_point_localid_dist_and_bear CASCADE; 
create or replace view public.geocheck_duplicate_polygon_point_localid_dist_and_bear as

	(select
		'HAZARD',
		hazard.hazard_guid,
		hazard.hazard_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by hazard.hazard_guid, hazard.hazard_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION',
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT',
		accident.accident_guid,
		accident.accident_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by accident.accident_guid, accident.accident_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE',
		mre.mre_guid,
		mre.mre_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by mre.mre_guid, mre.mre_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA',
		qa.qa_guid,
		qa.qa_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by qa.qa_guid, qa.qa_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM',
		victim.victim_guid,
		victim.victim_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by victim.victim_guid, victim.victim_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location.location_guid,
		location.location_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by location.location_guid, location.location_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'PLACE',
		place.place_guid,
		place.place_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by place.place_guid, place.place_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		victim_assistance.guid,
		victim_assistance.localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by victim_assistance.guid, victim_assistance.localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by task.guid, task.localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		geospatialinfo.shape_id,
		geopoint.pointlocal_id,
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by organisation.org_guid, organisation.org_localid, geospatialinfo.shape_id, geopoint.pointlocal_id, ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;
	
-------------------------------
-- Begin duplicate pointlocal_id in Polygon trimmed section
-------------------------------

drop view if exists public.geocheck_duplicate_polygon_point_localid_trimmed CASCADE; 
create or replace view public.geocheck_duplicate_polygon_point_localid_trimmed as

	(select
		'HAZARD',
		hazard.hazard_guid,
		hazard.hazard_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'HAZARD REDUCTION',
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'ACCIDENT',
		accident.accident_guid,
		accident.accident_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'MRE',
		mre.mre_guid,
		mre.mre_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'QA',
		qa.qa_guid,
		qa.qa_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'VICTIM',
		victim.victim_guid,
		victim.victim_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location.location_guid,
		location.location_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
		'PLACE',
		place.place_guid,
		place.place_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by place.place_guid, place.place_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		victim_assistance.guid,
		victim_assistance.localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
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
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by task.guid, task.localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline'
	group by organisation.org_guid, organisation.org_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;

-------------------------------
-- Begin duplicate pointlocal_id in Polygon (distance and bearing only) trimmed section
-------------------------------

drop view if exists public.geocheck_duplicate_polygon_point_localid_dist_and_bear_trimmed CASCADE; 
create or replace view public.geocheck_duplicate_polygon_point_localid_dist_and_bear_trimmed as

	(select
		'HAZARD',
		hazard.hazard_guid,
		hazard.hazard_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazard_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazard_has_geospatialinfo.geospatialinfo_guid
		inner join hazard on hazard_has_geospatialinfo.hazard_guid = hazard.hazard_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by hazard.hazard_guid, hazard.hazard_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION',
		hazreduc.hazreduc_guid,
		hazreduc.hazreduc_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join hazreduc_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = hazreduc_has_geospatialinfo.geospatialinfo_guid
		inner join hazreduc on hazreduc_has_geospatialinfo.hazreduc_guid = hazreduc.hazreduc_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by hazreduc.hazreduc_guid, hazreduc.hazreduc_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT',
		accident.accident_guid,
		accident.accident_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join accident_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = accident_has_geospatialinfo.geospatialinfo_guid
		inner join accident on accident_has_geospatialinfo.accident_guid = accident.accident_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by accident.accident_guid, accident.accident_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE',
		mre.mre_guid,
		mre.mre_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join mre_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = mre_has_geospatialinfo.geospatialinfo_guid
		inner join mre on mre_has_geospatialinfo.mre_guid = mre.mre_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by mre.mre_guid, mre.mre_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'QA',
		qa.qa_guid,
		qa.qa_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join qa_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = qa_has_geospatialinfo.geospatialinfo_guid
		inner join qa on qa_has_geospatialinfo.qa_guid = qa.qa_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by qa.qa_guid, qa.qa_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM',
		victim.victim_guid,
		victim.victim_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_has_geospatialinfo.geospatialinfo_guid
		inner join victim on victim_has_geospatialinfo.victim_guid = victim.victim_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by victim.victim_guid, victim.victim_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'GAZETTEER',
		gazetteer.gazetteer_guid,
		gazetteer.gazetteer_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join gazetteer_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = gazetteer_has_geospatialinfo.geospatialinfo_guid
		inner join gazetteer on gazetteer_has_geospatialinfo.gazetteer_guid = gazetteer.gazetteer_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by gazetteer.gazetteer_guid, gazetteer.gazetteer_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location.location_guid,
		location.location_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join location_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = location_has_geospatialinfo.geospatialinfo_guid
		inner join location on location_has_geospatialinfo.location_guid = location.location_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by location.location_guid, location.location_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'PLACE',
		place.place_guid,
		place.place_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join place_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = place_has_geospatialinfo.geospatialinfo_guid
		inner join place on place_has_geospatialinfo.place_guid = place.place_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by place.place_guid, place.place_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		victim_assistance.guid,
		victim_assistance.localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join victim_assistance_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = victim_assistance_has_geospatialinfo.geospatialinfo_guid
		inner join victim_assistance on victim_assistance_has_geospatialinfo.victim_assistance_guid = victim_assistance.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by victim_assistance.guid, victim_assistance.localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'TASK',
		task.guid,
		task.localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join task_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = task_has_geospatialinfo.geospatialinfo_guid
		inner join task on task_has_geospatialinfo.task_guid = task.guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by task.guid, task.localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		organisation.org_guid,
		organisation.org_localid,
		geospatialinfo.shape_id,
		trim(geopoint.pointlocal_id),
		ime02.enumvalue as pointtypeenum, -- geopoint.pointtypeenum_guid
		count(*)
	from geopoint
		inner join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
		inner join organisation_has_geospatialinfo on geospatialinfo.geospatialinfo_guid = organisation_has_geospatialinfo.geospatialinfo_guid
		inner join organisation on organisation_has_geospatialinfo.org_guid = organisation.org_guid
		left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
		left join imsmaenum ime02 on ime02.imsmaenum_guid = geopoint.pointtypeenum_guid
	where (ime01.enumvalue = 'Polygon' or ime01.enumvalue = 'Polyline') and geopoint.userinputformat = 'Bearing and Distance'
	group by organisation.org_guid, organisation.org_localid, geospatialinfo.shape_id, trim(geopoint.pointlocal_id), ime02.enumvalue
	having count(*) > 1
	order by 3)
	order by 1,3;
	
	
-------------------------------
-- Begin duplicate polygon section
-------------------------------

drop view if exists public.geocheck_duplicate_polygons CASCADE; 
create or replace view public.geocheck_duplicate_polygons as

	(select
		'HAZARD',
		hazard_guid,
		hazard_localid,
		shape,
		count(*)
	from geocheck_hazard_geo_polys
	group by hazard_guid, hazard_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION',
		hazreduc_guid,
		hazreduc_localid,
		shape,
		count(*)
	from geocheck_hazreduc_geo_polys
	group by hazreduc_guid, hazreduc_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT',
		accident_guid,
		accident_localid,
		shape,
		count(*)
	from geocheck_accident_geo_polys
	group by accident_guid, accident_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE',
		mre_guid,
		mre_localid,
		shape,
		count(*)
	from geocheck_mre_geo_polys
	group by mre_guid, mre_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'QA',
		qa_guid,
		qa_localid,
		shape,
		count(*)
	from geocheck_qa_geo_polys
	group by qa_guid, qa_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM',
		victim_guid,
		victim_localid,
		shape,
		count(*)
	from geocheck_victim_geo_polys
	group by victim_guid, victim_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'GAZETTEER',
		gazetteer_guid,
		gazetteer_localid,
		shape,
		count(*)
	from geocheck_gazetteer_geo_polys
	group by gazetteer_guid, gazetteer_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location_guid,
		location_localid,
		shape,
		count(*)
	from geocheck_location_geo_polys
	group by location_guid, location_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'PLACE',
		place_guid,
		place_localid,
		shape,
		count(*)
	from geocheck_place_geo_polys
	group by place_guid, place_localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		guid,
		localid,
		shape,
		count(*)
	from geocheck_victim_assistance_geo_polys
	group by guid, localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'TASK',
		guid,
		localid,
		shape,
		count(*)
	from geocheck_task_geo_polys
	group by guid, localid, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		org_guid,
		org_localid,
		shape,
		count(*)
	from geocheck_organisation_geo_polys
	group by org_guid, org_localid, shape
	having count(*) > 1
	order by 3)
	order by 1, 3;
	
-------------------------------
-- Begin duplicate points in polygon section
-------------------------------

drop view if exists public.geocheck_duplicate_points_in_polygons CASCADE; 
create or replace view public.geocheck_duplicate_points_in_polygons as
	(select
		'HAZARD',
		hazard_guid,
		hazard_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_hazard_geo_pts
	group by hazard_guid, hazard_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'HAZARD REDUCTION',
		hazreduc_guid,
		hazreduc_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_hazreduc_geo_polys
	group by hazreduc_guid, hazreduc_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'ACCIDENT',
		accident_guid,
		accident_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_accident_geo_polys
	group by accident_guid, accident_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'MRE',
		mre_guid,
		mre_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_mre_geo_polys
	group by mre_guid, mre_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'QA',
		qa_guid,
		qa_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_qa_geo_polys
	group by qa_guid, qa_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM',
		victim_guid,
		victim_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_victim_geo_polys
	group by victim_guid, victim_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'GAZETTEER',
		gazetteer_guid,
		gazetteer_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_gazetteer_geo_polys
	group by gazetteer_guid, gazetteer_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'LOCATION',
		location_guid,
		location_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_location_geo_polys
	group by location_guid, location_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'PLACE',
		place_guid,
		place_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_place_geo_polys
	group by place_guid, place_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'VICTIM ASSISTANCE',
		guid,
		localid,
		shape_id,
		shape,
		count(*)
	from geocheck_victim_assistance_geo_polys
	group by guid, localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'TASK',
		guid,
		localid,
		shape_id,
		shape,
		count(*)
	from geocheck_task_geo_polys
	group by guid, localid, shape_id, shape
	having count(*) > 1
	order by 3)
	union
	(select
		'ORGANISATION',
		org_guid,
		org_localid,
		shape_id,
		shape,
		count(*)
	from geocheck_organisation_geo_polys
	group by org_guid, org_localid, shape_id, shape
	having count(*) > 1
	order by 3)
	order by 1, 3;