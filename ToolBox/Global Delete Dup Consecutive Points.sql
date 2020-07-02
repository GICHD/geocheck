---- Delete duplicate consecutive points
delete from geopoint 
	where geopoint_guid in (
	select split_part(guids,'|',1) from
		(
		-- To get list, run query below
		select * from geocheck_duplicate_polygon_points 
		where split_part(dup_point_numbers,'|',1) :: integer - split_part(dup_point_numbers,'|',2) :: integer = 1
		) t
	);
	
---- Delete duplicate consecutive points (infoversion)
delete from geopoint 
	where geopoint_guid in (
	select split_part(guids,'|',1) from
		(
		-- To get list, run query below
		select * from geocheck_infoversion_duplicate_polygon_points 
		where split_part(dup_point_numbers,'|',1) :: integer - split_part(dup_point_numbers,'|',2) :: integer = 1
		) t
	);