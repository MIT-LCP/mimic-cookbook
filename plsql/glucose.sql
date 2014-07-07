select bucket, count(*) from (
  select width_bucket(valuenum, 0.5, 1000, 1000) as bucket
    from mimic2v26.labevents le,
         mimic2v26.d_patients dp
   where itemid in (50006,50112) and valuenum is not null
      and le.subject_id = dp.subject_id
      and months_between(le.charttime, dp.dob)/12 > 15
       ) group by bucket order by bucket;
