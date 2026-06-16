-- one time steps to setup and organize files
USE olist_data;

-- schemas are created to hold the data as it passes through the ETL process
    CREATE SCHEMA raw; -- no modification of this data
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
-- creating staging tables without data
    -- product table
        select product_id,
                product_category_name,
                product_name_lenght as product_name_length, -- correct typo
                product_description_lenght as product_description_length,  -- correct typo
                product_photos_qty, 
                product_weight_g,
                product_length_cm,
                product_height_cm,
                product_width_cm
            into stg.products 
            from raw.products
            where 1=0
    
    -- customer table
        drop table if exists stg.customers;
        select *, row_number() over (partition by customer_id order by customer_id) as row_num into stg.customers from raw.customers
        where 1=0;

        insert into stg.customers
            select  customer_id, 
                customer_unique_id, 
                customer_zip_code_prefix, 
                customer_city, 
                customer_state, 
                row_number() over (partition by customer_id order by customer_id) as row_num
            from raw.customers

    -- orders table
    -- order_items table
    -- order_reviews table
    -- order_payments table
    -- sellers table



    -- creating error table without data

    select * 
    into error.products 
    from stg.products
    where 1=0
    -- add columns to record errors
    alter table error.products
    add 
    flag_error bit default 0,
    error_description varchar(100)

    -- creating clean table without data
    drop table if exists clean.products; 

    select * 
    into clean.products 
    from stg.products
    where 1=0

    -- loading raw data into staging table
    insert into stg.products
    select * from raw.products 

-- Data Quality checks
-- product_category_name should not be null
insert into error.products(
    product_id, 
    product_category_name, 
    product_name_length, 
    product_description_length, 
    product_photos_qty, 
    product_weight_g, 
    product_length_cm, 
    product_height_cm, 
    product_width_cm, 
    flag_error,
    error_description
    )
select     product_id, 
    product_category_name, 
    product_name_length, 
    product_description_length, 
    product_photos_qty, 
    product_weight_g, 
    product_length_cm, 
    product_height_cm, 
    product_width_cm, 
    1, 
    'Product category name is null' 
from stg.products
where product_category_name is null 

select * from error.products


-- data quality checks
-- product id should not be null
-- product category name should exist in the category table. if null it should be renamed to undefined
-- product category name in english should be pulled into the staging table, brazillian name dropped
-- if product category name is > 0 then len product name should be used instead
-- photos quantity null shpuld be flagged
-- no description should be flagged
-- weight length height width should be non null

