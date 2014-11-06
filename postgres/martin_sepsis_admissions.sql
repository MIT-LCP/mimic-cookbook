DROP TABLE MIMIC2DEVEL.MARTIN_SEPSIS_ADMISSIONS;
CREATE MATERIALIZED VIEW MIMIC2DEVEL.MARTIN_SEPSIS_ADMISSIONS AS
WITH
  cohort_sepsis AS
  (
    SELECT DISTINCT
      subject_id,
      hadm_id
    FROM
      mimic2v26.icd9
    WHERE
      code LIKE '038%'
    OR code LIKE '020.0%'
    OR code LIKE '790.7%'
    OR code LIKE '117.9%'
    OR code LIKE '112.5%'
    OR code LIKE '112.81%'
  )
  --select * from cohort_sepsis;
  ,
  cohort_sepsis_and_organ_fail AS
  (
    SELECT DISTINCT
      cs.subject_id,
      cs.hadm_id
    FROM
      cohort_sepsis cs
    LEFT JOIN mimic2v26.icd9 i
    ON
      cs.hadm_id=i.hadm_id
    LEFT JOIN mimic2v26.procedureevents p
    ON
      cs.hadm_id=p.hadm_id
    WHERE
      i.code IN ('518.81','518.82','518.85','786.09','785.51','785.59','780.01'
      ,'780.09')
    OR i.code LIKE '799.1%'
    OR i.code LIKE '458.0%'
    OR i.code LIKE '785.5%'
    OR i.code LIKE '458.8%'
    OR i.code LIKE '458.9%'
    OR i.code LIKE '796.3%'
    OR i.code LIKE '584%'
    OR i.code LIKE '580%'
    OR i.code LIKE '585%'
    OR i.code LIKE '570%'
    OR i.code LIKE '572.2%'
    OR i.code LIKE '573.3%'
    OR i.code LIKE '286.2%'
    OR i.code LIKE '286.6%'
    OR i.code LIKE '286.9%'
    OR i.code LIKE '287.3%'
    OR i.code LIKE '287.4%'
    OR i.code LIKE '287.5%'
    OR i.code LIKE '276.2%'
    OR i.code LIKE '293%'
    OR i.code LIKE '348.1%'
    OR i.code LIKE '348.3%'
    OR p.itemid IN
      (
        SELECT DISTINCT
          itemid
        FROM
          mimic2v26.d_codeditems
        WHERE
          (
            code LIKE '967%'
          OR code LIKE '3995%'
          OR code LIKE '8914%'
          )
        AND type='PROCEDURE'
      )
  )
SELECT
  *
FROM
  cohort_sepsis_and_organ_fail;

GRANT SELECT ON MIMIC2DEVEL.MARTIN_SEPSIS_ADMISSIONS TO MIMIC_PUBLIC_USERS;
