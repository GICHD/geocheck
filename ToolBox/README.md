# geocheck ToolBox

## Description
The goecheck ToolBox is a set of tools to help clean up an IMSMAng database. It is important to run those tools before attempting to migrate an IMSMAng database to IMSMA Core.

The tools are doing the following:
  - Delete the last point of a polygon when it is a duplicate fo the first point [Global Delete Dup Last Points](#global_delete_dup_last_points)
  - Delete one of 2 duplicate consecutive points in a polygon [Global Delete Dup Consecutive Points](#global_delete_dup_consecutive_points)
  - Delete one point part of a pair of duplicate single point in a record [Global Delete Dup Single Points](#global_delete_dup_single_points)
  - Delete the last 2 points of a polygon when there are identical to the first 2 points [Global Delete Dup Last 2 Points with FirstSec](#global_delete_dup_last_2_points_with_firstcec)
  - Search for duplicate CDF values [Global Duplicate CDF (Records)](#global_duplicate_cdf__records_)
  - Provide queries to rename records with duplicate localid [Global Rename Dup Localids](#global_rename_dup_localids)
  - Provide queries to analyze the enum values [EnumValueReviewQueries](#enumvaluereviewqueries)

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
Type | SQL
Geocheck Views Needed | No
Scope | Records and Infoversions
Output | List of duplicate points or Duplicate points deletion
Detail Description | This SQL query looks for each polygon if the last point is a duplicate of the first point. The resolution used for comparison is 0.000001
Usage Information | either comment the first line to get the list of last points found or comment the second line to delete the last points found 

### Global Delete Dup Consecutive Points
Tool |  [Global Delete Dup Consecutive Points.sql](https://github.com/GICHD/geocheck/blob/master/ToolBox/Global%20Delete%20Dup%20Consecutive%20Points.sql)
--- | ---
Type | SQL
Geocheck Views Needed | Yes
Output | List of duplicate points or Duplicate points deletion
Scope | Records and Infoversions
Detail Description | This SQL query looks for each polygon if 2 consecutive points are duplicate. The resolution used for comparison is 0.000001
Usage Information | For both queries in the file, either comment the first line to get the list of duplicate consecutive points found or comment the second line to delete the duplicate consecutive points found 

