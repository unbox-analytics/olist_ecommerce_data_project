-- one time steps to setup and organize files
USE olist_data;

-- schemas are created to hold the data as it passes through the ETL process
    CREATE SCHEMA raw; -- no modification of this data
    CREATE SCHEMA stg; -- staging
    CREATE SCHEMA clean; -- cleaned data ready for analysis
    CREATE SCHEMA error; -- data with error flags
    CREATE SCHEMA audit; -- audit log
-- create audit table to hold information about each run
    drop table if exists audit.etl_runs; 
    create table audit.etl_runs(
        run_id int identity(1,1),
        table_name varchar(50),
        rows_loaded int,
        rows_rejected int,
        load_datetime datetime default getdate(),
        status VARCHAR(20),
        error_message VARCHAR(4000)
    );

-- creating staging tables and inserting data from raw
    -- product table
        drop table if exists stg.products;
        CREATE TABLE stg.products
        (
        product_id VARCHAR(32) NOT NULL,
        product_category_name VARCHAR(50),
        product_name_length INT,
        product_description_length INT,
        product_photos_qty INT,
        product_weight_g INT,
        product_length_cm INT,
        product_height_cm INT,
        product_width_cm INT,

        load_datetime DATETIME NOT NULL DEFAULT GETDATE(),
        source_file VARCHAR(255),
        batch_id INT
        );
        drop table if exists clean.products;
        CREATE TABLE clean.products
        (
            product_id VARCHAR(32) NOT NULL,
            product_category_name VARCHAR(50),
            product_name_length INT,
            product_description_length INT,
            product_photos_qty INT,
            product_weight_g INT,
            product_length_cm INT,
            product_height_cm INT,
            product_width_cm INT,

            load_datetime DATETIME NOT NULL,
            batch_id INT,

            CONSTRAINT PK_clean_products
                PRIMARY KEY (product_id)
        );
        
        drop table if exists error.products;
        CREATE TABLE error.products
        (
            product_id VARCHAR(32),
            product_category_name VARCHAR(50),
            product_name_length INT,
            product_description_length INT,
            product_photos_qty INT,
            product_weight_g INT,
            product_length_cm INT,
            product_height_cm INT,
            product_width_cm INT,

            error_flags VARCHAR(500),

            load_datetime DATETIME NOT NULL,
            source_file VARCHAR(255),
            batch_id INT
        );



    -- customer table
        drop table if exists stg.customers;
        CREATE TABLE stg.customers
        (
            customer_id VARCHAR(32) NOT NULL,
            customer_unique_id VARCHAR(32) NOT NULL,
            customer_zip_code_prefix CHAR(5),
            customer_city VARCHAR(100),
            customer_state CHAR(2),

            load_datetime DATETIME NOT NULL DEFAULT GETDATE(),
            source_file VARCHAR(255),
            batch_id INT
        );

    -- orders table
        drop table if exists stg.orders;
        CREATE TABLE stg.orders
        (
        order_id VARCHAR(32) NOT NULL,
        customer_id VARCHAR(32) NOT NULL,
        order_status VARCHAR(20),
        order_purchase_timestamp DATETIME,
        order_approved_at DATETIME,
        order_delivered_carrier_date DATETIME,
        order_delivered_customer_date DATETIME,
        order_estimated_delivery_date DATETIME,

        load_datetime DATETIME NOT NULL DEFAULT GETDATE(),
        source_file VARCHAR(255),
        batch_id INT
        );


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

