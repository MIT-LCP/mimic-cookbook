/*
  sofa_score_inserts.sql

  Created on   : April 2010 by Daniel Scott and Tal Mandelbaum
  Last updated :
     $Author: djscott@ECG.MIT.EDU $
     $Date: 2011-04-20 11:14:15 -0400 (Wed, 20 Apr 2011) $
     $Rev: 235 $

 Valid for MIMIC II database schema version 2.6
 
 This script generates daily sofa (Sequential Organ Failure Assessment) scores
 for each patient in the ICU.
 
*/
--DROP TABLE MERGE26.SOFA_SCORE;

CREATE TABLE MERGE26.SOFA_SCORE AS (SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ROWNUM < 0);
GRANT ALL PRIVILEGES ON MERGE26.SOFA_SCORE TO MIMIC_PRO;

SELECT count(*) FROM MERGE26.SOFA_SCORE;--625755
DELETE FROM MERGE26.SOFA_SCORE;

SELECT itemid, count(*) FROM MERGE26.SOFA_SCORE GROUP BY itemid;

INSERT INTO MERGE26.SOFA_SCORE (
  SUBJECT_ID,
  ITEMID,
  CHARTTIME,
  ELEMID,
  REALTIME,
  CGID,
  CUID,
  VALUE1NUM,
  VALUE1UOM,
  ICUSTAY_ID
)
With
icustays as (
  SELECT
    icue.subject_id,
    a.hadm_id,
    icue.icustay_id,
    icue.intime icustay_intime,
    icue.outtime icustay_outtime
  FROM mimic2v26.icustayevents icue,
       mimic2v26.d_patients p,
       mimic2v26.admissions a
  WHERE months_between(icue.intime, p.dob) / 12 >= 15
    AND p.subject_id = icue.subject_id
    AND a.subject_id = p.subject_id
    AND icue.intime >= a.admit_dt
    AND icue.outtime <= a.disch_dt + 1
    AND a.hadm_id is not null
    --and icue.subject_id between 1 and 50
)
--select * from icustays;
,icustay_population as (
  SELECT
    icue.subject_id,
    icue.icustay_id,
    icue.icustay_intime,
    icue.icustay_outtime,
    icud.begintime as icustay_day_intime,
    icud.endtime as icustay_day_outtime,
    icud.seq
  FROM icustays icue,
       mimic2v26.icustay_days icud
  WHERE icud.icustay_id = icue.icustay_id
  --and icud.subject_id between 1 and 50
)
--select * from icustay_population;
,Fio2 as (
  select i.subject_id, i.icustay_id,
         'FiO2' parameter,
         c.charttime as charttime,
         case 
            when itemid in (3420)
                then c.value1num / 100
           else c.value1num
         end as value
    from IcuStays i,
         mimic2v26.chartevents c
   where c.subject_id = i.subject_id
     and c.icustay_id = i.icustay_id
     and c.value1num is not null
     and (   (    c.itemid in (189, 190, 2981, 7570)                  -- FiO2
              and c.value1num >= 0.2
              and c.value1num <= 1.0
             )
          OR (    c.itemid = 3420   -- FiO2 %
              and c.value1num >= 20
              and c.value1num <= 100
             )
         )
    order by icustay_id, charttime
)
--select * from FiO2;
,Pao2 as (
  select i.subject_id, i.icustay_id, i.seq, i.icustay_day_intime, i.icustay_day_outtime,
         'PaO2' parameter,
         c.charttime as charttime,
         c.value1num as value
    from icustay_population i,
         mimic2v26.chartevents c
   where c.subject_id = i.subject_id
     and c.icustay_id = i.icustay_id
     and c.charttime >= i.icustay_day_intime
     and c.charttime < i.icustay_day_outtime
     and c.value1num is not null
     and (   (    c.itemid in (490, 779)   -- Pao2
              and c.value1num >= 40
              and c.value1num <= 500
             )
         )
)
--select * from Pao2 where subject_id = 3;
,Pao2Fio2Ratio as (
  /* Get the ratio of each pao2 value with the most recent prior fi02 */
  select distinct p.icustay_id, p.subject_id, p.seq,
         p.icustay_day_intime,
         p.icustay_day_outtime,
         p.charttime p_charttime, p.value as p_value,
         p.charttime - 1,
         p.value / first_value(f.value)
           over (partition by p.icustay_id, p.seq, p.charttime
                 order by f.charttime desc)
            as pao2_fio2_ratio
    from Pao2 p,
         Fio2 f
   where f.icustay_id = p.icustay_id
     and f.charttime <= p.charttime
     and f.charttime > (p.charttime - 1)
)
--select * from Pao2Fio2Ratio;
,p_f_daily_ratio as(
/* Get the minimum pao2/fio2 ratio for each day of ICU Stay */
select 
  subject_id,
  icustay_id,
  icustay_day_outtime,
  min (pao2_fio2_ratio) as p_f_ratio
from 
  Pao2Fio2Ratio
GROUP BY subject_id, icustay_id, icustay_day_outtime
)
--select * from p_f_daily_ratio;
-- Respiratory system failure: PaO2/FiO2 ratio
,ss_daily_raw_resp as (
select
  subject_id,
  20002 itemid,
  icustay_day_outtime charttime, -- CHARTTIME
  0 elemid, --ELEMID
  icustay_day_outtime realtime, -- REALTIME
  -1 cgid, -- CGID
  20001 cuid, -- CUID
  case when (p_f_ratio < 100) then 4
            when (p_f_ratio < 200) then 3
            when (p_f_ratio < 300) then 2
            when (p_f_ratio < 400) then 1
       else 0 end
  as value1num,
  null value1uom, -- VALUE1UOM
  icustay_id
from p_f_daily_ratio
)
select * from ss_daily_raw_resp;--64,221 rows inserted

