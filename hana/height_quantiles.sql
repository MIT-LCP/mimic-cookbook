-- # 2.	Quantile of Heights

drop view height_only_in;
create view height_only_in 
as SELECT "VALUE1NUM"
from "MIMIC2V26"."chartevents" 
where "ITEMID" = 492 and "VALUE1NUM" is not null and "VALUE1NUM" > 0 and "VALUE1NUM" < 500;

drop table output;
create column table output(ZERO INTEGER, PERCENT25 integer, PERCENT50 integer, PERCENT75 integer, PERCENT100 integer);

--#create SQL-script function including R script
DROP PROCEDURE avg_height;
CREATE PROCEDURE avg_height(IN input1 height_only_in, OUT result output)
LANGUAGE RLANG AS
BEGIN
result <- as.data.frame(t(quantile(input1$VALUE1NUM)));
names(result) <- c("ZERO","PERCENT25","PERCENT50","PERCENT75","PERCENT100");
END;

--#execute SQL-script function and retrieve result
CALL avg_height (height_only_in, output) WITH OVERVIEW;
SELECT * FROM output;

