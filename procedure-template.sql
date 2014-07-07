----------- create table types
create or replace force type column_t as object 
(
SUBJECT_ID	NUMBER(7,0),
HADM_ID	        NUMBER(7,0),
SEQUENCE	NUMBER(7,0),
CODE	        VARCHAR2(100 BYTE),
DESCRIPTION	VARCHAR2(255 BYTE)
);

create or replace type icd9set_t as table of column_t;

--------- create dynamic function
create or replace function return_table(q_subject_id in ICD9.SUBJECT_ID%type)
return icd9set_t as
  v_ret   icd9set_t;
begin
  select 
  cast(
  multiset(
    select * from icd9 where subject_id=q_subject_id)
    as icd9set_t)
    into
      v_ret
    from 
      dual;

  return v_ret;
  
end return_table;

------------ testing query
select * from table(return_table(44));

