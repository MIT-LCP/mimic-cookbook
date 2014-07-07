-- # 10.	RR interval Histogram

select bucket, count(*) from (
   	select "VALUE1NUM", width_bucket("ce"."VALUE1NUM", 0, 130, 1400) as bucket
   	from "MIMIC2V26"."chartevents" "ce", "MIMIC2V26"."d_patients" "dp"
   	where "ITEMID" in (219, 615, 618) and "ce"."SUBJECT_ID" = "dp"."SUBJECT_ID" and months_between("dp"."DOB", "ce"."CHARTTIME")/12 > 15)
group by bucket order by bucket;


