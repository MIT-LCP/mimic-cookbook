--SQL QUERY for BroadSpectrum IV Antimicrobials Given for at least 2 hours
-- Contributed by Jenna Wiens
SELECT
hadm_id,
drug,
start_dt,
stop_dt
FROM
MIMIC2V30.POE_MED_ORDER   
where (stop_dt-start_dt)>='0 2:00:00' and
(
lower(drug) like '%ampicillin-sulbactam%' or
lower(drug) like '%amoxicillin-clavulanic%' or
lower(drug) like '%amikacin%' or
lower(drug) like '%augmentin suspension%' or
lower(drug) like '%azithromycin%' or
lower(drug) like '%aztreonam%' or
lower(drug) like '%bactrim%' or
lower(drug) like '%cefepime%' or
lower(drug) like '%cefixime%' or
lower(drug) like '%cefotaxime %' or
lower(drug) like '%cefotetan%' or
lower(drug) like '%cefoxitin%' or
lower(drug) like '%cefpodoxime %' or
lower(drug) like '%ceftazidime%' or
lower(drug) like '%ceftriaxone%'or
lower(drug) like '%cefuroxime%' or
lower(drug) like '%ciprofloxacin%' or
lower(drug) like '%clarithromycin%' or
lower(drug) like '%clindamycin%' or
lower(drug) like '%colistin%' or
lower(drug) like '%daptomycin%' or
lower(drug) like '%doxycycline %' or
lower(drug) like '%ertapenem%' or
lower(drug) like '%erythromycin%' or
lower(drug) like '%gatifloxacin%' or
lower(drug) like '%gentamicin%' or
lower(drug) like '%imipenem%' or
lower(drug) like '%levofloxacin%' or
lower(drug) like '%linezolid%' or
lower(drug) like '%meropenem%' or
lower(drug) like '%metronidazole%' or
lower(drug) like '%minocycline%' or
lower(drug) like '%moxifloxacin%' or
lower(drug) like '%piperacillin%' or
lower(drug) like '%quinupristin%' or
lower(drug) like '%synercid%' or
lower(drug) like '%tetracycline%' or
lower(drug) like '%tigecycline%' or
lower(drug) like '%timentin%' or
lower(drug) like '%tobramycin%' or
lower(drug) like '%trimethoprim%' or
lower(drug) like '%unasyn%' or
lower(drug) like '%vancomycin%'	
) 
and
(route='IV' or route='IV DRIP')
