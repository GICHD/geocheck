# geocheck ToolBox

## Description
The goecheck ToolBox is a set of tools to help clean up an IMSMAng database. It is important to run those tools before attempting to migrate an IMSMAng database to IMSMA Core.

The tools are doing the following:
  - Delete the last point of a polygon when it is a duplicate fo the first point [Global Delete Dup Last Points](#global-delete-dup-last-points)
  - Delete one of 2 duplicate consecutive points in a polygon [Global Delete Dup Consecutive Points](#global-delete-dup-consecutive-points)
  - Delete one point part of a pair of duplicate single point in a record [Global Delete Dup Single Points](#global-delete-dup-single-points)
  - Delete the last 2 points of a polygon when there are identical to the first 2 points [Global Delete Dup Last 2 Points with FirstSec](#global-delete-dup-last-2-points-with-firstcec)
  - Search for duplicate CDF values [Global Duplicate CDF (Records)](#global-duplicate-cdf-records)
  - Search for duplicate CDF values [Global Duplicate CDF (Infoversions)](#global-duplicate-cdf-infoversions)
  - Provide queries to rename records with duplicate localid [Global Rename Dup Localids](#global-rename-dup-localids)
  - Provide queries to analyze the enum values [Enum Value Review](#enum-value-review)

## Who is this for?

* IMSMA NG Administrators
* IM Advisors supporting IMSMA NG

## Requirements

* IMSMA NG Version 6
* A SQL Editor, for example pgAdmin or Navicat.

## Detailed descriptions

### Global Delete Dup Last Points
Tool |  [Global Delete Dup Last Points.sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Delete%20Dup%20Last%20Points.sql)
--- | ---
Geocheck Views Needed | No
Scope | Records and Infoversions
Output | List of duplicate points or Duplicate points deletion
Detail Description | This SQL query looks for each polygon if the last point is a duplicate of the first point. The resolution used for comparison is 0.000001
Usage Information | either comment the first line to get the list of last points found or comment the second line to delete the last points found 

### Global Delete Dup Consecutive Points
Tool |  [Global Delete Dup Consecutive Points.sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Delete%20Dup%20Consecutive%20Points.sql)
--- | ---
Geocheck Views Needed | Yes
Output | List of duplicate points or Duplicate points deletion
Scope | Records and Infoversions
Detail Description | This SQL query looks for each polygon if 2 consecutive points are duplicate. The resolution used for comparison is 0.000001
Usage Information | For both queries in the file, either comment the first line to get the list of duplicate consecutive points found or comment the second line to delete the duplicate consecutive points found 

### Global Delete Dup Single Points
Tool |  [Global Delete Dup Single Points.sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Delete%20Dup%20Single%20Points.sql)
--- | ---
Geocheck Views Needed | Yes
Output | List of duplicate points or Duplicate points deletion
Scope | Records and Infoversions
Detail Description | This SQL query looks for each record if 2 single points are duplicate. The resolution used for comparison is 0.000001
Usage Information | For all queries in the file, either comment the first line to get the list of duplicate single points found or comment the second line to delete the duplicate single points found 


### Global Delete Dup Last 2 Points with FirstSec
Tool |  [Global Delete Dup Last 2 Points with FirstSec.sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Delete%20Dup%20Last%202%20Points%20with%20FirstSec.sql)
--- | ---
Geocheck Views Needed | Yes
Output | List of duplicate points or Duplicate points deletion
Scope | Lands and Activies Records
Detail Description | This SQL query looks for each polygon if the second but last and last points are a duplicate pair to the first and second points. The resolution used for comparison is 0.000001
Usage Information | For both queries in the file, either comment the first line to get the list of duplicate pair points found or comment the second line to delete the duplicate pair points found 

### Global Duplicate CDF (Records)
Tool |  [Global Duplicate CDF (Records).sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Duplicate%20CDF%20(Records).sql)
--- | ---
Geocheck Views Needed | No
Output | List of duplicate CDFs and their respective values
Scope | MRE, Land, Activity and Activity Device Records
Detail Description | This SQL query looks CDFs having 2 instances in MRE, Land, Activity and Activity Device records. It provides the values and cdfvalues guids in aggregate forms that can be used to perform the appropriate deletions.
Usage Information | Duplicate CDFs should not exist but are sometimes created through bad form configuration or IMSMAng bugs. They tipically prevent the generation of the staging area and leave incertainty regarding the concerned CDF value.

### Global Duplicate CDF (Infoversions)
Tool |  [Global Duplicate CDF (Infoversions).sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Duplicate%20CDF%20(Infoversions).sql)
--- | ---
Geocheck Views Needed | No
Output | List of duplicate CDFs and their respective values
Scope | MRE, Land, Activity and Activity Device Infoversions
Detail Description | This SQL query looks CDFs having 2 instances in MRE, Land, Activity and Activity Device infoversions. It provides the values and cdfvalues guids in aggregate forms that can be used to perform the appropriate deletions.
Usage Information | Duplicate CDFs should not exist but are sometimes created through bad form configuration or IMSMAng bugs. They tipically prevent the generation of the staging area and leave incertainty regarding the concerned CDF value.

### Global Rename Dup Localids
Tool |  [Global Rename Dup Localids.sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Rename%20Dup%20Localids.sql)
--- | ---
Geocheck Views Needed | No
Output | List of update queries to modify duplicate localids
Scope | Records and Infoversions
Detail Description | This SQL query looks for duplicate localids and build the update queries to modify them. It automatically adds -DUP01, -DUP02, .... to the existing localid.
Usage Information | Run the queries and use the content of the main_queries column to update Records localid and the content of the version_queries to update Infoversions localid.

### Enum Value Review
Tool |  [Enum Value Review.sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/EnumValueReviewQueries.xlsx)
--- | ---
Geocheck Views Needed | No
Output | List of the values and associated counts for all enum of all object types
Scope | Record
Detail Description | This SQL query provide an organized list of all enum values and associated counts. It is ordered by object type and enum name. Each enum is separated by a line of dashs with count 0.
Usage Information | Run the query and perform analysis to identify mistakes or inconsistencies in enum values.
