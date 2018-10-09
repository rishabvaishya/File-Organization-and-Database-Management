create database fodm_project;
use fodm_project;


drop table programming_languages;
create table programming_languages
(
language_name varchar(20) primary key,
language_status ENUM('current', 'future')
);

drop table software_products;
create table software_products
(
name varchar(40),
version varchar(40),
software_status ENUM('Ready', 'not-ready', 'usable') not null default 'not-ready',
primary key(name,version)
);


drop table Employees;
create table Employees
(
emp_id int primary key,
name varchar(30),
hire_date timestamp,
mgr_id int,
seniority varchar(10)
);


drop table Components;
create table Components
(
comp_id int auto_increment,
component_name varchar(30),
version varchar(10),
component_size int,
prog_language varchar(20),
comp_owner int,
comp_status ENUM('Ready', 'not-ready', 'usable') not null default 'not-ready',
primary key(component_name, version),
FOREIGN KEY (prog_language) REFERENCES programming_languages(language_name),
FOREIGN KEY (comp_owner) REFERENCES Employees(emp_id),
key (comp_id)
);

drop table software_product_built;
create table software_product_built
(
name varchar(40),
version varchar(40),
comp_id int,
primary key(name,version, comp_id),
FOREIGN KEY (name, version) REFERENCES software_products(name, version),
FOREIGN KEY (comp_id) REFERENCES Components(comp_id)
);


drop table Inspection;
create table Inspection
(
inspection_id int primary key auto_increment,
component_name varchar(30),
version varchar(10),
inspection_date timestamp not null,
by_who int,
score int not null,
description varchar(4000),
status ENUM('Ready', 'not-ready', 'usable') not null default 'not-ready',
FOREIGN KEY (by_who) REFERENCES Employees(emp_id),
FOREIGN KEY (component_name, version) REFERENCES Components(component_name, version),
key (inspection_id)
);


drop procedure employeeManagerValidation;
Delimiter $$
CREATE PROCEDURE employeeManagerValidation(in mgr_id int,in emp_id int)
begin
	DECLARE count_occ INT;
    if (emp_id = 10100) then 
		set mgr_id = mgr_id;
        if (mgr_id != 10100 or mgr_id != null) then
			signal sqlstate '45000'
			set message_text = 'The CEO can not have a subordinate as a manager or enter his own id or null as his manager.';
        end if;
    else
		begin
			if (emp_id = mgr_id) then
				signal sqlstate '45000'
				set message_text = 'An employee cannot be his own manager';
            end if;
			SET count_occ = (select count(id) from Employees where Employees.id = mgr_id group by Employees.id);
            if (count_occ = 0) then
				signal sqlstate '45000'
				set message_text = 'Manager should be an existing employee';
            end if;
		end;
    end if;
end;
$$
delimiter ;

drop trigger employee_manager_validation_insert;
delimiter $$
create trigger employee_manager_validation_insert
BEFORE INSERT on Employees
for each row
begin
	call employeeManagerValidation(mgr_id,new.emp_id);
end;
$$
delimiter ;


drop trigger employee_manager_validation_update;
delimiter $$
create trigger employee_manager_validation_update
BEFORE Update on Employees
for each row
begin
	call employeeManagerValidation(mgr_id,new.emp_id);
end;
$$
delimiter ;

drop procedure updateComponentsStatus;

Delimiter $$
CREATE PROCEDURE updateComponentsStatus (IN component_name varchar(30), IN version varchar(10), IN status varchar(10),IN score int)
BEGIN
   
	DECLARE id int;
if (score >90 ) then
		set status = 'ready';
	else if (score < 75) then
		set status = 'not-ready';
	else
		set status = 'usable';
	end if;
    end if;
   update Components set Components.comp_status = status where Components.component_name = component_name and Components.version = version;
   set id = (select comp_id from Components where Components.component_name = component_name and Components.version = version);
   CALL updateSoftwareProductStatus(id);
END $$
Delimiter ;

drop trigger inspection_status_insert;
delimiter $$
create trigger inspection_status_insert 
after insert on Inspection
for each row
begin
	
	 CALL updateComponentsStatus(new.component_name, new.version, new.status,new.score);
end;
$$
delimiter ;

drop trigger inspection_status_update;
delimiter $$
create trigger inspection_status_update
after update on Inspection
for each row
begin
	 CALL updateComponentsStatus(new.component_name, new.version, new.status, new.score);
end;
$$
delimiter ;

drop procedure updateSoftwareProductStatus;

