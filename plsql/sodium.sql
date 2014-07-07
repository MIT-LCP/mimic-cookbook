select bucket, count(*) from (
  select width_bucket(valuenum, 0, 180, 180) as bucket
    from mimic2v26.labevents le,
         mimic2v26.d_patients dp
   where itemid in (50012, 50159)
     and le.subject_id = dp.subject_id
     and months_between(le.charttime, dp.dob)/12 > 15
  ) group by bucket order by bucket;
