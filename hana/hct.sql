-- # 7.	Hematocrit (%) Histogram

select bucket, count(*) from (
   	select width_bucket("ce"."VALUE1NUM", 0, 150, 150) as bucket
   	from "MIMIC2V26"."chartevents" "ce", "MIMIC2V26"."d_patients" "dp"
   	where "ITEMID" in (813) and "ce"."SUBJECT_ID" = "dp"."SUBJECT_ID" and months_between("dp"."DOB", "ce"."CHARTTIME")/12 > 15)
group by bucket order by bucket;
