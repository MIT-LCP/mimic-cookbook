select bucket, count(*) from (
  select width_bucket(value1num, 0, 300, 301) as bucket
    from mimic2v26.chartevents ce,
         mimic2v26.d_patients dp
   where itemid = 211
     and ce.subject_id = dp.subject_id
     and months_between(ce.charttime, dp.dob)/12 > 15
       ) group by bucket order by bucket;

spool off
exit;