-- Hepatic failure
INSERT INTO MERGE26.SOFA_SCORE (
  SUBJECT_ID,
  ITEMID,
  CHARTTIME,
  ELEMID,
  REALTIME,
  CGID,
  CUID,
  VALUE1NUM,
  VALUE1UOM,
  ICUSTAY_ID
)
With
icustays as (
  SELECT
    icue.subject_id,
    a.hadm_id,
    icue.icustay_id,
    icue.intime icustay_intime,
    icue.outtime icustay_outtime
  FROM mimic2v26.icustayevents icue,
       mimic2v26.d_patients p,
       mimic2v26.admissions a
  WHERE months_between(icue.intime, p.dob) / 12 >= 15
    AND p.subject_id = icue.subject_id
    AND a.subject_id = p.subject_id
    AND icue.intime >= a.admit_dt
    AND icue.outtime <= a.disch_dt + 1
    AND a.hadm_id is not null
    --and icue.subject_id between 1 and 50
),
icustay_population as (
  SELECT
    icue.subject_id,
    icue.icustay_id,
    icue.icustay_intime,
    icue.icustay_outtime,
    icud.begintime as icustay_day_intime,
    icud.endtime as icustay_day_outtime,
    icud.seq
  FROM icustays icue,
       mimic2v26.icustay_days icud
  WHERE icud.icustay_id = icue.icustay_id
)
--select * from icustay_population;
,
-- Liver (bilirubin) and Coagulation
ss_daily_raw_hepatic as (
  SELECT
    icud.subject_id,
    icud.icustay_id,
    icud.icustay_day_outtime,
    max(
    case
      when (le.valuenum >= 12) then 4
      when (le.valuenum >= 6 and le.valuenum<=11.9) then 3
      when (le.valuenum >= 2 and le.valuenum<= 5.9) then 2
      when (le.valuenum >= 1.2 and le.valuenum<= 1.9) then 1
      else 0
    end) as hepatic_score
  from
    icustay_population icud,
    mimic2v26.labevents le
  where le.subject_id = icud.subject_id
  AND le.icustay_id = icud.icustay_id
  AND le.charttime >= icud.icustay_day_intime
  AND le.charttime <= icud.icustay_day_outtime
  AND le.itemid in (50170)
  GROUP BY icud.subject_id, icud.icustay_id, icud.icustay_day_outtime
  ORDER BY icud.subject_id, icud.icustay_id
)
SELECT
  subject_id,
  20003 itemid,
  icustay_day_outtime charttime, -- CHARTTIME
  0 elemid, --ELEMID
  icustay_day_outtime realtime, -- REALTIME
  -1 cgid, -- CGID
  20001 cuid, -- CUID
  hepatic_score,
  null value1uom, -- VALUE1UOM
  icustay_id
FROM
  ss_daily_raw_hepatic;--31,690 rows inserted

