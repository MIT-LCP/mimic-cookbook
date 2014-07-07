select subject_id, sex, dob
  from mimic2v26.d_patients
 where rownum < 10