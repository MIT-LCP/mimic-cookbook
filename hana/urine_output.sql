-- # 14.	Urine Output Histogram

select bucket, count(*) from (
   	select width_bucket("ie"."VOLUME", 0, 1000, 200) as bucket
   	from "MIMIC2V26"."ioevents" "ie", "MIMIC2V26"."d_patients" "dp"
   	where "ITEMID" in (55, 56, 57, 61, 65, 69, 85, 94, 96, 288, 405, 428, 473, 651, 715, 1922, 2042, 2068, 2111, 2119, 2130, 2366, 2463,
   	2507, 2510, 2592, 2676, 2810, 2859, 3053, 3175, 3462, 3519, 3966, 3987, 4132, 4253, 5927)
   	and "ie"."SUBJECT_ID" = "dp"."SUBJECT_ID" and months_between("dp"."DOB", "ie"."CHARTTIME")/12 > 15)
group by bucket order by bucket;

