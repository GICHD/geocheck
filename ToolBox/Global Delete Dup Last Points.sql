-- delete from geopoint 	-- uncommment this line for delete, comment this line for listing
select * from geopoint 		-- comment this line for delete, uncommment this line for listing
where geopoint_guid in (
	select geopoint_guid
		from (
			with min_point_values as(
				with min_point as(
					select
						geopoint.geospatialinfo_guid as geosp_min,
						min(geopoint.pointno) as min_point
					from geopoint
					left join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
					left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
					where ime01.enumvalue = 'Polygon'
					group by geopoint.geospatialinfo_guid) 
				select 
					*
				from geopoint
				inner join min_point on geopoint.geospatialinfo_guid = min_point.geosp_min and geopoint.pointno = min_point.min_point)
				,
			max_point as (
					select
					geopoint.geospatialinfo_guid as geosp_max,
					max(geopoint.pointno) as max_point
				from geopoint
				left join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
				left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
				where ime01.enumvalue = 'Polygon'
				group by geopoint.geospatialinfo_guid
				)
			select
				max_point.max_point,
				geopoint.geopoint_guid,
				geopoint.pointno,
				geopoint.latitude,
				geopoint.longitude,
				min_point_values.pointno,
				min_point_values.latitude,
				min_point_values.longitude,
				abs(geopoint.latitude - min_point_values.latitude),
				abs(geopoint.longitude - min_point_values.longitude)
			from geopoint
			left join geospatialinfo on geopoint.geospatialinfo_guid = geospatialinfo.geospatialinfo_guid
			left join imsmaenum ime01 on ime01.imsmaenum_guid = geospatialinfo.shapeenum_guid
			left join min_point_values on geopoint.geospatialinfo_guid = min_point_values.geosp_min
			left join max_point on geopoint.geospatialinfo_guid = max_point.geosp_max
			where ime01.enumvalue = 'Polygon' and geopoint.pointno != min_point_values.pointno
				and abs(geopoint.latitude - min_point_values.latitude) < 0.000001
				and abs(geopoint.longitude - min_point_values.longitude) < 0.000001
				and max_point.max_point = geopoint.pointno
			) as dup_start_end_points
	);