Delimiter $$
CREATE PROCEDURE updateSoftwareProductStatus (IN id int)
BEGIN

	DECLARE current_streak int;
    DECLARE rowcount int;
	DECLARE Name VARCHAR(40);
    DECLARE Version VARCHAR(40);
    DECLARE updatedone int default 0;
	DECLARE cur CURSOR FOR SELECT software_product_built.name,software_product_built.version FROM software_product_built where comp_id = id;
    DECLARE continue handler for sqlstate '02000' set updatedone = 1;

	set current_streak=0;
    open cur;
	select FOUND_ROWS() into rowcount ;
    
    start_loop: loop
		if updatedone=1 then
			leave start_loop;
		end if;
        
        fetch cur into Name,Version;
		set current_streak = current_streak +1;
        
		if ((select count(*) from Components where Components.comp_status like 'not-ready' and Components.comp_id in (SELECT software_product_built.comp_id  FROM software_product_built where software_product_built.name = Name and software_product_built.version = Version))>0 ) then
			update software_products set software_products.software_status = 'not-ready' where software_products.name = name and software_products.version = version;
		
		else if ((select count(*) from Components where Components.comp_status like 'usable' and Components.comp_id in (SELECT software_product_built.comp_id  FROM software_product_built where software_product_built.name = Name and software_product_built.version = Version))>0 ) then
			update software_products set software_products.software_status = 'usable' where software_products.name = name and software_products.version = version;
       
		else 
			update software_products set software_products.software_status = 'ready' where software_products.name = name and software_products.version = version;
		end if;
        end if;
        
        if (current_streak<=rowcount) then
			leave start_loop;
		end if;
     
    end loop;
    close cur;
	
END $$
Delimiter ;


 SET GLOBAL event_scheduler = ON;
-- Triggers for Employees
-- Seniority
drop event seniority_update
delimiter $$
CREATE EVENT seniority_update
ON SCHEDULE
EVERY 1 day
DO
BEGIN
    
	DECLARE current_streak int;
    DECLARE rowcount int;
    Declare hire_date timestamp;
    Declare id int;
    Declare date_diff int;
	DECLARE seniority_temp VARCHAR(10);
    DECLARE updateDone INT DEFAULT 0;
	DECLARE cur CURSOR FOR SELECT id, hire_date from employees;
	-- DECLARE EXIT HANDLER FOR NOT FOUND    
	DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET updateDone = 1;
    
	set current_streak=0;
    open cur;
	select FOUND_ROWS() into rowcount ;

	insert into logger values(10);
    
    start_loop: loop
        IF updateDone =1 THEN
            LEAVE start_loop;
        END IF;
        
        fetch cur into id, hire_date;
        
		set current_streak = current_streak +1;
		set date_diff = ((UNIX_TIMESTAMP(current_date()) - UNIX_TIMESTAMP(hire_date))/60/60/24);
		
        if (day_diff < 365) then
			update Employees set seniority = 'newbie' where Employees.id = id;
		else if (day_diff > 365 and day_diff < 1825) then
			update Employees set seniority = 'junior' where Employees.id = id;
		else if (day_diff > 1825) then
			update Employees set seniority = 'senior' where Employees.id = id;
		end if;
		end if;
		end if;
    
        
        if (current_streak<=rowcount) then
			leave start_loop;
		end if;
     
    end loop;
    close cur;
            
END 
$$
delimiter ;


-- Triggers on Employee Seniority 
-- Insert
drop trigger employee_seniority_update
delimiter $$
create trigger employee_seniority_update 
before insert on employees
for each row
begin
	DECLARE day_diff INT;
    set day_diff = ((UNIX_TIMESTAMP(current_date()) - UNIX_TIMESTAMP(new.hire_date))/60/60/24);
    if (day_diff < 365) then
		set new.seniority = 'newbie';
    else if (day_diff > 365 and day_diff < 1825) then
		set new.seniority = 'junior';
	else if (day_diff > 1825) then
		set new.seniority = 'senior';
    end if;
    end if;
    end if;
end;
$$
delimiter ;

describe employee_seniority_update;
describe seniority_update;
describe updateSoftwareProductStatus;
describe inspection_status_update;
describe inspection_status_insert;
describe updateComponentsStatus;
describe employeeManagerValidation;
describe employee_manager_validation_insert;
describe employee_manager_validation_update;

-- Insert Programming languages
insert into programming_languages values('C','current');
insert into programming_languages values('C++','current');
insert into programming_languages values('C#','current');
insert into programming_languages values('Java','current');
insert into programming_languages values('PHP','current');
insert into programming_languages values('Python','Future');
insert into programming_languages values('assembly','Future');