-- Hematologic failure
INSERT INTO MERGE26.SOFA_SCORE (
  SUBJECT_ID,
  ITEMID,
  CHARTTIME,
  ELEMID,
  REALTIME,
  CGID,
  CUID,
  VALUE1NUM,
  VALUE1UOM,
  ICUSTAY_ID
)
With
icustays as (
  SELECT
    icue.subject_id,
    a.hadm_id,
    icue.icustay_id,
    icue.intime icustay_intime,
    icue.outtime icustay_outtime
  FROM mimic2v26.icustayevents icue,
       mimic2v26.d_patients p,
       mimic2v26.admissions a
  WHERE months_between(icue.intime, p.dob) / 12 >= 15
    AND p.subject_id = icue.subject_id
    AND a.subject_id = p.subject_id
    AND icue.intime >= a.admit_dt
    AND icue.outtime <= a.disch_dt + 1
    AND a.hadm_id is not null
),
icustay_population as (
  SELECT
    icue.subject_id,
    icue.icustay_id,
    icue.icustay_intime,
    icue.icustay_outtime,
    icud.begintime as icustay_day_intime,
    icud.endtime as icustay_day_outtime,
    icud.seq
  FROM icustays icue,
       mimic2v26.icustay_days icud
  WHERE icud.icustay_id = icue.icustay_id
),
-- Liver (bilirubin) and Coagulation
ss_raw_hema as (
  SELECT
    icud.subject_id,
    icud.icustay_id,
    icud.seq,
    icud.icustay_day_outtime,
    case 
      when le.valuenum < 20 then 4
      when le.valuenum < 50 then 3
      when le.valuenum < 100 then 2
      when le.valuenum < 150 then 1
      else 0
    end as hematologic_score
  from
    icustay_population icud,
    mimic2v26.labevents le
  where le.subject_id = icud.subject_id
  AND le.icustay_id = icud.icustay_id
  AND le.charttime >= icud.icustay_day_intime
  AND le.charttime <= icud.icustay_day_outtime
  AND le.itemid in (50428)
)
--select * from ss_raw_hema where subject_id = 21;
,ss_daily_raw_hema as (
  SELECT
    subject_id,
    icustay_id,
    seq,
    icustay_day_outtime,
    max(hematologic_score) as hematologic_score
  from
    ss_raw_hema
  GROUP BY subject_id, icustay_id, seq, icustay_day_outtime
)
--select * from ss_daily_raw_hema where subject_id = 21;
SELECT
  subject_id,
  20004 itemid,
  icustay_day_outtime charttime, -- CHARTTIME
  0 elemid, --ELEMID
  icustay_day_outtime realtime, -- REALTIME
  -1 cgid, -- CGID
  20001 cuid, -- CUID
  hematologic_score,
  null value1uom, -- VALUE1UOM
  icustay_id
FROM
  ss_daily_raw_hema;--121,115 rows inserted

--select * from merge26.sofa_score where itemid = 20004 order by subject_id, charttime;--115185
--select * from mimic2v26.chartevents where itemid = 20004 order by subject_id, charttime;--103684

