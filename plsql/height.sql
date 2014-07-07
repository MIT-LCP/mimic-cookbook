select bucket, count(*) from (
select value1num, width_bucket(value1num, 1, 200, 200) as
bucket from mimic2v26.chartevents where itemid = 920 and value1num is
not null and value1num > 0 and value1num < 500
      ) group by bucket order by bucket;