---- Delete duplicate single points with same types (1 against 2)

-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
	select split_part(guids,'|',1) from
		(
		-- To get list, run query below
		select * from geocheck_duplicate_points 
		where split_part(pointtypes,'|',1) = split_part(pointtypes,'|',2)
		) t
	);

---- Delete duplicate single points with same types (2 against 3)

-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
	select split_part(guids,'|',2) from
		(
		-- To get list, run query below
		select * from geocheck_duplicate_points 
		where (char_length(pointtypes) - char_length(replace(pointtypes,'|','')) = 2) and (split_part(pointtypes,'|',2) = split_part(pointtypes,'|',3))
		) t
	);

---- Delete duplicate single points with same types (3 against 4)

-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
	select split_part(guids,'|',3) from
		(
		-- To get list, run query below
		select * from geocheck_duplicate_points 
		where (char_length(pointtypes) - char_length(replace(pointtypes,'|','')) = 3) and (split_part(pointtypes,'|',3) = split_part(pointtypes,'|',4))
		) t
	);