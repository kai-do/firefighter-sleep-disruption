select
	incident_number = incidentnumber
,	callsign
,	dispatch_dt = dispatchtime
,	enroute_dt = enroutetime
,	arrival_dt = onscenetime
,	clear_dt = cleartime

from mv_incidentunits

where agencyid = 'CF'