-- Cardiovascular failure - Pressors
INSERT INTO MERGE26.SOFA_SCORE (
  SUBJECT_ID,
  ITEMID,
  CHARTTIME,
  ELEMID,
  REALTIME,
  CGID,
  CUID,
  VALUE1NUM,
  VALUE1UOM,
  ICUSTAY_ID
)
With
icustays as (
  SELECT
    icue.subject_id,
    a.hadm_id,
    icue.icustay_id,
    icue.intime icustay_intime,
    icue.outtime icustay_outtime
  FROM mimic2v26.icustayevents icue,
       mimic2v26.d_patients p,
       mimic2v26.admissions a
  WHERE months_between(icue.intime, p.dob) / 12 >= 15
    AND p.subject_id = icue.subject_id
    AND a.subject_id = p.subject_id
    AND icue.intime >= a.admit_dt
    AND icue.outtime <= a.disch_dt + 1
    AND a.hadm_id is not null
    --and icue.subject_id between 1 and 50
),
icustay_population as (
  SELECT
    icue.subject_id,
    icue.icustay_id,
    icue.icustay_intime,
    icue.icustay_outtime,
    icud.begintime as icustay_day_intime,
    icud.endtime as icustay_day_outtime,
    icud.seq
  FROM icustays icue,
       mimic2v26.icustay_days icud
  WHERE icud.icustay_id = icue.icustay_id
  --and icud.subject_id between 1 and 50
),
max_icustay_weight AS (
SELECT DISTINCT
  icud.subject_id,
  icud.icustay_id,
  MAX ( ce.value1num ) weight
FROM
  mimic2v26.chartevents ce,
  icustays icud
WHERE
  itemid         IN ( 580, 1393, 762, 1395 )
AND ce.subject_id = icud.subject_id
AND ce.icustay_id = icud.icustay_id
AND ce.value1num          IS NOT NULL
AND ce.value1num          >= 30 -- Arbitrary value to eliminate 0
GROUP BY
  icud.subject_id,
  icud.icustay_id
ORDER BY
  icud.icustay_id
),
-- Pressors, used in cardiovascular
ss_daily_raw_press as (
  SELECT
    icud.subject_id,
    icud.icustay_id,
    icud.seq,
    icud.icustay_day_outtime,
    max(case
      when ((me.itemid in (43,307) and (me.dose > 0 and me.dose <= 5)) or (me.itemid in (42,306) and me.dose > 0)) then 2
      when ((me.itemid in (43,307) and (me.dose > 5 and me.dose <= 15)) or (me.itemid in (44,119,309,47,120) and (me.dose > 0 and (me.dose/miw.weight) <= 0.1))) then 3
      when ((me.itemid in (43,307) and me.dose > 15) or (me.itemid in (44,119,309,47,120) and (me.dose/miw.weight) > 0.1)) then 4 
      else 0
      end
    ) as cardiovascular_score_pres
  FROM
    mimic2v26.medevents me,
    max_icustay_weight miw,
    icustay_population icud 
  where miw.icustay_id = icud.icustay_id
  AND me.subject_id = icud.subject_id
  AND me.icustay_id = icud.icustay_id
  AND me.charttime >= icud.icustay_day_intime
  AND me.charttime <= icud.icustay_day_outtime
  AND me.itemid in (43,307,42,306,44,119,309,47,120)
  GROUP BY icud.subject_id, icud.icustay_id, icud.seq, icud.icustay_day_outtime
)
--select * from ss_daily_raw_press where subject_id = 21;
SELECT
  subject_id,
  20005 itemid,
  icustay_day_outtime charttime, -- CHARTTIME
  0 elemid, --ELEMID
  icustay_day_outtime realtime, -- REALTIME
  -1 cgid, -- CGID
  20001 cuid, -- CUID
  cardiovascular_score_pres,
  null value1uom, -- VALUE1UOM
  icustay_id
FROM
  ss_daily_raw_press;--18,354 rows inserted

-- Cardiovascular score ABP
INSERT INTO MERGE26.SOFA_SCORE (
  SUBJECT_ID,
  ITEMID,
  CHARTTIME,
  ELEMID,
  REALTIME,
  CGID,
  CUID,
  VALUE1NUM,
  VALUE1UOM,
  ICUSTAY_ID
)
With
icustays as (
  SELECT
    icue.subject_id,
    a.hadm_id,
    icue.icustay_id,
    icue.intime icustay_intime,
    icue.outtime icustay_outtime
  FROM mimic2v26.icustayevents icue,
       mimic2v26.d_patients p,
       mimic2v26.admissions a
  WHERE months_between(icue.intime, p.dob) / 12 >= 15
    AND p.subject_id = icue.subject_id
    AND a.subject_id = p.subject_id
    AND icue.intime >= a.admit_dt
    AND icue.outtime <= a.disch_dt + 1
    AND a.hadm_id is not null
    --and p.subject_id < 10
)
--select * from icustays;
, icustay_population as (
  SELECT
    icue.subject_id,
    icue.icustay_id,
    icue.icustay_intime,
    icue.icustay_outtime,
    icud.begintime as icustay_day_intime,
    icud.endtime as icustay_day_outtime,
    icud.seq
  FROM icustays icue,
       mimic2v26.icustay_days icud
  WHERE icud.icustay_id = icue.icustay_id
  --and icud.subject_id between 1 and 50
)
--select * from icustay_population;
,min_daily_abp AS (
  SELECT
    icud.subject_id,
    icud.icustay_id,
    icud.icustay_day_outtime,
    MIN(ce.value1num) as min_daily_abp_val
  FROM icustay_population icud
  JOIN mimic2v26.chartevents ce
  ON (icud.subject_id = ce.subject_id and icud.icustay_id = ce.icustay_id)
  WHERE ce.itemid in (52,456)
  AND ce.charttime >= icud.icustay_day_intime
  AND ce.charttime <= icud.icustay_day_outtime
  AND   ce.value1num IS NOT NULL
  GROUP BY icud.subject_id, icud.icustay_id, icud.icustay_day_outtime
)
--select * from min_daily_abp;
-- ABP - used in cardiovascular
, ss_daily_raw_abp as (
  SELECT
    mda.subject_id,
    mda.icustay_id,
    mda.icustay_day_outtime,
    case
      when (mda.min_daily_abp_val < 70) then 1
      else 0
      end
    as cardiovascular_score_abp
  FROM
    min_daily_abp mda
)
--select * from ss_daily_raw_abp;
SELECT
  subject_id,
  20006 itemid,
  icustay_day_outtime charttime, -- CHARTTIME
  0 elemid, --ELEMID
  icustay_day_outtime realtime, -- REALTIME
  -1 cgid, -- CGID
  20001 cuid, -- CUID
  cardiovascular_score_abp,
  null value1uom, -- VALUE1UOM
  icustay_id
