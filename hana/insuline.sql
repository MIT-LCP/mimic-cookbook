-- # 1.	Insuline Doses

select distinct po."DOSES_PER_24HRS", pm."DOSE_VAL_RX"
from "MIMIC2V26"."poe_order" po, "MIMIC2V26"."poe_med" pm
where po."POE_ID" = pm."POE_ID" and lower(po."MEDICATION") like '%insulin%' and lower(pm."DRUG_NAME_GENERIC") like '%insulin%'
order by po."DOSES_PER_24HRS", pm."DOSE_VAL_RX";

