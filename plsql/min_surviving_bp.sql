set echo off ver off feed off pages 0 lin 200

spool &3/&2

select bucket, count(*) from (
  select width_bucket(min_sbp, 0, 300, 300) as bucket from (
    select dp.subject_id, ce.icustay_id, min(value1num) as min_sbp
      from mimic2v26.chartevents ce,
           mimic2v26.d_patients dp
     where itemid in (6, 51, 455, 6701)
       and ce.subject_id = dp.subject_id
       and dp.hospital_expire_flg = 'N'
       and months_between(ce.charttime, dp.dob)/12 > 15 group by dp.subject_id, ce.icustay_id
    )
  ) group by bucket order by bucket;

spool off
exit;
