-- # 6.	Serum HCO3 Histogram

select bucket, count(*) from (
   	select width_bucket("le"."VALUENUM", 0, 231, 231) as bucket
   	from "MIMIC2V26"."labevents" "le"
   	where "ITEMID" in (50022, 50025, 50172))
group by bucket order by bucket;

