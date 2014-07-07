/*
  saps_create_24hr_minmax.sql

  Created on   : September 2009 by Mauricio Villarroel
  Last updated :
     $Author: djscott@ECG.MIT.EDU $
     $Date: 2010-11-04 15:36:31 -0400 (Thu, 04 Nov 2010) $
     $Rev: 123 $

 Valid for MIMIC II database schema version 2.5
 
 Creates the minimum and maximum values for each of the SAPS I parameters
 for the first 24hr of each ICUStay for adult patients.
 
*/


--delete from merge25.SAPS_SCORE;
--
--delete from merge25.SAPS_DAILY_PARAM;
--
--INSERT INTO merge25.SAPS_DAILY_PARAM
--     (SUBJECT_ID, ICUSTAY_ID, CALC_DT, CATEGORY,
--      MIN_VAL, MIN_VAL_SCORE,
--      MAX_VAL, MAX_VAL_SCORE, PARAM_SCORE)
-- Find the score for min/max value for each parameter
-- and choose the highest saps as the parameter representative
WITH ICUstays as (
  select subject_id, icustay_id, dob, icustay_intime as intime,
         icustay_outtime as outtime,
         icustay_admit_age as age
    from mimic2v26.icustay_detail
   where icustay_age_group = 'adult'
     --and subject_id in (13, 17, 21, 41, 61, 68, 91, 109, 377, 4412, 21369)
     --and subject_id in (13)
)
--select * from ICUstays;
, DailyICUStays as (
  SELECT subject_id, icustay_id, icustay_day,
         intime, outtime, age
    FROM ICUstays
    MODEL RETURN UPDATED ROWS
    PARTITION BY (subject_id, icustay_id)
    DIMENSION BY (0 icustay_day)
    MEASURES (intime, outtime, dob, age)
    RULES ITERATE(1000)
        UNTIL (ITERATION_NUMBER > trunc(outtime[0] - intime[0]) - 1)
    --RULES ITERATE(icustay_daysnum)
    (
      intime[ITERATION_NUMBER + 1] = intime[0] + ITERATION_NUMBER,
      -- Make sure we stay within the time bounds of the ICU stay
      outtime[ITERATION_NUMBER + 1] = 
            case 
             when (intime[0] + ITERATION_NUMBER + 1 > outtime[0])
               then outtime[0]
             else   intime[0] + ITERATION_NUMBER + 1
            end,
      age[ITERATION_NUMBER + 1] = 
        round(months_between(intime[ITERATION_NUMBER + 1], dob[0]) / 12, 0)
    )  
    order by subject_id, icustay_id, intime
)
select * from DailyICUStays;
, ChartedParams as (
  -- Group each c.itemid in meaninful category names
  -- also performin some metric conversion (temperature, etc...)
  select s.subject_id, s.icustay_id, s.icustay_day,
         s.outtime as calc_dt,
         case 
            when c.itemid in (211) then
                'HR'
            when c.itemid in (676, 677, 678, 679) then
                'TEMPERATURE'    
            when c.itemid in (51, 455) then
                'SYS ABP'    -- Invasive/noninvasive BP 
            when c.itemid in (781) then 
                'BUN'
            when c.itemid in (198) then 
                'GCS'
         end category,
         case
            when c.itemid in (678, 679) then
               (5/9)*(c.value1num-32)
            else
               c.value1num
         end valuenum
    from DailyICUStays s,
         mimic2v26.chartevents c
   where c.subject_id = s.subject_id
     and c.itemid in (
         211,
         676, 677, 678, 679,
         51,455,
         781,
         198)
     and c.charttime >= s.intime
     and c.charttime < s.outtime
     and c.value1num is not null
)
, VentilatedRespParams as (
  select distinct s.subject_id, s.icustay_id, s.icustay_day,
         s.outtime as calc_dt,
         'VENTILATED_RESP' as category,
         -1 as valuenum -- force invalid number
    from DailyICUStays s,
         mimic2v26.chartevents c
   where c.subject_id = s.subject_id
     and c.itemid in (543, 544, 545, 619, 39, 535, 683, 720, 721, 722, 732)
     and c.charttime >= s.intime
     and c.charttime < s.outtime
),
SpontaneousRespParams as (
  -- Group each c.itemid in meaninful category names
  -- also performin some metric conversion (temperature, etc...)
  select s.subject_id, s.icustay_id, s.icustay_day,
         s.outtime as calc_dt,
         'SPONTANEOUS_RESP' as category,
         c.value1num as valuenum
    from DailyICUStays s,
         mimic2v26.chartevents c
   where c.subject_id = s.subject_id
     and c.itemid in (
         615, 618) -- 3603 was for NICU, 614 spontaneous useless
     and c.charttime >= s.intime
     and c.charttime < s.outtime
     and c.value1num is not null
     and not exists (select 'X' 
                       from VentilatedRespParams nv
                      where nv.icustay_id = s.icustay_id
                        and nv.calc_dt = s.outtime)
)
, LabParams as (
  -- Group each c.itemid in meaninful category names
  -- also performin some metric conversion (temperature, etc...)
  select s.subject_id, s.icustay_id, s.icustay_day,
         s.outtime as calc_dt,
         case 
            when c.itemid in (50383)
              then 'HCT'
            when c.itemid in (50316, 50468)    
              then 'WBC'
            when c.itemid in (50112)
              then 'GLUCOSE'
            when c.itemid in (50172)
              then 'HCO3' -- 'TOTAL CO2'
            when c.itemid in (50149) then 
                'POTASSIUM'              
            when c.itemid in (50159) then 
                'SODIUM'              
         end category,
         c.valuenum
    from DailyICUStays s,
         mimic2v26.labevents c
   where c.subject_id = s.subject_id
     and c.itemid in (
         50383,
         50316, 50468,
         50112,
         50172,
         50149,
         50159
         )
     and c.charttime >= s.intime
     and c.charttime < s.outtime
     and c.valuenum is not null
)
, AgeParams as (
  -- The age (in years) at the admission day 
  select subject_id, icustay_id,  icustay_day, outtime as calc_dt,
         'AGE' as category, age as valuenum
    from DailyICUStays
),
UrineParams as (
  select s.subject_id, s.icustay_id, s.icustay_day,
         s.outtime as calc_dt,
         'URINE' as category,
         sum(c.volume)/1000 as valuenum
    from DailyICUStays s,
         mimic2v26.ioevents c
   where c.subject_id = s.subject_id
     and c.itemid IN ( 651, 715, 55, 56, 57, 61, 65, 69, 85, 94, 96, 288, 405, 428, 473, 2042, 2068, 2111, 2119, 2130, 1922, 2810, 2859, 3053, 3462, 3519, 3175, 2366, 2463, 2507, 2510, 2592, 2676, 3966, 3987, 4132, 4253, 5927 )
     and c.charttime >= s.intime
     and c.charttime < s.outtime
     and c.volume is not null
   GROUP BY s.subject_id, s.icustay_id, s.icustay_day, s.outtime
),
CombinedParams as (
  select subject_id, icustay_id, icustay_day, calc_dt, category, valuenum
    from ChartedParams
  UNION
  select subject_id, icustay_id, icustay_day, calc_dt, category, valuenum
    from VentilatedRespParams
  UNION
  select subject_id, icustay_id, icustay_day, calc_dt, category, valuenum
    from SpontaneousRespParams
  UNION
  select subject_id, icustay_id, icustay_day, calc_dt, category, valuenum
    from AgeParams
  UNION
  select subject_id, icustay_id, icustay_day, calc_dt, category, valuenum
    from UrineParams
  UNION
  select subject_id, icustay_id, icustay_day, calc_dt, category, valuenum
    from LabParams    
),
MinMaxValues as (
  -- find the min and max values for each category and calc_dt
  select subject_id, icustay_id, icustay_day, calc_dt, category,
         min(valuenum) min_valuenum, max(valuenum) max_valuenum
   from CombinedParams
  GROUP BY subject_id, icustay_id, icustay_day, calc_dt, category
)
, CalcSapsParams as (
  -- find the min and max values for each category and calc_dt
  select subject_id, icustay_id, icustay_day, calc_dt, category,
         min_valuenum,
         merge25.get_saps_for_parameter(category, min_valuenum)
            as min_valuenum_score,
         max_valuenum,
         merge25.get_saps_for_parameter(category, max_valuenum)
            as max_valuenum_score
   from MinMaxValues
)
select subject_id, icustay_id, calc_dt, category,
       min_valuenum, min_valuenum_score, max_valuenum, max_valuenum_score,
       case 
          when min_valuenum_score >= max_valuenum_score then 
              min_valuenum_score
          else
              max_valuenum_score
       end as param_score   
  from CalcSapsParams
 order by subject_id, icustay_id, category, calc_dt;  

-- Calculate the SAPS score for every patient record
INSERT INTO merge25.SAPS_SCORE
      (SUBJECT_ID, ICUSTAY_ID, calc_dt,
       SCORE, PARAM_COUNT)
select d.subject_id, d.icustay_id, d.calc_dt,
       SUM(param_score) SAPS_SCORE,
       count(*) param_count
  from merge25.SAPS_DAILY_PARAM D
 where d.param_score is not null
   and d.param_score >= 0
 group by d.subject_id, d.icustay_id, d.calc_dt;


-- Insert the values into chartevents
/*
delete from mimic2v26.chartevents
 where itemid = 20001;

insert into mimic2v26.chartevents(
            subject_id, itemid, charttime, elemid,
            realtime,  cgid, cuid, value1num)
     select subject_id, 20001, calc_dt, 1,
            calc_dt,  -1, 20001, score
       from merge25.SAPS_SCORE
      where param_count = 14;            
*/