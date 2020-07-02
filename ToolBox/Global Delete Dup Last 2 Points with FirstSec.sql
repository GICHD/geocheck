-------------
-- Hazard ---
-------------

-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
(select distinct onebutlast_point_guid
from (

with first_point_values as(
with first_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join first_point on migration.hazard_geo_pts.geospatialinfo_guid = first_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = first_point.pointno)
			,
second_point_values as(
with second_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join second_point on migration.hazard_geo_pts.geospatialinfo_guid = second_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = second_point.pointno)
			,
last_point_values as(
with last_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join last_point on migration.hazard_geo_pts.geospatialinfo_guid = last_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = last_point.pointno)
			,
onebutlast_point_values as(
with onebutlast_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join onebutlast_point on migration.hazard_geo_pts.geospatialinfo_guid = onebutlast_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = onebutlast_point.pointno)			
			
			select
			hazard_geo_pts.hazard_localid,
			migration.hazard_geo_pts.shape_id,
			first_point_values.pointno as first_point_pointno,
			first_point_values.latitude as first_point_latitude,
			first_point_values.longitude as first_point_longitude,
			first_point_values.geopoint_guid as first_point_guid,
			onebutlast_point_values.pointno as onebutlast_point_pointno,
			onebutlast_point_values.latitude as onebutlast_point_latitude,
			onebutlast_point_values.longitude as onebutlast_point_longitude,
			onebutlast_point_values.geopoint_guid as onebutlast_point_guid,
			second_point_values.pointno as second_point_pointno,
			second_point_values.latitude as second_point_latitude,
			second_point_values.longitude as second_point_longitude,
			second_point_values.geopoint_guid as second_point_guid,
			last_point_values.pointno as last_point_pointno,
			last_point_values.latitude as last_point_latitude,
			last_point_values.longitude as last_point_longitude,
			last_point_values.geopoint_guid as last_point_guid
		from migration.hazard_geo_pts
		left join first_point_values on migration.hazard_geo_pts.geospatialinfo_guid = first_point_values.geospatialinfo_guid
		left join onebutlast_point_values on migration.hazard_geo_pts.geospatialinfo_guid = onebutlast_point_values.geospatialinfo_guid
		left join second_point_values on migration.hazard_geo_pts.geospatialinfo_guid = second_point_values.geospatialinfo_guid
		left join last_point_values on migration.hazard_geo_pts.geospatialinfo_guid = last_point_values.geospatialinfo_guid
		where migration.hazard_geo_pts.shapeenum = 'Polygon' 
		and (abs(first_point_values.latitude - onebutlast_point_values.latitude) < 0.0000001
			and abs(first_point_values.longitude - onebutlast_point_values.longitude) < 0.0000001)
		and (abs(second_point_values.latitude - last_point_values.latitude) < 0.0000001
			and abs(second_point_values.longitude - last_point_values.longitude) < 0.0000001)
) t2)
union
(select distinct last_point_guid
from (

with first_point_values as(
with first_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join first_point on migration.hazard_geo_pts.geospatialinfo_guid = first_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = first_point.pointno)
			,
second_point_values as(
with second_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join second_point on migration.hazard_geo_pts.geospatialinfo_guid = second_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = second_point.pointno)
			,
last_point_values as(
with last_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join last_point on migration.hazard_geo_pts.geospatialinfo_guid = last_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = last_point.pointno)
			,
onebutlast_point_values as(
with onebutlast_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazard_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazard_geo_pts.*
			from migration.hazard_geo_pts
			inner join onebutlast_point on migration.hazard_geo_pts.geospatialinfo_guid = onebutlast_point.geospatialinfo_guid and migration.hazard_geo_pts.pointno = onebutlast_point.pointno)			
			
			select
			hazard_geo_pts.hazard_localid,
			migration.hazard_geo_pts.shape_id,
			first_point_values.pointno as first_point_pointno,
			first_point_values.latitude as first_point_latitude,
			first_point_values.longitude as first_point_longitude,
			first_point_values.geopoint_guid as first_point_guid,
			onebutlast_point_values.pointno as onebutlast_point_pointno,
			onebutlast_point_values.latitude as onebutlast_point_latitude,
			onebutlast_point_values.longitude as onebutlast_point_longitude,
			onebutlast_point_values.geopoint_guid as onebutlast_point_guid,
			second_point_values.pointno as second_point_pointno,
			second_point_values.latitude as second_point_latitude,
			second_point_values.longitude as second_point_longitude,
			second_point_values.geopoint_guid as second_point_guid,
			last_point_values.pointno as last_point_pointno,
			last_point_values.latitude as last_point_latitude,
			last_point_values.longitude as last_point_longitude,
			last_point_values.geopoint_guid as last_point_guid
		from migration.hazard_geo_pts
		left join first_point_values on migration.hazard_geo_pts.geospatialinfo_guid = first_point_values.geospatialinfo_guid
		left join onebutlast_point_values on migration.hazard_geo_pts.geospatialinfo_guid = onebutlast_point_values.geospatialinfo_guid
		left join second_point_values on migration.hazard_geo_pts.geospatialinfo_guid = second_point_values.geospatialinfo_guid
		left join last_point_values on migration.hazard_geo_pts.geospatialinfo_guid = last_point_values.geospatialinfo_guid
		where migration.hazard_geo_pts.shapeenum = 'Polygon' 
		and (abs(first_point_values.latitude - onebutlast_point_values.latitude) < 0.0000001
			and abs(first_point_values.longitude - onebutlast_point_values.longitude) < 0.0000001)
		and (abs(second_point_values.latitude - last_point_values.latitude) < 0.0000001
			and abs(second_point_values.longitude - last_point_values.longitude) < 0.0000001)
) t2)
);

