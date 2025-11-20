select
	incident_number = Basic_Incident_Number
,	incident_type = Basic_Incident_Type
,	incident_type_code = Basic_Incident_Type_Code

from DwFire.Dim_Basic
	inner join DwFire.Fact_Fire on Fact_Fire.Dim_Basic_FK = Dim_Basic.Dim_Basic_PK

where Basic_Incident_Validity_Score = 100