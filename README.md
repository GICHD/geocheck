# geocheck views

The SQL script geocheck.sql create views in the public schema of IMSMAng that help check the quality of geographical information for your IMSMAng database. The script is meant to be run on a IMSMAng V6 installation.

To create the views just copy the script in a query window in pgAdmin III or Navicat and run it.

The checks look at a variety of possible issues:
  - invalid polygons (IMSMAng does not check if a polygon created by a set of points is valid)
  - polygons with too many vertices (less than 3)
  - duplicate information (polygon, point, point or polygon id)
  - distance between points in a polygon

The SQL script drop_views.sql can be used to remove all views from IMSMAng.

## Views available
There are 2 types of views:
  - Geo Check: they provides identified issues that need to be looked at.
  - Information: they are used as intermediary views to generate the Geo Check views but can provide useful information

|View Name| Type | Description|
| --- | --- | --- |
| [geocheck_obj_**!TYPE!**_invalid_polys](#test) | Geo Check | List of invalid polygons |
| geocheck_obj_**!TYPE!**_few_vertices_polys | Geo Check | List of polygons defined with less than 3 vertices|
| geocheck_duplicate_polygons | Geo Check | List of duplicate polygons based on coordinates in a record |
| geocheck_duplicate_polygon_polyid | Geo Check | List of duplicate polygons based on shape id in a record |
| geocheck_duplicate_polygon_polyid_trimmed | Geo Check | List of duplicate polygons based on trimmed shapeid in a record |
| geocheck_duplicate_polygon_points | Geo Check | List of of duplicate points based on coordinates in a polygon|
| geocheck_duplicate_polygon_point_localid | Geo Check | List of duplicate points based on localid in a polygon
| geocheck_duplicate_polygon_point_localid_trimmed | Geo Check | List of duplicate points based on trimmed localid in a polygon|
| geocheck_duplicate_points TODO | Geo Check | List of duplicate points based on coordinates NOT in a polygon|
| geocheck_duplicate_point_point_localid | Geo Check | List of duplicate points based on localid NOT in a polygon |
| geocheck_duplicate_point_point_localid_trimmed | Geo Check | List of duplicate points based on trimmed localid NOT in a polygon |
| geocheck_distance_polygon_points | Geo Check | List of polygons defined with a distance between 2 consecutive points higher than the value defined in the query (default is 5000 m) | 
| geocheck_zint_**!TYPE!**_valid_polys | Information | List of valid polygons |
| geocheck_zint_**!TYPE!**_valid_multipart_polys | Information| List of multi polygon records|
| geocheck_zint_**!TYPE!**_polys | Information | List of polygons created from IMSMAng points |
| geocheck_zint_**!TYPE!**_pts | Information | List of points from IMSMAng |

**!TYPE!** can be accident, gazetteer, hazard, hazreduc, location, mre, organisation, place, qa, task, victim_assistance, victim.

## Detailed description

### test


### geocheck_obj_**!type!**_invalid_polys
List of invalid polygons for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| wkt | WKT LINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| st_isvalidreason | Reason why the polygon is invalid |
| st_summary | Polygon description |

### geocheck_obj_**!TYPE!**_few_vertices_polys
List of polygons defined with less than 3 vertices for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| pointcount | Number of vertices |

### geocheck_duplicate_polygons
List of duplicate polygons based on coordinates in a record for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape | Postgis geometry |
| count | Number of duplicate polygons for each record|

### geocheck_duplicate_polygon_polyid
List of duplicate polygons based on shape id in a record for each IMSMAng object type.
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeenum | IMSMAng shape type |
| count | Number of duplicate polygons based on shapeid for each record|

### geocheck_duplicate_polygon_polyid_trimmed
List of duplicate polygons based on trimmed shape id in a record for each IMSMAng object type. Trim helps to find if space characters have been added by mistake at the end of the shape id.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeenum | IMSMAng shape type |
| count | Number of duplicate polygons based on shapeid for each record|

### geocheck_duplicate_polygon_points
List of duplicate points based on coordinates in a polygon for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  
The issues in the geocheck_duplicate_polygons views must be fixed first before looking at this view.

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeid | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| count | Number of duplicate points based on coordinates for each polygon in each record|

### geocheck_duplicate_polygon_point_localid
List of duplicate points based on localid in a polygon for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  
The issues in the geocheck_duplicate_polygons and geocheck_duplicate_polygon_points views must be fixed first before looking at this view.

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeid | IMSMAng polygon shapeid |
| pointlocal_id | IMSMAng point localid |
| pointtypeenum | IMSMAng point type |
| count | Number of duplicate points based on localid for each polygon in each record|

### geocheck_duplicate_polygon_point_localid_trimmed
List of duplicate points based on trimmed localid in a polygon for each IMSMAng object type.  Trim helps to find if space characters have been added by mistake at the end of the localid.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  
The issues in the geocheck_duplicate_polygons and geocheck_duplicate_polygon_points views must be fixed first before looking at this view.  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeid | IMSMAng polygon shapeid |
| pointlocal_id | IMSMAng point localid |
| pointtypeenum | IMSMAng point type |
| count | Number of duplicate points based on localid for each polygon in each record|

### geocheck_duplicate_points
List of duplicate points based on coordinates NOT in a polygon for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeid | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| count | Number of duplicate points based on coordinates for each polygon in each record|

### geocheck_duplicate_polygon_point_localid
List of duplicate points based on localid NOT in a polygon for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  
The issues in the geocheck_duplicate_points view must be fixed first before looking at this view.

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| pointlocal_id | IMSMAng point localid |
| pointtypeenum | IMSMAng point type |
| count | Number of duplicate points based on localid for each polygon in each record|

### geocheck_duplicate_polygon_point_localid_trimmed
List of duplicate points based on trimmed localid NOT in a polygon for each IMSMAng object type.  Trim helps to find if space characters have been added by mistake at the end of the localid.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  
The issues in the geocheck_duplicate_points view must be fixed first before looking at this view.  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| pointlocal_id | IMSMAng point localid |
| pointtypeenum | IMSMAng point type |
| count | Number of duplicate points based on localid for each polygon in each record|

### geocheck_distance_polygon_points
List of polygons defined with a distance between 2 consecutive points higher than the value defined in the query (default is 5000 m). The value can be change by doing a replace all as explained at the top of the file.  
**This view must be MOSTLY empty as there may be relevant use cases for long distance between vertices.**

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| localid | IMSMAng localid |
| shapeid | IMSMAng polygon shapeid |
| distance | Distance in meters higher than the default distance used in the query |

### geocheck_obj_**!TYPE!**_valid_polys 
List of valid polygons for each IMSMAng object type.  

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| wkt | WKT LINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| st_summary | Polygon description |

### geocheck_zint_**!TYPE!**_valid_multipart_polys
List of multi polygon records.  

| Field | Description|
| --- | --- |
| **!TYPE!**_localid | IMSMAng localid |
| st_collect | Postgis geometry |
| wkt | WKT MULTILINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| st_summary | Polygon description |

### geocheck_obj_**!TYPE!**_valid_polys 
List of polygons for each IMSMAng object type.  

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| pointcount | Number of vertices for each polygon |

### geocheck_zint_**!TYPE!**_pts
List of points from IMSMAng.  

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng object GUID |
| **!TYPE!**_localid | IMSMAng localid |
| geospatialifo_guid| IMSMAng geospatialinfo GUID |
| shapeenum | IMSMAng shape type |
| shape_id | IMSMAng shapeid |
| isactive | IMSMAng system field |
| g_dataentrydate | Geopoint entry date in IMSMAng|
| g_dataenterer | IMSMAng user who entered the geopoint|
| poly_prop_enum_guid | IMSMAng Poly Property GUID |
| geopoint_guid | IMSMAng Geopoint GUID|
| pointlocal_id | IMSMAng Geopoint localid |
| pointno | IMSMAng Geopoint number |
| pointtypeenum | IMSMAng point type |
| pointdescription | IMSMAng point description |
| latitude | IMSMAng point latitude (WGS 1984)|
| longitude | IMSMAng point latitude (WGS 1984)|
| coordrefsys | Coordinate Reference System used by user when entering original coordinates|
| fixedby_guid | IMSMAng enum GUID on how the coordinated were taken|
| bearing| bearing information|
| distance| distance information|
| frompoint_guid| IMSMAng point GUID from which the distance and bearing were taken|
| frompointinput | |
| userinputformat | Input format used by user when entering original coordinates|
| coordformat | Coordinate format used by user when entering original coordinates|
| dataentrydate | Geopoint entry date in IMSMAng|
| dataenterer | IMSMAng user who entered the geopoint|
| elevation | Geopoint elevation information|
| user_entered_x | x coordinate originally entered by user|
| user_entered_y| y coordinate originally entered by user|
| user_entered_mgrs| MGRS coordinate originally entered by user|
| shape | Postgis geometry |