FROM
  ss_daily_raw_abp;--134,791 rows inserted

-- DELETE FROM MERGE26.SOFA_SCORE WHERE ITEMID = 20007;

-- Neurological failure (GCS)
INSERT INTO MERGE26.SOFA_SCORE (
  SUBJECT_ID,
  ITEMID,
  CHARTTIME,
  ELEMID,
  REALTIME,
  CGID,
  CUID,
  VALUE1NUM,
  VALUE1UOM,
  ICUSTAY_ID
)
With
icustays as (
  SELECT
    icue.subject_id,
    a.hadm_id,
    icue.icustay_id,
    icue.intime icustay_intime,
    icue.outtime icustay_outtime
  FROM mimic2v26.icustayevents icue,
       mimic2v26.d_patients p,
       mimic2v26.admissions a
  WHERE months_between(icue.intime, p.dob) / 12 >= 15
    AND p.subject_id = icue.subject_id
    AND a.subject_id = p.subject_id
    AND icue.intime >= a.admit_dt
    AND icue.outtime <= a.disch_dt + 1
    AND a.hadm_id is not null
    --and icue.subject_id between 1 and 50
)
--select * from icustays where subject_id = 21;
,icustay_population as (
  SELECT
    icue.subject_id,
    icue.icustay_id,
    icue.icustay_intime,
    icue.icustay_outtime,
    icud.begintime as icustay_day_intime,
    icud.endtime as icustay_day_outtime,
    icud.seq
  FROM icustays icue,
       mimic2v26.icustay_days icud
  WHERE icud.icustay_id = icue.icustay_id
  --and icud.subject_id between 1 and 50
)
--select * from icustay_population where subject_id = 21;
,
ss_raw_neuro as (
  SELECT
    icud.subject_id,
    icud.icustay_id,
    icud.seq,
    icud.icustay_day_outtime,
    ce.value1num,
    case 
      when (ce.value1num >= 13 and ce.value1num <= 14) then 1 
      when (ce.value1num >= 10 and ce.value1num <= 12) then 2 
      when (ce.value1num >= 6 and ce.value1num <= 9) then 3
      when (ce.value1num < 6) then 4
      else 0 end
    as neurological_score
  FROM
    mimic2v26.chartevents ce,
    icustay_population icud
  WHERE ce.subject_id = icud.subject_id
  AND ce.icustay_id = icud.icustay_id
  AND ce.charttime >= icud.icustay_day_intime
  AND ce.charttime <= icud.icustay_day_outtime
  AND ce.itemid = 198
)
--select * from ss_raw_neuro where subject_id = 21;
,ss_daily_raw_neuro as (
  SELECT
    subject_id,
    icustay_id,
    icustay_day_outtime,
    max(neurological_score) as neurological_score
  FROM
    ss_raw_neuro
  GROUP BY subject_id, icustay_id, icustay_day_outtime
)
--select * from ss_daily_raw_neuro where subject_id = 21;
SELECT
  subject_id,
  20007 itemid,
  icustay_day_outtime charttime, -- CHARTTIME
  0 elemid, --ELEMID
  icustay_day_outtime realtime, -- REALTIME
  -1 cgid, -- CGID
  20001 cuid, -- CUID
  neurological_score,
  null value1uom, -- VALUE1UOM
  icustay_id
FROM
  ss_daily_raw_neuro;--132,140 rows inserted

