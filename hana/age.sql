-- # 1.	Age Histogram

select bucket + 15, count(*) from (
   	select width_bucket(months_between("dp"."DOB", "ad"."ADMIT_DT")/12, 15, 100, 85) as bucket
   	from "MIMIC2V26"."admissions" "ad", "MIMIC2V26"."d_patients" "dp"
   	where "ad"."SUBJECT_ID" = "dp"."SUBJECT_ID" and months_between("dp"."DOB", "ad"."ADMIT_DT") / 12 between 15 and 199)
group by bucket order by bucket

