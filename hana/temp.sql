-- # 13.	Body temperature Histogram

select bucket, count(*) from (
   	select width_bucket(
          	case
          	when "ce"."ITEMID" in (676, 677) then "ce"."VALUE1NUM"
          	when "ce"."ITEMID" in (678, 679) then ("ce"."VALUE1NUM" - 32) * 5 / 9
          	end, 30, 45, 160) as bucket
   	from "MIMIC2V26"."chartevents" "ce", "MIMIC2V26"."d_patients" "dp"
   	where "ITEMID" in (676, 677, 678, 679) and "ce"."SUBJECT_ID" = "dp"."SUBJECT_ID" and months_between("dp"."DOB", "ce"."CHARTTIME")/12 > 15)
group by bucket order by bucket;
