select bucket, count(*) from (
       select width_bucket(valuenum, 0, 231, 231) as bucket from mimic2v26.labevents where itemid in (50022, 50025, 50172)
       ) group by bucket order by bucket;
