# geocheck views

The SQL script geocheck.sql create views in the public schema of IMSMAng that help check the quality of geographical information for your IMSMAng database. The script is meant to be run on a IMSMAng V6 installation.

To create the views just copy the script in a query window in pgAdmin III or Navicat and run it.

The check looks at a variety of possible issues:
  - invalid polygons (IMSMAng does not check if a polygon created by a set of points is valid)
  - polygosn with too many vertices (less than 3)
  - duplicate information (polygon, point, point or polygon id)
  - distance between points in a polygon

Views available and description:

|View Name| Type | Description|
| --- | --- | --- |
| geocheck_**!TYPE!**_geo_invalid_polys | Geo Check | List of invalid polygons |
| geocheck_**!TYPE!**_geo_few_vertices | Geo Check | List of polygons defined with less than 3 vertices|
| geocheck_**!TYPE!**_geo_valid_multipart_polys | Information| List of multi polygon records|
| geocheck_distance_polygon_points | Geo Check | List of polygons defined with a distance between 2 consecutive points higher than the value defined in the query (default is 5000 m) | 
| geocheck_duplicate_point_point_localid | Geo Check | List of duplicate points based on localid |
| geocheck_duplicate_point_point_localid_trimmed | Geo Check | List of duplicate points based on trimmed localid |
| geocheck_duplicate_points_in_polygons | Geo Check | List of of duplicate points based on coordinates in a polygon|
| geocheck_duplicate_polygon_point_localid | Geo Check | List of duplicate points based on localid in a polygon
| geocheck_duplicate_polygon_point_localid_trimmed | Geo Check | List of duplicate points based on trimmed localid in a polygon|
| geocheck_duplicate_polygon_polyid | Geo Check | List of duplicate polygons based on shape id in a record |
| geocheck_duplicate_polygon_polyid_trimmed | Geo Check | List of duplicate polygons based on trimmed shapeid in a record |
| geocheck_duplicate_polygons | Geo Check | List of duplicate polygons based on coordinates in a record |
| geocheck_zint_**!TYPE!**_geo_polys | Intermediary | List of polygons created from IMSMAng points |
| geocheck_zint_**!TYPE!**_geo_pts | Intermediary | List of points from IMSMAng |
| geocheck_zint_**!TYPE!**_geo_valid_polys | Intermediary | List of valid polygons |
  
**!TYPE!** can be accident, gazetteer, hazard, hazreduc, location, mre, organisation, place, qa, task, victim_assistance, victim.

This section provide detail information for each view type

geocheck_**!TYPE!**_geo_invalid_polys:
------------------------------------
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng guid |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| wkt | WKT LINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| st_isvalidreason | Reason why the polygon is invalid |
| st_summary | Polygon description |

geocheck_**!TYPE!**_geo_few_vertices:
------------------------------------
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng guid |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| pointcount | Number of vertices |

geocheck_**!TYPE!**_geo_valid_multipart_polys:
------------------------------------

| Field | Description|
| --- | --- |
| **!TYPE!**_localid | IMSMAng localid |
| st_collect | Postgis geometry |
| wkt | WKT LINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| st_summary | Polygon description |