-- Insert Into Employees
insert into employees(emp_id, name, hire_date, mgr_id) values(10100, 'Employee-1', STR_TO_DATE( '08/11/1984', '%m/%d/%Y'), null);
insert into employees(emp_id, name, hire_date, mgr_id) values(10200, 'Employee-2', STR_TO_DATE( '08/11/1994', '%m/%d/%Y'),10100);
insert into employees(emp_id, name, hire_date, mgr_id) values(10300, 'Employee-3', STR_TO_DATE( '08/11/2004', '%m/%d/%Y'),10200);
insert into employees(emp_id, name, hire_date, mgr_id) values(10400, 'Employee-4', STR_TO_DATE( '01/11/2008', '%m/%d/%Y'),10200);
insert into employees(emp_id, name, hire_date, mgr_id) values(10500, 'Employee-5', STR_TO_DATE( '01/11/2015', '%m/%d/%Y'),10400);
insert into employees(emp_id, name, hire_date, mgr_id) values(10600, 'Employee-6', STR_TO_DATE( '01/11/2015', '%m/%d/%Y'),10400);
insert into employees(emp_id, name, hire_date, mgr_id) values(10700, 'Employee-7', STR_TO_DATE( '01/11/2016', '%m/%d/%Y'),10400);
insert into employees(emp_id, name, hire_date, mgr_id) values(10800, 'Employee-8', STR_TO_DATE( '01/11/2017', '%m/%d/%Y'),10200);


truncate Components;
select * from Components;
-- Insert into Components
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(1, 'Keyboard Driver', 'K11', 1200, 'C', 10100);
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(2, 'Touch Screen Driver', 'T00', 4000, 'C++', 10100);
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(3, 'Dbase Interface', 'D00', 2500, 'C++', 10200);
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(4, 'Dbase Interface', 'D01', 2500,'C++', 10300);
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(5, 'Chart generator', 'C11', 6500, 'java', 10200);
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(6, 'Pen Driver', 'P01', 3575, 'C', 10700);
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(7, 'Math unit', 'A01', 5000, 'C', 10200);
insert into Components(comp_id, component_name, version, component_size, prog_language, comp_owner) values(8, 'Math unit', 'A02', 3500, 'Java', 10200);


-- Insert into Software Products
insert into software_products(name, version) values('Excel', '2010');
insert into software_products(name, version) values('Excel', '2015');
insert into software_products(name, version) values('Excel', '2018beta');
insert into software_products(name, version) values('Excel', 'secret');


-- Insert into Components in Software
insert into software_product_built values('Excel', '2010', 1);
insert into software_product_built values('Excel', '2010', 3);
insert into software_product_built values('Excel', '2015', 1);
insert into software_product_built values('Excel', '2015', 4);
insert into software_product_built values('Excel', '2015', 6);
insert into software_product_built values('Excel', '2018beta', 1);
insert into software_product_built values('Excel', '2018beta', 2);
insert into software_product_built values('Excel', '2018beta', 5);
insert into software_product_built values('Excel', 'secret', 1);
insert into software_product_built values('Excel', 'secret', 2);
insert into software_product_built values('Excel', 'secret', 5);
insert into software_product_built values('Excel', 'secret', 8);

select * from software_products;
describe software_products;
select * from Components;
describe Components;
select * from programming_languages;
describe programming_languages;
select * from software_product_built;
describe software_product_built;
select * from employees;
describe employees;
select * from inspection;
describe inspection;

truncate inspection;

-- insert into Inspection
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(1, 'Keyboard Driver', 'K11', STR_TO_DATE('02/14/2010', '%m/%d/%Y'), 10100, 100, 'legacy code which is already approved');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(2, 'Touch Screen Driver', 'T00', STR_TO_DATE('06/01/2017', '%m/%d/%Y'), 10200, 95, 'initial release ready for usage');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(3, 'Dbase Interface', 'D00', STR_TO_DATE('02/22/2010', '%m/%d/%Y'), 10100, 55, 'too many hard coded parameters, the software must be more maintainable and configurable because we want to use this in other products.');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(4, 'Dbase Interface', 'D00', STR_TO_DATE('02/24/2010', '%m/%d/%Y'), 10100, 78, 'improved, but only handles DB2 format');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(5, 'Dbase Interface', 'D00', STR_TO_DATE('02/26/2010', '%m/%d/%Y'), 10100, 95, 'Okay, handles DB3 format.');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(6, 'Dbase Interface', 'D00', STR_TO_DATE('02/28/2010', '%m/%d/%Y'), 10100, 100, 'satisfied');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(7, 'Dbase Interface', 'D01', STR_TO_DATE('05/01/2011', '%m/%d/%Y'), 10200, 100, 'Okay ready for use');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(8, 'Pen Driver', 'P01', STR_TO_DATE('07/15/2017', '%m/%d/%Y'), 10300, 80, 'Okay ready for beta testing');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(9, 'Math unit', 'A01', STR_TO_DATE('06/10/2014', '%m/%d/%Y'), 10100, 90, 'almost ready');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(10, 'Math unit', 'A02', STR_TO_DATE('06/15/2014', '%m/%d/%Y'), 10100, 70, 'Accuracy problems!');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(11, 'Math unit', 'A02', STR_TO_DATE('06/30/2014', '%m/%d/%Y'), 10100, 100, 'Okay problems fixed');
insert into inspection(inspection_id, component_name, version, inspection_date, by_who, score, description) values(12, 'Math unit', 'A02', STR_TO_DATE('11/02/2016', '%m/%d/%Y'), 10700, 100, 're-review for new employee to gain experience in the process.');