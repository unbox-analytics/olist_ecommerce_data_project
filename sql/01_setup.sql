-- one time steps to setup and organize files
USE olist_data;

-- schemas are created to hold the data as it passes through the ETL process
CREATE SCHEMA raw -- no modification of this data
CREATE SCHEMA stg; -- staging
CREATE SCHEMA clean; -- cleaned data ready for analysis
CREATE SCHEMA error; -- data with error flags
CREATE SCHEMA audit; -- audit log

-- create audit table to hold information about each run
create table audit.etl_runs(
    run_id int identity(1,1),
    table_name varchar(50),
    rows_loaded int,
    rows_rejected int,
    load_datetime datetime default getdate()
);

-----  PRODUCTS TABLE ------
-- creating staging tables without data
select * 
into stg.products 
from raw.products
where 1=0

-- creating error table without data
select * 
into error.products 
from raw.products
where 1=0

alter table error.products
add 
flag_duplicates bit default 0,
flag_null_product bit default 0,
flag_category_not_found bit default 0,
flag_invalid_weight bit default 0,
flag_invalid_length bit default 0,
flag_invalid_height bit default 0,
flag_invalid_width bit default 0

-- creating clean table without data
select * 
into clean.products 
from raw.products
where 1=0




