select bucket, count(*) from (
  select width_bucket(value1num, 1, 30, 30) as bucket
    from mimic2v26.chartevents ce,
         mimic2v26.d_patients dp
   where itemid in (198)
     and ce.subject_id = dp.subject_id
     and months_between(ce.charttime, dp.dob)/12 > 15
       ) group by bucket order by bucket;
