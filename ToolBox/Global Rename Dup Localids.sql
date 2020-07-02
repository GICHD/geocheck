(select
	'HAZARD' as object_type,
	hazard_guid,
	old_localid,
	new_localid,
	concat(
		'update hazard set hazard_localid=''',
		new_localid,
		''' where hazard_localid=''',
		old_localid,
		''' and hazard_guid=''',
		hazard_guid,
		''';') as main_queries,
	concat(
		'update hazardinfoversion set hazard_localid=''',
		new_localid,
		''' where hazard_localid=''',
		old_localid,
		''' and hazard_guid=''',
		hazard_guid,
		''';') as version_queries
from
	(select
		hazard_guid,
		hazard_localid as old_localid,
		row_number() over (partition by hazard_localid order by hazard_localid ),
		hazard_localid || '-DUP' || lpad(row_number() over (partition by hazard_localid order by hazard_localid ) :: text, 2, '0') as new_localid
	from hazard where hazard_localid in 
		(select
			hazard_localid as duplicate_localid
		from hazard
		group by hazard_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'HAZARD REDUCTION' as object_type,
	hazreduc_guid,
	old_localid,
	new_localid,
	concat(
		'update hazreduc set hazreduc_localid=''',
		new_localid,
		''' where hazreduc_localid=''',
		old_localid,
		''' and hazreduc_guid=''',
		hazreduc_guid,
		''';') as main_queries,
	concat(
		'update hazreducinfoversion set hazreduc_localid=''',
		new_localid,
		''' where hazreduc_localid=''',
		old_localid,
		''' and hazreduc_guid=''',
		hazreduc_guid,
		''';') as version_queries
from
	(select
		hazreduc_guid,
		hazreduc_localid as old_localid,
		row_number() over (partition by hazreduc_localid order by hazreduc_localid ),
		hazreduc_localid || '-DUP' || lpad(row_number() over (partition by hazreduc_localid order by hazreduc_localid ) :: text, 2, '0') as new_localid
	from hazreduc where hazreduc_localid in 
		(select
			hazreduc_localid as duplicate_localid
		from hazreduc
		group by hazreduc_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'ACCIDENT' as object_type,
	accident_guid,
	old_localid,
	new_localid,
	concat(
		'update accident set accident_localid=''',
		new_localid,
		''' where accident_localid=''',
		old_localid,
		''' and accident_guid=''',
		accident_guid,
		''';') as main_queries,
	concat(
		'update accidentinfoversion set accident_localid=''',
		new_localid,
		''' where accident_localid=''',
		old_localid,
		''' and accident_guid=''',
		accident_guid,
		''';') as version_queries
from
	(select
		accident_guid,
		accident_localid as old_localid,
		row_number() over (partition by accident_localid order by accident_localid ),
		accident_localid || '-DUP' || lpad(row_number() over (partition by accident_localid order by accident_localid ) :: text, 2, '0') as new_localid
	from accident where accident_localid in 
		(select
			accident_localid as duplicate_localid
		from accident
		group by accident_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'MRE' as object_type,
	mre_guid,
	old_localid,
	new_localid,
	concat(
		'update mre set mre_localid=''',
		new_localid,
		''' where mre_localid=''',
		old_localid,
		''' and mre_guid=''',
		mre_guid,
		''';') as main_queries,
	concat(
		'update mreinfoversion set mre_localid=''',
		new_localid,
		''' where mre_localid=''',
		old_localid,
		''' and mre_guid=''',
		mre_guid,
		''';') as version_queries
from
	(select
		mre_guid,
		mre_localid as old_localid,
		row_number() over (partition by mre_localid order by mre_localid ),
		mre_localid || '-DUP' || lpad(row_number() over (partition by mre_localid order by mre_localid ) :: text, 2, '0') as new_localid
	from mre where mre_localid in 
		(select
			mre_localid as duplicate_localid
		from mre
		group by mre_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'QA' as object_type,
	qa_guid,
	old_localid,
	new_localid,
	concat(
		'update qa set qa_localid=''',
		new_localid,
		''' where qa_localid=''',
		old_localid,
		''' and qa_guid=''',
		qa_guid,
		''';') as main_queries,
	concat(
		'update qainfoversion set qa_localid=''',
		new_localid,
		''' where qa_localid=''',
		old_localid,
		''' and qa_guid=''',
		qa_guid,
		''';') as version_queries
from
	(select
		qa_guid,
		qa_localid as old_localid,
		row_number() over (partition by qa_localid order by qa_localid ),
		qa_localid || '-DUP' || lpad(row_number() over (partition by qa_localid order by qa_localid ) :: text, 2, '0') as new_localid
	from qa where qa_localid in 
		(select
			qa_localid as duplicate_localid
		from qa
		group by qa_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'VICTIM' as object_type,
	victim_guid,
	old_localid,
	new_localid,
	concat(
		'update victim set victim_localid=''',
		new_localid,
		''' where victim_localid=''',
		old_localid,
		''' and victim_guid=''',
		victim_guid,
		''';') as main_queries,
	concat(
		'update victiminfoversion set victim_localid=''',
		new_localid,
		''' where victim_localid=''',
		old_localid,
		''' and victim_guid=''',
		victim_guid,
		''';') as version_queries
from
	(select
		victim_guid,
		victim_localid as old_localid,
		row_number() over (partition by victim_localid order by victim_localid ),
		victim_localid || '-DUP' || lpad(row_number() over (partition by victim_localid order by victim_localid ) :: text, 2, '0') as new_localid
	from victim where victim_localid in 
		(select
			victim_localid as duplicate_localid
		from victim
		group by victim_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'GAZETTEER' as object_type,
	gazetteer_guid,
	old_localid,
	new_localid,
	concat(
		'update gazetteer set gazetteer_localid=''',
		new_localid,
		''' where gazetteer_localid=''',
		old_localid,
		''' and gazetteer_guid=''',
		gazetteer_guid,
		''';') as main_queries,
	'' :: text as version_queries
from
	(select
		gazetteer_guid,
		gazetteer_localid as old_localid,
		row_number() over (partition by gazetteer_localid order by gazetteer_localid ),
		gazetteer_localid || '-DUP' || lpad(row_number() over (partition by gazetteer_localid order by gazetteer_localid ) :: text, 2, '0') as new_localid
	from gazetteer where gazetteer_localid in 
		(select
			gazetteer_localid as duplicate_localid
		from gazetteer
		group by gazetteer_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'LOCATION' as object_type,
	location_guid,
	old_localid,
	new_localid,
	concat(
		'update location set location_localid=''',
		new_localid,
		''' where location_localid=''',
		old_localid,
		''' and location_guid=''',
		location_guid,
		''';') as main_queries,
	concat(
		'update locationinfoversion set location_localid=''',
		new_localid,
		''' where location_localid=''',
		old_localid,
		''' and location_guid=''',
		location_guid,
		''';') as version_queries
from
	(select
		location_guid,
		location_localid as old_localid,
		row_number() over (partition by location_localid order by location_localid ),
		location_localid || '-DUP' || lpad(row_number() over (partition by location_localid order by location_localid ) :: text, 2, '0') as new_localid
	from location where location_localid in 
		(select
			location_localid as duplicate_localid
		from location
		group by location_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'PLACE' as object_type,
	place_guid,
	old_localid,
	new_localid,
	concat(
		'update place set place_localid=''',
		new_localid,
		''' where place_localid=''',
		old_localid,
		''' and place_guid=''',
		place_guid,
		''';') as main_queries,
	concat(
		'update placeinfoversion set place_localid=''',
		new_localid,
		''' where place_localid=''',
		old_localid,
		''' and place_guid=''',
		place_guid,
		''';') as version_queries
from
	(select
		place_guid,
		place_localid as old_localid,
		row_number() over (partition by place_localid order by place_localid ),
		place_localid || '-DUP' || lpad(row_number() over (partition by place_localid order by place_localid ) :: text, 2, '0') as new_localid
	from place where place_localid in 
		(select
			place_localid as duplicate_localid
		from place
		group by place_localid
		having count(*) > 1)
		) as temp1)
union
(select
	'VICTIM ASSISTANCE' as object_type,
	guid,
	old_localid,
	new_localid,
	concat(
		'update victim_assistance set localid=''',
		new_localid,
		''' where localid=''',
		old_localid,
		''' and guid=''',
		guid,
		''';') as main_queries,
	concat(
		'update victim_assistance_version set localid=''',
		new_localid,
		''' where localid=''',
		old_localid,
		''' and guid=''',
		guid,
		''';') as version_queries
from
	(select
		guid,
		localid as old_localid,
		row_number() over (partition by localid order by localid ),
		localid || '-DUP' || lpad(row_number() over (partition by localid order by localid ) :: text, 2, '0') as new_localid
	from victim_assistance where localid in 
		(select
			localid as duplicate_localid
		from victim_assistance
		group by localid
		having count(*) > 1)
		) as temp1)
union
(select
	'TASK' as object_type,
	guid,
	old_localid,
	new_localid,
	concat(
		'update task set localid=''',
		new_localid,
		''' where localid=''',
		old_localid,
		''' and guid=''',
		guid,
		''';') as main_queries,
	'' :: text as version_queries
from
	(select
		guid,
		localid as old_localid,
		row_number() over (partition by localid order by localid ),
		localid || '-DUP' || lpad(row_number() over (partition by localid order by localid ) :: text, 2, '0') as new_localid
	from task where localid in 
		(select
			localid as duplicate_localid
		from task
		group by localid
		having count(*) > 1)
		) as temp1)
union
(select
	'ORGANISATION' as object_type,
	org_guid,
	old_localid,
	new_localid,
	concat(
		'update organisation set org_localid=''',
		new_localid,
		''' where org_localid=''',
		old_localid,
		''' and org_guid=''',
		org_guid,
		''';') as main_queries,
	'' :: text as version_queries
from
	(select
		org_guid,
		org_localid as old_localid,
		row_number() over (partition by org_localid order by org_localid ),
		org_localid || '-DUP' || lpad(row_number() over (partition by org_localid order by org_localid ) :: text, 2, '0') as new_localid
	from organisation where org_localid in 
		(select
			org_localid as duplicate_localid
		from organisation
		group by org_localid
		having count(*) > 1)
		) as temp1)

