--Create a 'polycheck' schema if it does not exist already. This schema will be used to perform the analysis of the polygons and
-- to keep things separate from imsma data

-- this line should be commented out if the schema already exists, or it will fail on PostgreSQL 9.1
drop schema if exists polycheck cascade;
create schema polycheck;

-------------------------------
-- Begin hazard section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists polycheck.hazard_geo_pts CASCADE; 
create or replace view polycheck.hazard_geo_pts as

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
drop view if exists polycheck.hazard_geo_polys CASCADE;
create or replace view polycheck.hazard_geo_polys as
select hazard_guid, hazard_localid,
	ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
	count(*) as pointcount
		from (select hazard_guid, hazard_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.hazard_geo_pts where shapeenum = 'Polygon' 
			order by hazard_guid, hazard_localid, geospatialinfo_guid, pointno)
				as values 
					group by hazard_guid, hazard_localid, geospatialinfo_guid having count(*) > 2
						order by hazard_guid;
						
-- create view to list only low-vertex polygons
drop view if exists polycheck.hazard_geo_polys_few_vertices CASCADE;
create or replace view polycheck.hazard_geo_polys_few_vertices as
select hazard_guid, hazard_localid,
	count(*) as pointcount
		from (select hazard_guid, hazard_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.hazard_geo_pts where shapeenum = 'Polygon' 
			order by hazard_guid, hazard_localid, geospatialinfo_guid, pointno)
				as values 
					group by hazard_guid, hazard_localid, geospatialinfo_guid having count(*) < 3
						order by hazard_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists polycheck.hazard_geo_valid_polys CASCADE;
create view polycheck.hazard_geo_valid_polys as
	select hazard_guid, hazard_localid, shape, st_asewkt(st_exteriorring(shape)), st_summary(shape) from polycheck.hazard_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists polycheck.hazard_geo_invalid_polys CASCADE;
create view polycheck.hazard_geo_invalid_polys as
	select hazard_guid, hazard_localid, shape, st_asewkt(st_exteriorring(shape)), st_isvalidreason(shape), st_summary(shape) from polycheck.hazard_geo_polys where ST_IsValid(shape) = 'f';

	
-------------------------------
-- Begin hazreduc section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists polycheck.hazreduc_geo_pts CASCADE; 
create or replace view polycheck.hazreduc_geo_pts as

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
drop view if exists polycheck.hazreduc_geo_polys CASCADE;
create or replace view polycheck.hazreduc_geo_polys as
select hazreduc_guid, hazreduc_localid,
	ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
	count(*) as pointcount
		from (select hazreduc_guid, hazreduc_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.hazreduc_geo_pts where shapeenum = 'Polygon' 
			order by hazreduc_guid, hazreduc_localid, geospatialinfo_guid, pointno)
				as values 
					group by hazreduc_guid, hazreduc_localid, geospatialinfo_guid  having count(*) > 2
						order by hazreduc_guid;

-- create view to list only low-vertex polygons
drop view if exists polycheck.hazreduc_geo_polys_few_vertices CASCADE;
create or replace view polycheck.hazreduc_geo_polys_few_vertices as
select hazreduc_guid, hazreduc_localid,
	count(*) as pointcount
		from (select hazreduc_guid, hazreduc_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.hazreduc_geo_pts where shapeenum = 'Polygon' 
			order by hazreduc_guid, hazreduc_localid, geospatialinfo_guid, pointno)
				as values 
					group by hazreduc_guid, hazreduc_localid, geospatialinfo_guid  having count(*) < 3
						order by hazreduc_guid;

-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists polycheck.hazreduc_geo_valid_polys CASCADE;
create view polycheck.hazreduc_geo_valid_polys as
	select hazreduc_guid, hazreduc_localid, shape, st_asewkt(st_exteriorring(shape)), st_summary(shape) from polycheck.hazreduc_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists polycheck.hazreduc_geo_invalid_polys CASCADE;
create view polycheck.hazreduc_geo_invalid_polys as
	select hazreduc_guid, hazreduc_localid, shape, st_asewkt(st_exteriorring(shape)), st_isvalidreason(shape), st_summary(shape) from polycheck.hazreduc_geo_polys where ST_IsValid(shape) = 'f';


-------------------------------
-- Begin accident section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists polycheck.accident_geo_pts CASCADE; 
create or replace view polycheck.accident_geo_pts as

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
drop view if exists polycheck.accident_geo_polys CASCADE;
create or replace view polycheck.accident_geo_polys as
select accident_guid, accident_localid,
	ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
	count(*) as pointcount
		from (select accident_guid, accident_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.accident_geo_pts where shapeenum = 'Polygon' 
			order by accident_guid, accident_localid, geospatialinfo_guid, pointno)
				as values 
					group by accident_guid, accident_localid, geospatialinfo_guid  having count(*) > 2
						order by accident_guid;

