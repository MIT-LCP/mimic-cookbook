select bucket, count(*) from (
  select width_bucket(valuenum, 0, 280, 280) as bucket
    from mimic2v26.labevents le,
         mimic2v26.d_patients dp
   where itemid in (50177)
     and le.subject_id = dp.subject_id
     and months_between(le.charttime, dp.dob)/12 > 15
  ) group by bucket order by bucket;