-- Renal failure creatinine or urine
INSERT INTO MERGE26.SOFA_SCORE (
  SUBJECT_ID,
  ITEMID,
  CHARTTIME,
  ELEMID,
  REALTIME,
  CGID,
  CUID,
  VALUE1NUM,
  VALUE1UOM,
  ICUSTAY_ID
)
With
icustays as (
  SELECT
    icue.subject_id,
    a.hadm_id,
    icue.icustay_id,
    icue.intime icustay_intime,
    icue.outtime icustay_outtime
  FROM mimic2v26.icustayevents icue,
       mimic2v26.d_patients p,
       mimic2v26.admissions a
  WHERE months_between(icue.intime, p.dob) / 12 >= 15
    AND p.subject_id = icue.subject_id
    AND a.subject_id = p.subject_id
    AND icue.intime >= a.admit_dt
    AND icue.outtime <= a.disch_dt + 1
    AND a.hadm_id is not null
    --and icue.subject_id between 1 and 50
)
--select * from icustays where subject_id = 21;
,icustay_population as (
  SELECT
    icue.subject_id,
    icue.icustay_id,
    icue.icustay_intime,
    icue.icustay_outtime,
    icud.begintime as icustay_day_intime,
    icud.endtime as icustay_day_outtime,
    icud.seq
  FROM icustays icue,
       mimic2v26.icustay_days icud
  WHERE icud.icustay_id = icue.icustay_id
  --and icud.subject_id between 1 and 50
)
--select * from icustay_population where subject_id = 21;
,
ss_raw_renal_creat as (
  SELECT
    icud.subject_id,
    icud.icustay_id,
    icud.seq,
    icud.icustay_day_outtime,
    'CREATININE',
    le.valuenum,
--    le.valueuom,
    case 
      when (le.valuenum >= 1.2 and le.valuenum < 2.0) then 1 
      when (le.valuenum >= 2.0 and le.valuenum < 3.5) then 2 
      when (le.valuenum >= 3.5 and le.valuenum < 5.0) then 3
      when (le.valuenum >= 5.0) then 4
      else 0 end
    as renal_score
  FROM
    mimic2v26.labevents le,
    icustay_population icud
  WHERE le.subject_id = icud.subject_id
  AND le.icustay_id = icud.icustay_id
  AND le.charttime >= icud.icustay_day_intime
  AND le.charttime <= icud.icustay_day_outtime
  AND le.itemid = 50090
)
--select * from ss_raw_renal_creat;--161
,
ss_raw_renal_urine as (
  SELECT
    icud.subject_id,
    icud.icustay_id,
    icud.seq,
    icud.icustay_day_outtime,
    'URINE',
    SUM(ie.volume),
    case 
      when (SUM(ie.volume) >= 200 and SUM(ie.volume) < 500) then 3
      when (SUM(ie.volume) <  200) then 4
      else 0 end
    as renal_score
  FROM
    mimic2v26.ioevents ie,
    icustay_population icud
  WHERE ie.subject_id = icud.subject_id
    AND ie.icustay_id = icud.icustay_id
    AND ie.charttime >= icud.icustay_day_intime
    AND ie.charttime <= icud.icustay_day_outtime
    AND ie.itemid IN ( 651, 715, 55, 56, 57, 61, 65, 69, 85, 94, 96, 288, 405, 428, 473, 2042, 2068, 2111, 2119, 2130, 1922, 2810, 2859, 3053, 3462, 3519, 3175, 2366, 2463, 2507, 2510, 2592, 2676, 3966, 3987, 4132, 4253, 5927 )
GROUP BY icud.subject_id, icud.icustay_id, icud.seq, icud.icustay_day_outtime, 'URINE'
)
--select * from ss_raw_renal_urine union select * from ss_raw_renal_creat;
, ss_daily_raw_renal as (
select
    subject_id,
    icustay_id,
    seq,
    icustay_day_outtime,
    MAX(renal_score) as renal_score
FROM (
      select * from ss_raw_renal_urine--122
      union
      select * from ss_raw_renal_creat
      )
GROUP BY subject_id, icustay_id, seq, icustay_day_outtime
)
--select * from ss_daily_raw_renal;
SELECT
  subject_id,
  20008 itemid,
  icustay_day_outtime charttime, -- CHARTTIME
  0 elemid, --ELEMID
  icustay_day_outtime realtime, -- REALTIME
  -1 cgid, -- CGID
  20001 cuid, -- CUID
  renal_score,
  null value1uom, -- VALUE1UOM
  icustay_id
FROM
  ss_daily_raw_renal;--134,571 rows inserted

SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID > 20001;--762118
SELECT * FROM MERGE26.SOFA_SCORE;--636882

INSERT INTO MIMIC2V26.D_CHARTITEMS (
  ITEMID,
  LABEL,
  CATEGORY,
  DESCRIPTION)
VALUES (
20008,
'Renal SOFA Score',
'LCP',
'Calculated SOFA score due to renal failure (Creatinine and Urine output) - by the MIMIC2 team'
);

