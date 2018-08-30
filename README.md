# geocheck views

The SQL script geocheck.sql create views in the public schema of IMSMAng that help check the quality of geographical information for your IMSMAng database. The script is meant to be run on a IMSMAng V6 installation.

To create the views just copy the script in a query window in pgAdmin III or Navicat and run it.

The check looks at a variety of possible issues:
  - invalid polygon (IMSMAng does not check if a polygon created by a set of points is valid)
  - polygon with too many vertices (less than 3)
  - duplicate information (polygon, point, point or polygon id)
  - distance between points in a polygon

Views available and description:

|View Name| Description|
| --- | --- |
| geocheck_**!TYPE!**_geo_invalid_polys | List of invalid polygons |
| geocheck_**!TYPE!**_geo_few_vertices | List of polygons defined with less than 3 vertices|
| geocheck_**!TYPE!**_geo_valid_multipart_polys | List of multi polygon records|
| geocheck_distance_polygon_points | List of polygons defined with a distance between 2 consecutive points higher than the value defined in the query (default is 5000 m) | 
| geocheck_duplicate_point_point_localid | List of duplicate points based on localid |
| geocheck_duplicate_point_point_localid_trimmed | List of duplicate points based on trimmed localid |
| geocheck_duplicate_points_in_polygons | List of of duplicate points based on coordinates in a polygon|
| geocheck_duplicate_polygon_point_localid | List of duplicate points based on localid in a polygon
| geocheck_duplicate_polygon_point_localid_trimmed | List of duplicate points based on trimmed localid in a polygon|
| geocheck_duplicate_polygon_polyid | List of duplicate polygons based on shape id in a record |
| geocheck_duplicate_polygon_polyid_trimmed | List of duplicate polygons based on trimmed shapeid in a record |
| geocheck_duplicate_polygons | List of duplicate polygons based on coordinates in a record |
| geocheck_
  
**!TYPE!** can be accident, gazetteer, hazard, hazreduc, location, mre, organisation, place, qa, task, victim_assistance, victim.

This section provide detail information for each view type

geocheck_**!TYPE!**_geo_invalid_polys:
  - 
