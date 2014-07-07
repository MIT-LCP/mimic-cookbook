select (bucket/10) + 30, count(*) from (
  select width_bucket(
      case when itemid in (676, 677) then value1num
           when itemid in (678, 679) then (value1num - 32) * 5 / 9
           end, 30, 45, 160) as bucket
    from mimic2v26.chartevents ce,
         mimic2v26.d_patients dp
   where itemid in (676, 677, 678, 679)
     and ce.subject_id = dp.subject_id
     and months_between(ce.charttime, dp.dob)/12 > 15
       ) group by bucket order by bucket;