----------------------
-- Hazard Reduction---
----------------------

-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
(select distinct onebutlast_point_guid
from (

with first_point_values as(
with first_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join first_point on migration.hazreduc_geo_pts.geospatialinfo_guid = first_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = first_point.pointno)
			,
second_point_values as(
with second_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join second_point on migration.hazreduc_geo_pts.geospatialinfo_guid = second_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = second_point.pointno)
			,
last_point_values as(
with last_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join last_point on migration.hazreduc_geo_pts.geospatialinfo_guid = last_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = last_point.pointno)
			,
onebutlast_point_values as(
with onebutlast_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join onebutlast_point on migration.hazreduc_geo_pts.geospatialinfo_guid = onebutlast_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = onebutlast_point.pointno)			
			
			select
			hazreduc_geo_pts.hazreduc_localid,
			migration.hazreduc_geo_pts.shape_id,
			first_point_values.pointno as first_point_pointno,
			first_point_values.latitude as first_point_latitude,
			first_point_values.longitude as first_point_longitude,
			first_point_values.geopoint_guid as first_point_guid,
			onebutlast_point_values.pointno as onebutlast_point_pointno,
			onebutlast_point_values.latitude as onebutlast_point_latitude,
			onebutlast_point_values.longitude as onebutlast_point_longitude,
			onebutlast_point_values.geopoint_guid as onebutlast_point_guid,
			second_point_values.pointno as second_point_pointno,
			second_point_values.latitude as second_point_latitude,
			second_point_values.longitude as second_point_longitude,
			second_point_values.geopoint_guid as second_point_guid,
			last_point_values.pointno as last_point_pointno,
			last_point_values.latitude as last_point_latitude,
			last_point_values.longitude as last_point_longitude,
			last_point_values.geopoint_guid as last_point_guid
		from migration.hazreduc_geo_pts
		left join first_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = first_point_values.geospatialinfo_guid
		left join onebutlast_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = onebutlast_point_values.geospatialinfo_guid
		left join second_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = second_point_values.geospatialinfo_guid
		left join last_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = last_point_values.geospatialinfo_guid
		where migration.hazreduc_geo_pts.shapeenum = 'Polygon' 
		and (abs(first_point_values.latitude - onebutlast_point_values.latitude) < 0.0000001
			and abs(first_point_values.longitude - onebutlast_point_values.longitude) < 0.0000001)
		and (abs(second_point_values.latitude - last_point_values.latitude) < 0.0000001
			and abs(second_point_values.longitude - last_point_values.longitude) < 0.0000001)
) t2)
union
(select distinct last_point_guid
from (

with first_point_values as(
with first_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join first_point on migration.hazreduc_geo_pts.geospatialinfo_guid = first_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = first_point.pointno)
			,
second_point_values as(
with second_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno asc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join second_point on migration.hazreduc_geo_pts.geospatialinfo_guid = second_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = second_point.pointno)
			,
last_point_values as(
with last_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 1)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join last_point on migration.hazreduc_geo_pts.geospatialinfo_guid = last_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = last_point.pointno)
			,
onebutlast_point_values as(
with onebutlast_point as (
select geospatialinfo_guid, pointno from (
select
geospatialinfo_guid,
pointno, 
row_number() over (partition by geospatialinfo_guid order by pointno desc ) as rn
from migration.hazreduc_geo_pts
where shapeenum = 'Polygon') t
where rn = 2)
select 
				hazreduc_geo_pts.*
			from migration.hazreduc_geo_pts
			inner join onebutlast_point on migration.hazreduc_geo_pts.geospatialinfo_guid = onebutlast_point.geospatialinfo_guid and migration.hazreduc_geo_pts.pointno = onebutlast_point.pointno)			
			
			select
			hazreduc_geo_pts.hazreduc_localid,
			migration.hazreduc_geo_pts.shape_id,
			first_point_values.pointno as first_point_pointno,
			first_point_values.latitude as first_point_latitude,
			first_point_values.longitude as first_point_longitude,
			first_point_values.geopoint_guid as first_point_guid,
			onebutlast_point_values.pointno as onebutlast_point_pointno,
			onebutlast_point_values.latitude as onebutlast_point_latitude,
			onebutlast_point_values.longitude as onebutlast_point_longitude,
			onebutlast_point_values.geopoint_guid as onebutlast_point_guid,
			second_point_values.pointno as second_point_pointno,
			second_point_values.latitude as second_point_latitude,
			second_point_values.longitude as second_point_longitude,
			second_point_values.geopoint_guid as second_point_guid,
			last_point_values.pointno as last_point_pointno,
			last_point_values.latitude as last_point_latitude,
			last_point_values.longitude as last_point_longitude,
			last_point_values.geopoint_guid as last_point_guid
		from migration.hazreduc_geo_pts
		left join first_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = first_point_values.geospatialinfo_guid
		left join onebutlast_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = onebutlast_point_values.geospatialinfo_guid
		left join second_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = second_point_values.geospatialinfo_guid
		left join last_point_values on migration.hazreduc_geo_pts.geospatialinfo_guid = last_point_values.geospatialinfo_guid
		where migration.hazreduc_geo_pts.shapeenum = 'Polygon' 
		and (abs(first_point_values.latitude - onebutlast_point_values.latitude) < 0.0000001
			and abs(first_point_values.longitude - onebutlast_point_values.longitude) < 0.0000001)
		and (abs(second_point_values.latitude - last_point_values.latitude) < 0.0000001
			and abs(second_point_values.longitude - last_point_values.longitude) < 0.0000001)
) t2)
);
