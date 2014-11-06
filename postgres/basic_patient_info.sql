select subject_id, sex, dob
  from mimic2v25.d_patients
 where rownum < 10