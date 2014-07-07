select bucket+15, count(*) from (
       select months_between(ad.adm_dt, dp.dob)/12, width_bucket(months_between(ad.adm_dt, dp.dob)/12, 15, 100, 85) as bucket from mimic2v26.admissions ad, mimic2v26.d_patients dp where ad.subject_id = dp.subject_id and months_between(ad.adm_dt, dp.dob)/12 between 15 and 199
       ) group by bucket order by bucket;
