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
objcdf."MRE_GUID" as record_guid,
mre.mre_localid as localid
from mre_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf."CDFValue_GUID"
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join mre on mre.mre_guid = objcdf."MRE_GUID"
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
objcdf."Hazard_GUID" as record_guid,
hazard.hazard_localid as localid
from hazard_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf."CDFValue_GUID"
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join hazard on hazard.hazard_guid = objcdf."Hazard_GUID"
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
objcdf."HazReduc_GUID" as record_guid,
hazreduc.hazreduc_localid as localid
from hazreduc_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf."CDFValue_GUID"
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join hazreduc on hazreduc.hazreduc_guid = objcdf."HazReduc_GUID"
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
objcdf.hazreducdevice_guid as record_guid,
hazreduc.hazreduc_localid as localid
from hazreducdevice_has_cdfvalue objcdf
inner join cdfvalue cdv on cdv.cdfvalue_guid = objcdf.cdfvalue_guid
inner join customdefinedfield cdf on cdf.cdf_id = cdv.cdf_id 
inner join hazreducdeviceinfo on hazreducdeviceinfo.hazreducdeviceinfo_guid = objcdf.hazreducdevice_guid
inner join hazreduc on hazreduc.hazreduc_guid = hazreducdeviceinfo.hazreduc_guid
where cdf.cdf_datatype != 'MULTI_SELECT'
)  as values_from
group by cdf_id, name, record_guid, localid) as agg_values_from
where agg_cdfvalues like '%|%')
