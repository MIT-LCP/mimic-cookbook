-- # 1.	Trivial R example calculation of mean height

--#create view containing heights
drop view height_only_in;
create view height_only_in 
as select "VALUE1NUM"
from "MIMIC2V26"."chartevents" 
where "ITEMID" = 920 and "VALUE1NUM" is not null and "VALUE1NUM" > 0 and "VALUE1NUM" < 500;

--#single row to contain mean
drop table output;
create table output(MEAN INTEGER);

--#create SQL-script function including R script
drop procedure avg_height;
create procedure avg_height(IN input1 height_only_in, OUT result output)
language RLANG as
begin
result <- as.data.frame(mean(input1$VALUE1NUM));
names(result) <- c("MEAN");
end;

--#execute SQL-script function and retrieve result
call avg_height (height_only_in, output) with OVERVIEW;
select * from output;

