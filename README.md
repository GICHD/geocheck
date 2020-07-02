# geocheck views

## Features
The SQL script geocheck.sql create views in the public schema of IMSMAng that help check the quality of geographical information for your IMSMAng database. The script is meant to be run on a IMSMAng V6 installation.  The Geocheck is **read-only** and does not edit your data.

The checks look at a variety of possible issues:
  - invalid polygons (IMSMAng does not check if a polygon created by a set of points is valid)
  - polygons with too few vertices (less than 3)
  - duplicate information (polygon, point, point or polygon id)
  - distance between points in a polygon
  - overlapping polygons

The SQL script drop_views.sql can be used to remove all views from IMSMAng. 
The SQL script issue_count.sql can be used to count all issues detected by the geocheck queries.

## Who is this for?

* IMSMA NG Administrators
* IM Advisors supporting IMSMA NG

## Requirements

* IMSMA NG Version 6
* A SQL Editor, for example pgAdmin or Navicat.

## Installation Instructions

1. Create the database views

   Copy and run the geocheck.sql script in a query window in pgAdmin III or Navicat.

 2. Review the Geocheck Results

    In your database SQL editor, check the views below in turn for any issues.  As the issues are resolved the views will update automatically.

3. Drop the Views _(optional)_

   Run the drop_views.sql script to delete the views.

## Views available
There are 2 types of views:
  - Geo Check: they provides identified issues that need to be looked at.
  - Information: they are used as intermediary views to generate the Geo Check views but can provide useful information

