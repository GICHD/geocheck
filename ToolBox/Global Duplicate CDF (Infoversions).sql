(select 'MRE' as cdf_type, agg_values_from.*
from
(select
name,
cdf_id,
string_agg(value,'|' order by value) as agg_cdfvalues,
string_agg(cdfvalue_guid,'|' order by value) as agg_cdfvalue_guids,
record_guid,
localid
from
(select
cdv.cdfvalue_guid as cdfvalue_guid,
cdf.cdf_id as cdf_id,
cdf.name as name,
coalesce(cdv.stringvalue, to_char(cdv.datevalue,'YYYY-MM-DD HH24:MI:SS'), to_char(cdv.numbervalue,'9999999.99'), cdv.organisation_value, cdv.place_value, cdv.gazetteer_value) as value,
objcdf.mreinfoversion_guid as record_guid,
mreinfoversion.mre_localid as localid
from mreinfoversion_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf.cdfvalue_guid
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join mreinfoversion on mreinfoversion.mreinfoversion_guid = objcdf.mreinfoversion_guid
where cdf.cdf_datatype != 'MULTI_SELECT'
)  as values_from
group by cdf_id, name, record_guid, localid) as agg_values_from
where agg_cdfvalues like '%|%')

union

(select 'HAZARD' as cdf_type, agg_values_from.*
from
(select
name,
cdf_id,
string_agg(value,'|' order by value) as agg_cdfvalues,
string_agg(cdfvalue_guid,'|' order by value) as agg_cdfvalue_guids,
record_guid,
localid
from
(select
cdv.cdfvalue_guid as cdfvalue_guid,
cdf.cdf_id as cdf_id,
cdf.name as name,
coalesce(cdv.stringvalue, to_char(cdv.datevalue,'YYYY-MM-DD HH24:MI:SS'), to_char(cdv.numbervalue,'9999999.99'), cdv.organisation_value, cdv.place_value, cdv.gazetteer_value) as value,
objcdf.hazardinfoversion_guid as record_guid,
hazardinfoversion.hazard_localid as localid
from hazardinfoversion_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf.cdfvalue_guid
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join hazardinfoversion on hazardinfoversion.hazardinfoversion_guid = objcdf.hazardinfoversion_guid
where cdf.cdf_datatype != 'MULTI_SELECT'
)  as values_from
group by cdf_id, name, record_guid, localid) as agg_values_from
where agg_cdfvalues like '%|%')

union

(select 'HAZARD REDUCTION' as cdf_type, agg_values_from.*
from
(select
name,
cdf_id,
string_agg(value,'|' order by value) as agg_cdfvalues,
string_agg(cdfvalue_guid,'|' order by value) as agg_cdfvalue_guids,
record_guid,
localid
from
(select
cdv.cdfvalue_guid as cdfvalue_guid,
cdf.cdf_id as cdf_id,
cdf.name as name,
coalesce(cdv.stringvalue, to_char(cdv.datevalue,'YYYY-MM-DD HH24:MI:SS'), to_char(cdv.numbervalue,'9999999.99'), cdv.organisation_value, cdv.place_value, cdv.gazetteer_value) as value,
objcdf.hazreducinfoversion_guid as record_guid,
hazreducinfoversion.hazreduc_localid as localid
from hazreducinfoversion_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf.cdfvalue_guid
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join hazreducinfoversion on hazreducinfoversion.hazreducinfoversion_guid = objcdf.hazreducinfoversion_guid
where cdf.cdf_datatype != 'MULTI_SELECT'
)  as values_from
group by cdf_id, name, record_guid, localid) as agg_values_from
where agg_cdfvalues like '%|%')

union

(select 'HAZARD REDUCTION DEVICE' as cdf_type, agg_values_from.*
from
(select
name,
cdf_id,
string_agg(value,'|' order by value) as agg_cdfvalues,
string_agg(cdfvalue_guid,'|' order by value) as agg_cdfvalue_guids,
record_guid,
localid
from
(select
cdv.cdfvalue_guid as cdfvalue_guid,
cdf.cdf_id as cdf_id,
cdf.name as name,
coalesce(cdv.stringvalue, to_char(cdv.datevalue,'YYYY-MM-DD HH24:MI:SS'), to_char(cdv.numbervalue,'9999999.99'), cdv.organisation_value, cdv.place_value, cdv.gazetteer_value) as value,
objcdf.hazreducdeviceversion_guid as record_guid,
hazreducinfoversion.hazreduc_localid as localid
from hazreducdeviceversion_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf.cdfvalue_guid
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join hazreducdeviceinfoversion on hazreducdeviceinfoversion.hazreducdeviceinfoversionversion_guid = objcdf.hazreducdeviceversion_guid
inner join hazreducinfoversion on hazreducinfoversion.hazreducinfoversion_guid = hazreducdeviceinfoversion.hazreducinfoversion_guid
where cdf.cdf_datatype != 'MULTI_SELECT'
)  as values_from
group by cdf_id, name, record_guid, localid) as agg_values_from
where agg_cdfvalues like '%|%')
