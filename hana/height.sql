-- # 2.	Height Histogram

select bucket, count(*) from (
   	select "VALUE1NUM", floor("VALUE1NUM" * 200/ (200 - 0)) as bucket
   	from "MIMIC2V26"."chartevents"
   	where "ITEMID" = 920 and "VALUE1NUM" is not null and "VALUE1NUM" between 1 and 499) x
group by bucket order by bucket;

