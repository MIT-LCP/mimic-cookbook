-- # 3.	Death prediction with SVM
 
--Create the table that contains all the information and features that we want for our prediction algorithm
--Note that we create the column 'training' where training examples are selected at random. 1 means it's for training, 0 for testing.
drop table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES";
create column table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES" as (
   	select "icud"."ICUSTAY_ID" ,
          	"icud"."DOB" ,
          	"icud"."DOD" ,
          	"icud"."HOSPITAL_ADMIT_DT" ,
          	"icud"."ICUSTAY_ADMIT_AGE" "age",
          	"icud"."WEIGHT_FIRST" ,
          	"icud"."WEIGHT_MIN" ,
          	"icud"."WEIGHT_MAX" ,
          	"icud"."SAPSI_FIRST",
          	"icud"."SOFA_FIRST",
   	map("icud"."GENDER",'F',0,'M',1) "gender",
   	map("icud"."DOD",null,0,1) DEAD,
   	1-floor(rand()/0.75) "training"
   	from "MIMIC2V26"."icustay_detail" "icud"
   	where "icud"."WEIGHT_FIRST" is not null and
          	"icud"."WEIGHT_MIN" is not null and
          	"icud"."WEIGHT_MAX" is not null and
          	"icud"."SAPSI_FIRST" is not null and
          	"icud"."SOFA_FIRST" is not null and
          	"icud"."GENDER" is not null
);
alter table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES" add (CPREDICT nvarchar(10), CPROB decimal);
 
 
-- Create a procedure that will train and predict.
-- This could be split into two different procedure, one for training the other one for testing.
drop procedure "MIMIC2V26"."PROC_DEATH_TRAIN_PREDICT";
create procedure "MIMIC2V26"."PROC_DEATH_TRAIN_PREDICT" (in input1 "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES",
	in input2 "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES",
	out output1 "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES" )
language RLANG as
begin
   	library("kernlab");
   	library("RODBC");
 
   	myconn <-odbcConnect("hana", uid="SYSTEM", pwd="HANA4ever");
 
   	input_training <- input1 ;
   	meta_cols <- c("DOB", "DOD", "HOSPITAL_ADMIT_DT", "DEAD", "training", "CPREDICT", "CPROB" ) ;
   	x_train <- data.matrix(input_training[-match(meta_cols, names(input_training))]) ;
   	y_train <- input_training$DEAD ;
   	model <- ksvm(x_train, y_train, type = "C-bsvc", kernel = "rbfdot", kpar = list(sigma = 0.1), C = 10, prob.model = TRUE);
   	
   	input_test <- input2;
   	x_test <- input_test[-match(meta_cols, names(input_test))];
 
   	prob_matrix <- predict(model, x_test, type="probabilities");
 
   	clabel <- apply(prob_matrix, 1, which.max);
   	cprob <- apply(prob_matrix, 1, max);
   	classlabels = colnames(prob_matrix);
   	clabel <- classlabels[clabel];
 
   	output1 <- input2;
   	output1$CPREDICT <- clabel;
   	output1$CPROB <- cprob;
 
end;
 
 
-- Create the table for training. Subset of the main table.
drop table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_TRAIN";
create column table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_TRAIN" as (
   	select * from "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES" where "training" = 1
);
select count(*) from "MIMIC2V26"."MIMIC.PREDICTION::DEATH_PREDICTION";
 
-- Create the table for testing. Subset of the main table.
drop table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_PREDICTION";
create column table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_PREDICTION" as (
   	select * from "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES" where "training" = 0
);
 
drop table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_OUTPUT";
create column table "MIMIC2V26"."MIMIC.PREDICTION::DEATH_OUTPUT" like "MIMIC2V26"."MIMIC.PREDICTION::DEATH_FEATURES";

call "MIMIC2V26"."PROC_DEATH_TRAIN_PREDICT"("MIMIC2V26"."MIMIC.PREDICTION::DEATH_TRAIN", "MIMIC2V26"."MIMIC.PREDICTION::DEATH_PREDICTION","MIMIC2V26"."MIMIC.PREDICTION::DEATH_OUTPUT") with overview;
 
 
select 1-sum(abs(DEAD - CPREDICT))/count(*) from "MIMIC2V26"."MIMIC.PREDICTION::DEATH_OUTPUT";
 