-- create view to list only low-vertex polygons
drop view if exists polycheck.accident_geo_polys_few_vertices CASCADE;
create or replace view polycheck.accident_geo_polys_few_vertices as
select accident_guid, accident_localid,
	count(*) as pointcount
		from (select accident_guid, accident_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.accident_geo_pts where shapeenum = 'Polygon' 
			order by accident_guid, accident_localid, geospatialinfo_guid, pointno)
				as values 
					group by accident_guid, accident_localid, geospatialinfo_guid  having count(*) < 3
						order by accident_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists polycheck.accident_geo_valid_polys CASCADE;
create view polycheck.accident_geo_valid_polys as
	select accident_guid, accident_localid, shape, st_asewkt(st_exteriorring(shape)), st_summary(shape) from polycheck.accident_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists polycheck.accident_geo_invalid_polys CASCADE;
create view polycheck.accident_geo_invalid_polys as
	select accident_guid, accident_localid, shape, st_asewkt(st_exteriorring(shape)), st_isvalidreason(shape), st_summary(shape) from polycheck.accident_geo_polys where ST_IsValid(shape) = 'f';
	

-------------------------------
-- Begin mre section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists polycheck.mre_geo_pts CASCADE; 
create or replace view polycheck.mre_geo_pts as

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
drop view if exists polycheck.mre_geo_polys CASCADE;
create or replace view polycheck.mre_geo_polys as
select mre_guid, mre_localid,
	ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
	count(*) as pointcount
		from (select mre_guid, mre_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.mre_geo_pts where shapeenum = 'Polygon' 
			order by mre_guid, mre_localid, geospatialinfo_guid, pointno)
				as values 
					group by mre_guid, mre_localid, geospatialinfo_guid  having count(*) > 2
						order by mre_guid;

-- create view to list only low-vertex polygons
drop view if exists polycheck.mre_geo_polys_few_vertices CASCADE;
create or replace view polycheck.mre_geo_polys_few_vertices as
select mre_guid, mre_localid,
	count(*) as pointcount
		from (select mre_guid, mre_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.mre_geo_pts where shapeenum = 'Polygon' 
			order by mre_guid, mre_localid, geospatialinfo_guid, pointno)
				as values 
					group by mre_guid, mre_localid, geospatialinfo_guid  having count(*) < 3
						order by mre_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists polycheck.mre_geo_valid_polys CASCADE;
create view polycheck.mre_geo_valid_polys as
	select mre_guid, mre_localid, shape, st_asewkt(st_exteriorring(shape)), st_summary(shape) from polycheck.mre_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists polycheck.mre_geo_invalid_polys CASCADE;
create view polycheck.mre_geo_invalid_polys as
	select mre_guid, mre_localid, shape, st_asewkt(st_exteriorring(shape)), st_isvalidreason(shape), st_summary(shape) from polycheck.mre_geo_polys where ST_IsValid(shape) = 'f';
	
-------------------------------
-- Begin qa section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists polycheck.qa_geo_pts CASCADE; 
create or replace view polycheck.qa_geo_pts as

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
drop view if exists polycheck.qa_geo_polys CASCADE;
create or replace view polycheck.qa_geo_polys as
select qa_guid, qa_localid,
	ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
	count(*) as pointcount
		from (select qa_guid, qa_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.qa_geo_pts where shapeenum = 'Polygon' 
			order by qa_guid, qa_localid, geospatialinfo_guid, pointno)
				as values 
					group by qa_guid, qa_localid, geospatialinfo_guid  having count(*) > 2
						order by qa_guid;

-- create view to list only low-vertex polygons
drop view if exists polycheck.qa_geo_polys_few_vertices CASCADE;
create or replace view polycheck.qa_geo_polys_few_vertices as
select qa_guid, qa_localid,
	count(*) as pointcount
		from (select qa_guid, qa_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.qa_geo_pts where shapeenum = 'Polygon' 
			order by qa_guid, qa_localid, geospatialinfo_guid, pointno)
				as values 
					group by qa_guid, qa_localid, geospatialinfo_guid  having count(*) < 3
						order by qa_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists polycheck.qa_geo_valid_polys CASCADE;
create view polycheck.qa_geo_valid_polys as
	select qa_guid, qa_localid, shape, st_asewkt(st_exteriorring(shape)), st_summary(shape) from polycheck.qa_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists polycheck.qa_geo_invalid_polys CASCADE;