|View Name| Type |  | Description|
| --- | --- | --- | --- |
| [geocheck_obj_**!TYPE!**_invalid_polys](#geocheck_obj_type_invalid_polys) | Geo Check | :heavy_exclamation_mark: | List of invalid polygons |
| [geocheck_obj_**!TYPE!**_few_vertices_polys](#geocheck_obj_type_few_vertices_polys) | Geo Check |:heavy_exclamation_mark: | List of polygons defined with less than 3 vertices|
| [geocheck_duplicate_polygons](#geocheck_duplicate_polygons) | Geo Check | :heavy_exclamation_mark: | List of duplicate polygons based on coordinates in a record |
| [geocheck_duplicate_polygon_polyid](#geocheck_duplicate_polygon_polyid) | Geo Check |:heavy_exclamation_mark: | List of duplicate polygons based on shape id in a record |
| [geocheck_duplicate_polygon_polyid_trimmed](#geocheck_duplicate_polygon_polyid_trimmed) | Geo Check | :heavy_exclamation_mark: | List of duplicate polygons based on trimmed shapeid in a record |
| [geocheck_duplicate_polygon_points](#geocheck_duplicate_polygon_points) | Geo Check | :heavy_exclamation_mark: | List of of duplicate points based on coordinates in a polygon|
| [geocheck_duplicate_polygon_point_localid](#geocheck_duplicate_polygon_point_localid) | Geo Check | :heavy_exclamation_mark: |List of duplicate points based on localid in a polygon
| [geocheck_duplicate_polygon_point_localid_trimmed](#geocheck_duplicate_polygon_point_localid_trimmed) | Geo Check | :heavy_exclamation_mark: | List of duplicate points based on trimmed localid in a polygon|
| [geocheck_duplicate_points](#geocheck_duplicate_points) | Geo Check | :heavy_exclamation_mark:| List of duplicate points based on coordinates NOT in a polygon|
| [geocheck_duplicate_point_point_localid](#geocheck_duplicate_point_point_localid) | Geo Check | :heavy_exclamation_mark: | List of duplicate points based on localid NOT in a polygon |
| [geocheck_duplicate_point_point_localid_trimmed](#geocheck_duplicate_point_point_localid_trimmed) | Geo Check | :heavy_exclamation_mark:| List of duplicate points based on trimmed localid NOT in a polygon |
| [geocheck_duplicate_localids](#geocheck_duplicate_localids) | Data Check | :heavy_exclamation_mark:| List of duplicate objects based on localid |
| [geocheck_duplicate_devices](#geocheck_duplicate_devices) | Data Check | :heavy_exclamation_mark:| List of duplicate devices|
| [geocheck_adv_distance_polygon_points](#geocheck_adv_distance_polygon_points) | Geo Check | :warning:| List of polygons defined with a distance between 2 consecutive points higher than the value defined in the query (default is 5000 m) | 
| [geocheck_adv_overlapping_polygons](#geocheck_adv_overlapping_polygons) | Geo Check | :warning:| List of multipart polygons whose polygons overlap more than a percentage defined in the query (default is 0.9%) | 
| [geocheck_zint_**!TYPE!**_valid_polys](#geocheck_zint_type_valid_polys) | Information |:information_source: | List of valid polygons |
| [geocheck_zint_**!TYPE!**_valid_singlepart_polys](#geocheck_zint_type_valid_singlepart_polys) | Information|:information_source: | List of single polygon records|
| [geocheck_zint_**!TYPE!**_valid_multipart_polys](#geocheck_zint_type_valid_multipart_polys) | Information|:information_source: | List of multi polygon records|
| [geocheck_zint_**!TYPE!**_all_object_polys](#geocheck_zint_type_all_object_polys) | Information|:information_source: | List of all polygons (single and multi)|
| [geocheck_zint_**!TYPE!**_polys](#geocheck_zint_type_polys) | Information | :information_source:|  List of polygons created from IMSMAng points |
| [geocheck_zint_**!TYPE!**_pts](#geocheck_zint_type_pts) | Information |:information_source: | List of points from IMSMAng |
| [geocheck_zint_**!TYPE!**_infoversion_pts](#geocheck_zint_type_infoversion_pts) | Information |:information_source: | List of points from IMSMAng infoversions |

**!TYPE!** can be accident, gazetteer, hazard, hazreduc, location, mre, organisation, place, qa, task, victim_assistance, victim.

:heavy_exclamation_mark: - Mandatory Fix
:warning: - Advisory
:information_source: - Information only

## Detailed descriptions

### geocheck_obj_**!TYPE!**_invalid_polys
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

[View list](#views-available)

### geocheck_obj_**!TYPE!**_few_vertices_polys
List of polygons defined with less than 3 vertices for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| pointcount | Number of vertices |

[View list](#views-available)

### geocheck_duplicate_polygons
List of duplicate polygons based on coordinates in a record for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| dup_shape_ids | List of duplicate polygon shape ids for each record|

[View list](#views-available)

### geocheck_duplicate_polygon_polyid
List of duplicate polygons based on shape id in a record for each IMSMAng object type.
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeenum | IMSMAng shape type |
| shape_id | IMSMAng polygon shapeid |
| count | Number of duplicate polygons based on shapeid for each record|

[View list](#views-available)

### geocheck_duplicate_polygon_polyid_trimmed
List of duplicate polygons based on trimmed shape id in a record for each IMSMAng object type. Trim helps to find if space characters have been added by mistake at the end of the shape id.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shapeenum | IMSMAng shape type |
| shape_id | IMSMAng polygon shapeid |
| count | Number of duplicate polygons based on shapeid for each record|

[View list](#views-available)

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
| dup_point_numbers | List of duplicate point numbers based on coordinates for each polygon in each record|

[View list](#views-available)

### geocheck_duplicate_polygon_point_localid
List of duplicate points based on localid in a polygon for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  
The issues in the geocheck_duplicate_polygons and geocheck_duplicate_polygon_points views must be fixed first before looking at this view.

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| pointlocal_id | IMSMAng point localid |
| pointtypeenum | IMSMAng point type |
| dup_point_numbers | List of duplicate point numbers based on localid for each polygon in each record|

[View list](#views-available)

### geocheck_duplicate_polygon_point_localid_trimmed
List of duplicate points based on trimmed localid in a polygon for each IMSMAng object type.  Trim helps to find if space characters have been added by mistake at the end of the localid.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  
The issues in the geocheck_duplicate_polygons and geocheck_duplicate_polygon_points views must be fixed first before looking at this view.  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| pointlocal_id | IMSMAng point localid |
| pointtypeenum | IMSMAng point type |
| dup_point_numbers | List of duplicate point numbers based on localid for each polygon in each record|

[View list](#views-available)

### geocheck_duplicate_points
List of duplicate points based on coordinates NOT in a polygon for each IMSMAng object type.  
**This view must be empty. If not, issues must be fixed manually in IMSMAng.**  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| dup_point_ids | List of duplicate point_ids based on coordinates for each polygon in each record|

[View list](#views-available)

### geocheck_duplicate_point_point_localid
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
| dup_point_numbers | List of the duplicate point numbers for each polygon in each record|

[View list](#views-available)

### geocheck_duplicate_point_point_localid_trimmed
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
| dup_point_numbers | List of the duplicate point numbers for each polygon in each record|

[View list](#views-available)

### geocheck_duplicate_localids
List of duplicate objects based on localid.  
**This view should be empty.**  

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| duplicate_localid | IMSMAng localid |
| duplicate_quantity | Number of duplicates per localid |
| duplicate_guids | List of the guids for each duplicate object|

[View list](#views-available)

### geocheck_duplicate_devices
List of duplicate devices based on model and quantity.  
**This view must be MOSTLY empty. When CDFs are used, there may be some genuine duplicate in this view.**

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| localid | IMSMAng localid |
| ordcategory_enum | Device category |
| ordsubcategory_enum | Device subcategory |
| model |  Device model |
| qty |  Device quantity |
| count | Number of duplicates | 

[View list](#views-available)

### geocheck_adv_distance_polygon_points
List of polygons defined with a distance between 2 consecutive points higher than the value defined in the query (default is 5000 m). The value can be change by doing a replace all as explained at the top of the file.  
**This view must be MOSTLY empty as there may be relevant use cases for long distance between vertices.**

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| localid | IMSMAng localid |
| shapeid | IMSMAng polygon shapeid |
| distance | Distance in meters higher than the default distance used in the query |

[View list](#views-available)

### geocheck_adv_overlapping_polygons
List of multipart polygons whose polygons overlap more than a defined percentage (default is 0.9%). The percentage can be change by doing a replace all as explained at the top of the file.  
**This view must be MOSTLY empty as there may be relevant use cases for polygon overlapping.**

| Field | Description|
| --- | --- |
| object_type | IMSMAng object type |
| localid | IMSMAng localid |
| wkt | WKT MULTILINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| overlap | Percentage by which the polygons are overlapping |

[View list](#views-available)

### geocheck_zint_**!TYPE!**_valid_polys 
List of valid polygons for each IMSMAng object type.  

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| wkt | WKT LINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| st_summary | Polygon description |

[View list](#views-available)

### geocheck_zint_**!TYPE!**_valid_singlepart_polys
List of single polygon records.  
**This view uses the ST_RemoveRepeatedPoints function to remove duplicate points from polygons.**

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape | Postgis geometry |
| wkt | WKT LINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| summary | Polygon description |

[View list](#views-available)

### geocheck_zint_**!TYPE!**_valid_multipart_polys
List of multi polygon records.  
**This view uses the ST_RemoveRepeatedPoints function to remove duplicate points from polygons.**

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape | Postgis geometry |
| wkt | WKT MULTILINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| summary | Polygon description |

[View list](#views-available)

### geocheck_zint_**!TYPE!**_all_object_polys
List of all polygons (single and multi).  
This view is a simple union of geocheck_zint_**!TYPE!**_valid_singlepart_polys and geocheck_zint_**!TYPE!**_valid_multipart_polys views.

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape | Postgis geometry |
| wkt | WKT LINESTRING and MULTILINESTRING - can be visualize with [this webpage](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) |
| summary | Polygon description |

[View list](#views-available)

### geocheck_zint_**!TYPE!**_polys 
List of polygons for each IMSMAng object type.  

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng GUID |
| **!TYPE!**_localid | IMSMAng localid |
| shape_id | IMSMAng polygon shapeid |
| shape | Postgis geometry |
| pointcount | Number of vertices for each polygon |

[View list](#views-available)

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

[View list](#views-available)


### geocheck_zint_**!TYPE!**_infoversion_pts
List of points from IMSMAng.  

| Field | Description|
| --- | --- |
| **!TYPE!**_guid | IMSMAng object GUID |
| **!TYPE!**_infoversion_guid | IMSMAng infoversion GUID |
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

[View list](#views-available)