DELETE FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID BETWEEN 20002 AND 20008;--625,755 rows deleted
-- Insert individual scores
INSERT INTO MIMIC2V26.CHARTEVENTS (
  subject_id,
  itemid,
  charttime,
  elemid,
  realtime,
  cgid,
  cuid,
  value1num,
  icustay_id
)
SELECT
  subject_id,
  itemid,
  charttime,
  elemid,
  realtime,
  cgid,
  cuid,
  value1num,
  icustay_id
FROM MERGE26.SOFA_SCORE;--636,882 rows inserted

SELECT * FROM MIMIC2V26.D_CHARTITEMS WHERE ITEMID > 20001;
SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID > 20001;
SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID > 20001 ORDER BY ICUSTAY_ID, ITEMID, CHARTTIME;

-- Insert total
INSERT INTO MIMIC2V26.D_CHARTITEMS (
  ITEMID,
  LABEL,
  CATEGORY,
  DESCRIPTION)
VALUES (
20009,
'Overall SOFA Score',
'LCP',
'Calculated SOFA score. Sum of sofa scores from individual organ systems (Sum of ITEMIDs 20002 - 20008) - by the MIMIC2 team'
);

DELETE FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID = 20009;

INSERT INTO MIMIC2V26.CHARTEVENTS (
 subject_id,
 itemid,
 charttime,
 elemid,
 realtime,
 cgid,
 cuid,
 value1num,
 icustay_id
 )
SELECT SUBJECT_ID, 20009, CHARTTIME, 0, CHARTTIME, -1, 20001, SUM(VALUE1NUM), ICUSTAY_ID
  FROM MERGE26.SOFA_SCORE
 GROUP BY SUBJECT_ID, 20009, CHARTTIME, 0, CHARTTIME, -1, 20001, ICUSTAY_ID
 ORDER BY SUBJECT_ID, ICUSTAY_ID;--137,118 rows inserted


SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID = 20009;

SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID > 20001 AND icustay_id = 4 ORDER BY ICUSTAY_ID, CHARTTIME, ITEMID;

SELECT * FROM MERGE26.SOFA_SCORE WHERE icustay_id = 4;

SELECT * FROM MIMIC2V26.ICUSTAY_DETAIL WHERE ICUSTAY_ID = 4;

SELECT COUNT(*) FROM MERGE26.OVERALL_SOFA_SCORE;--116930
SELECT COUNT(*) FROM MIMIC2V26.CHARTEVENTS;--159972807

INSERT INTO MIMIC2V26.D_CHARTITEMS (
  ITEMID,
  LABEL,
  CATEGORY,
  DESCRIPTION
) VALUES (
  20009,
  'Overall SOFA Score',
  'LCP',
  'Calculated SOFA overall score (Sum of individual system scores) - by the MIMIC2 team'
);

select * from mimic2v26.d_chartitems where itemid > 20002;

-- Compare with mimic2v26
select 'V2.5 - ' || itemid, count(*) from mimic2v26.chartevents where itemid >= 20002 GROUP BY itemid 
union
select 'V2.6 - ' || itemid, count(*) from mimic2v26.chartevents where itemid >= 20002 GROUP BY itemid ;

/*ss_daily_raw as (
  SELECT DISTINCT
    icud.subject_id,
    icud.icustay_id,
    icud.icustay_day,
    NVL(sdrl.hepatic_score,0) hepatic_score,
    NVL(sdrl.hematologic_score,0) hematologic_score,
    NVL(sdrc.cardiovascular_score_abp,0) cardiovascular_score_abp,
    NVL(sdrc.cardiovascular_score_pres,0) cardiovascular_score_pres,
    case
    when (NVL(sdrc.cardiovascular_score_abp,0) > NVL(sdrc.cardiovascular_score_pres,0)) then NVL(sdrc.cardiovascular_score_abp,0)
    else NVL(sdrc.cardiovascular_score_pres,0) end as cardiovascular_score,
    NVL(sdrn.neurologic_score,0) neurologic_score,
    NVL(sdrr.respiratory_score,0) respiratory_score
  FROM
    icustay_days icud
  FULL OUTER JOIN ss_daily_raw_lab sdrl
  ON (icud.icustay_id = sdrl.icustay_id AND icud.icustay_day = sdrl.icustay_day)
  FULL OUTER JOIN ss_daily_raw_cardio sdrc
  ON (icud.icustay_id = sdrc.icustay_id AND icud.icustay_day = sdrc.icustay_day)
  FULL OUTER JOIN ss_daily_raw_neuro sdrn
  ON (icud.icustay_id = sdrn.icustay_id AND icud.icustay_day = sdrn.icustay_day)
  FULL OUTER JOIN ss_daily_raw_resp sdrr
  ON (icud.icustay_id = sdrr.icustay_id AND icud.icustay_day = sdrr.icustay_day)
),
non_renal_daily_sofa_score as (
select
  sofa.subject_id,
  sofa.icustay_id,
  sofa.icustay_day,
  sofa.hepatic_score,
  sofa.hematologic_score,
  sofa.neurologic_score,
  --sofa.cardiovascular_score_abp,
  --sofa.cardiovascular_score_pres,
  sofa.cardiovascular_score,
  sofa.respiratory_score,
  sofa.respiratory_score + sofa.hepatic_score + sofa.hematologic_score + sofa.neurologic_score + sofa.cardiovascular_score as non_renal_score
from ss_daily_raw sofa
join icustay_days icud
on (icud.icustay_id = sofa.icustay_id and icud.icustay_day = sofa.icustay_day)
)
SELECT * FROM non_renal_daily_sofa_score;*/

