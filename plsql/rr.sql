select bucket/10, count(*) from (
  select value1num, width_bucket(value1num, 0, 130, 1400) as bucket
    from mimic2v26.chartevents ce,
         mimic2v26.d_patients dp
   where itemid in (219, 615, 618)
     and ce.subject_id = dp.subject_id
     and months_between(ce.charttime, dp.dob)/12 > 15
       ) group by bucket order by bucket;
