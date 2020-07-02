-- RECORDS

-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
	select split_part(guids,'|',1) from
		(
		-- To get list, run query below
		select * from geocheck_duplicate_polygon_points 
		where split_part(dup_point_numbers,'|',1) :: integer - split_part(dup_point_numbers,'|',2) :: integer = 1
		) t
	);
	
-- INFOVERSIONS

-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
	select split_part(guids,'|',1) from
		(
		-- To get list, run query below
		select * from geocheck_infoversion_duplicate_polygon_points 
		where split_part(dup_point_numbers,'|',1) :: integer - split_part(dup_point_numbers,'|',2) :: integer = 1
		) t
	);