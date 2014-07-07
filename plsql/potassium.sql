select bucket/10, count(*) from (
  select width_bucket(valuenum, 0, 10, 100) as bucket
    from mimic2v26.labevents le,
         mimic2v26.d_patients dp
   where itemid in (50009, 50149)
     and le.subject_id = dp.subject_id
     and months_between(le.charttime, dp.dob)/12 > 15
       ) group by bucket order by bucket;