--INSERT INTO MIMIC2V26.D_CHARTITEMS (ITEMID, LABEL, CATEGORY, DESCRIPTION) VALUES (20002, 'Respiratory SOFA Score', 'LCP', 'Calculated SOFA score due to respiratory failure (PaO2/FiO2 ratio) - by the MIMIC2 team');
--INSERT INTO MIMIC2V26.D_CHARTITEMS (ITEMID, LABEL, CATEGORY, DESCRIPTION) VALUES (20003, 'Hepatic SOFA Score', 'LCP', 'Calculated SOFA score due to hepatic failure (Bilirubin values) - by the MIMIC2 team');
--INSERT INTO MIMIC2V26.D_CHARTITEMS (ITEMID, LABEL, CATEGORY, DESCRIPTION) VALUES (20004, 'Hematologic SOFA Score', 'LCP', 'Calculated SOFA score due to hematologic failure (Platelet count) - by the MIMIC2 team');
--INSERT INTO MIMIC2V26.D_CHARTITEMS (ITEMID, LABEL, CATEGORY, DESCRIPTION) VALUES (20005, 'Pressor Cardiovascular SOFA Score', 'LCP', 'Calculated SOFA score due to cardiovascular failure (Pressors) - by the MIMIC2 team');
--INSERT INTO MIMIC2V26.D_CHARTITEMS (ITEMID, LABEL, CATEGORY, DESCRIPTION) VALUES (20006, 'MAP Cardiovascular SOFA Score', 'LCP', 'Calculated SOFA score due to cardiovascular failure (MAP) - by the MIMIC2 team');
--INSERT INTO MIMIC2V26.D_CHARTITEMS (ITEMID, LABEL, CATEGORY, DESCRIPTION) VALUES (20007, 'Neurologic SOFA Score', 'LCP', 'Calculated SOFA score due to neurologic failure (Glasgow coma score) - by the MIMIC2 team');
--
--SELECT subject_id, itemid, charttime, elemid, COUNT(*) FROM MERGE26.SOFA_SCORE GROUP BY subject_id, itemid, charttime, elemid HAVING COUNT(*) >1;
--
--select distinct itemid from MERGE26.SOFA_SCORE;
--select itemid, count(*) from MERGE26.SOFA_SCORE GROUP BY itemid;
--
--SELECT * FROM MERGE26.SOFA_SCORE WHERE SUBJECT_ID = 21;
--SELECT * FROM MERGE26.SOFA_SCORE WHERE ITEMID IN (20007) AND SUBJECT_ID = 21;
--SELECT * FROM MERGE26.SOFA_SCORE WHERE ITEMID IN (20005, 20006) AND SUBJECT_ID = 21;
--
--SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ICUSTAY_ID = 24;
--SELECT * FROM MIMIC2V26.ICUSTAYEVENTS WHERE ICUSTAY_ID = 24;
--SELECT * FROM MIMIC2V26.ICUSTAY_DAYS WHERE ICUSTAY_ID = 24;
--
--INSERT INTO MIMIC2V26.CHARTEVENTS SELECT * FROM MERGE26.SOFA_SCORE;
--
--SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID IN (20002, 20003, 20004, 20005, 20006, 20007);
----DELETE FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID IN (20002, 20003, 20004, 20005, 20006, 20007);
--SELECT * FROM MIMIC2V26.CHARTEVENTS WHERE ITEMID IN (20007) AND SUBJECT_ID = 21;

