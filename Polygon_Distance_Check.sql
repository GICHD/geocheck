-- This query calculates the distance between consecutive points in a Polygon
-- and returns the object type, the local id, the polygon id and the distance.
-- It is set to returns distances above 2000m (This value can be changed for each object type in the query).
--
-- HAZARD
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
order by 1, 2



