select distinct doses_per_24hrs, dose_val_rx

from mimic2v26.poe_order,mimic2v26.poe_med

where mimic2v26.poe_order.poe_id=mimic2v26.poe_med.poe_id

AND lower(mimic2v26.poe_order.medication) like
'%insulin%'

AND lower(mimic2v26.poe_med.drug_name_generic) like
'%insulin%';

-- Find the first ICU admission

select * from

 (select  min(intime) over (partition by subject_id) as min_intime,
ie.*  from  icustayevents ie)

where  min_intime = intime