create view polycheck.qa_geo_invalid_polys as
	select qa_guid, qa_localid, shape, st_asewkt(st_exteriorring(shape)), st_isvalidreason(shape), st_summary(shape) from polycheck.qa_geo_polys where ST_IsValid(shape) = 'f';
	
-------------------------------
-- Begin victim section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists polycheck.victim_geo_pts CASCADE; 
create or replace view polycheck.victim_geo_pts as

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
drop view if exists polycheck.victim_geo_polys CASCADE;
create or replace view polycheck.victim_geo_polys as
select victim_guid, victim_localid,
	ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
	count(*) as pointcount
		from (select victim_guid, victim_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.victim_geo_pts where shapeenum = 'Polygon' 
			order by victim_guid, victim_localid, geospatialinfo_guid, pointno)
				as values 
					group by victim_guid, victim_localid, geospatialinfo_guid  having count(*) > 2
						order by victim_guid;

-- create view to list only low-vertex polygons
drop view if exists polycheck.victim_geo_polys_few_vertices CASCADE;
create or replace view polycheck.victim_geo_polys_few_vertices as
select victim_guid, victim_localid,
	count(*) as pointcount
		from (select victim_guid, victim_localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.victim_geo_pts where shapeenum = 'Polygon' 
			order by victim_guid, victim_localid, geospatialinfo_guid, pointno)
				as values 
					group by victim_guid, victim_localid, geospatialinfo_guid  having count(*) < 3
						order by victim_guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists polycheck.victim_geo_valid_polys CASCADE;
create view polycheck.victim_geo_valid_polys as
	select victim_guid, victim_localid, shape, st_asewkt(st_exteriorring(shape)), st_summary(shape) from polycheck.victim_geo_polys where ST_IsValid(shape) = 't';

-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists polycheck.victim_geo_invalid_polys CASCADE;
create view polycheck.victim_geo_invalid_polys as
	select victim_guid, victim_localid, shape, st_asewkt(st_exteriorring(shape)), st_isvalidreason(shape), st_summary(shape) from polycheck.victim_geo_polys where ST_IsValid(shape) = 'f';
	
	
-------------------------------
-- Begin victim_assistance section
-------------------------------

-- Create a view that extracts all required info for geopoints into one table

drop view if exists polycheck.victim_assistance_geo_pts CASCADE; 
create or replace view polycheck.victim_assistance_geo_pts as

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
drop view if exists polycheck.victim_assistance_geo_polys CASCADE;
create or replace view polycheck.victim_assistance_geo_polys as
select guid, localid,
	ST_MakePolygon(ST_AddPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'), 4326), 
		ST_StartPoint(ST_GeomFromText(concat('LINESTRING(', string_agg(concat(longitude::varchar, ' ', latitude::varchar),','),')'))))) as shape,
	count(*) as pointcount
		from (select guid, localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.victim_assistance_geo_pts where shapeenum = 'Polygon' 
			order by guid, localid, geospatialinfo_guid, pointno)
				as values 
					group by guid, localid, geospatialinfo_guid  having count(*) > 2
						order by guid;

-- create view to list only low-vertex polygons
drop view if exists polycheck.victim_assistance_geo_polys_few_vertices CASCADE;
create or replace view polycheck.victim_assistance_geo_polys_few_vertices as
select guid, localid,
	count(*) as pointcount
		from (select guid, localid, geospatialinfo_guid, pointno, longitude, latitude from polycheck.victim_assistance_geo_pts where shapeenum = 'Polygon' 
			order by guid, localid, geospatialinfo_guid, pointno)
				as values 
					group by guid, localid, geospatialinfo_guid  having count(*) < 3
						order by guid;
						
-- Create a subsidiary view of all valid polygons within that view (extracts valid polygons only)
drop view if exists polycheck.victim_assistance_geo_valid_polys CASCADE;
create view polycheck.victim_assistance_geo_valid_polys as
	select guid, localid, shape, st_asewkt(st_exteriorring(shape)), st_summary(shape) from polycheck.victim_assistance_geo_polys where ST_IsValid(shape) = 't';


-- Create a subsidiary view of all Invalid polygons within that view (extracts invalid polygons)
drop view if exists polycheck.victim_assistance_geo_invalid_polys CASCADE;
create view polycheck.victim_assistance_geo_invalid_polys as
	select guid, localid, shape, st_asewkt(st_exteriorring(shape)), st_isvalidreason(shape), st_summary(shape) from polycheck.victim_assistance_geo_polys where ST_IsValid(shape) = 'f';
	
