-- # 4.	Get Gladow come scale (GSC) histogram

select bucket, count(*) from (
   	select width_bucket("ce"."VALUE1NUM", 1, 30, 20) as bucket
   	from "MIMIC2V26"."chartevents" "ce", "MIMIC2V26"."d_patients" "dp"
   	where "ITEMID" in (198) and "ce"."SUBJECT_ID" = "dp"."SUBJECT_ID" and months_between("dp"."DOB", "ce"."CHARTTIME")/12 > 15)
group by bucket order by bucket;

