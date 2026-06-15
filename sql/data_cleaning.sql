USE Olist;
GO

select * from raw.products
select * from customers
Select * from geolocation
select * from sellers
select * from payments
select * from orders
select * from order_reviews
select * from order_items
select * from category_name

-- Creating schemas
create schema raw;
create schema stg;
create schema clean;
create schema error;
create schema audit;

-- creating audit table
CREATE TABLE audit.etl_runs
(
    run_id INT IDENTITY(1,1),
    table_name VARCHAR(50),
    rows_loaded INT,
    rows_rejected INT,
    load_datetime DATETIME DEFAULT GETDATE()
);

-- creating raw ---> stg ---> error ---> clean
SELECT *
FROM INFORMATION_SCHEMA.TABLES
where table_name like '%products'

-- creating staging tables without data
select * 
into stg.products 
from raw.products
where 1=0

-- creating error table without data and adding descriptive error columns

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

-- load data into staging table
truncate table stg.products

insert into stg.products
select * from raw.products

--********* ERROR TABLE ************
truncate table error.products;
with validation_cte as (
    select *, 
    ROW_NUMBER() over(partition by product_id order by product_id) as row_num from stg.products
)
Insert into error.products (
       [product_id]
      ,[product_category_name]
      ,[product_name_lenght]
      ,[product_description_lenght]
      ,[product_photos_qty]
      ,[product_weight_g]
      ,[product_length_cm]
      ,[product_height_cm]
      ,[product_width_cm]
      ,[flag_duplicates]
      ,[flag_null_product]
      ,[flag_category_not_found]
      ,[flag_invalid_weight]
      ,[flag_invalid_length]
      ,[flag_invalid_height]
      ,[flag_invalid_width]
)
select 
       [product_id]
      ,[product_category_name]
      ,[product_name_lenght]
      ,[product_description_lenght]
      ,[product_photos_qty]
      ,[product_weight_g]
      ,[product_length_cm]
      ,[product_height_cm]
      ,[product_width_cm],
        CASE WHEN row_num > 1 THEN 1 ELSE 0 END as flag_duplicates,
        CASE WHEN product_id is null THEN 1 ELSE 0 END as flag_null_product,
        CASE WHEN product_category_name is null THEN 1 ELSE 0 END as flag_category_not_found,
        CASE WHEN product_weight_g <=0 THEN 1 ELSE 0 END as flag_invalid_weight,
        CASE WHEN product_length_cm <=0 THEN 1 ELSE 0 END as flag_invalid_length,
        CASE WHEN product_height_cm <=0 THEN 1 ELSE 0 END as flag_invalid_height,
        CASE WHEN product_width_cm <=0 THEN 1 ELSE 0 END as flag_invalid_width
from validation_cte
where row_num > 1
or product_id is null
or product_category_name is null
OR product_weight_g <=0
OR product_length_cm <=0
OR product_height_cm <=0
OR product_width_cm <=0;

--********* CLEAN TABLE ************

select * 
into clean.products
from raw.products
where 0=1;

with validation_cte as (
    select *, 
    ROW_NUMBER() over(partition by product_id order by product_id) as row_num from stg.products
)
Insert into clean.products (
       [product_id]
      ,[product_category_name]
      ,[product_name_lenght]
      ,[product_description_lenght]
      ,[product_photos_qty]
      ,[product_weight_g]
      ,[product_length_cm]
      ,[product_height_cm]
      ,[product_width_cm]
)
select 
       [product_id]
      ,[product_category_name]
      ,[product_name_lenght]
      ,[product_description_lenght]
      ,[product_photos_qty]
      ,[product_weight_g]
      ,[product_length_cm]
      ,[product_height_cm]
      ,[product_width_cm]
from validation_cte
where row_num = 1
AND product_id is not null
AND product_category_name is not null
AND product_weight_g >0
AND product_length_cm >0
AND product_height_cm >0
AND product_width_cm >0;

select * from clean.products







CREATE OR ALTER PROCEDURE stg.usp_load_products
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @rows_loaded INT = 0, @rows_rejected INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Stage
        TRUNCATE TABLE stg.products;
        INSERT INTO stg.products SELECT * FROM raw.products;

        -- Error table
        TRUNCATE TABLE error.products;
        ;WITH v AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS row_num
            FROM stg.products
        )
        INSERT INTO error.products (
            product_id, product_category_name,
            product_name_lenght, product_description_lenght, product_photos_qty,
            product_weight_g, product_length_cm, product_height_cm, product_width_cm,
            flag_duplicates, flag_null_product, flag_category_not_found,
            flag_invalid_weight, flag_invalid_length, flag_invalid_height, flag_invalid_width
        )
        SELECT
            product_id, product_category_name,
            product_name_lenght, product_description_lenght, product_photos_qty,
            product_weight_g, product_length_cm, product_height_cm, product_width_cm,
            CASE WHEN row_num > 1 THEN 1 ELSE 0 END,
            CASE WHEN product_id IS NULL THEN 1 ELSE 0 END,
            CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END,
            CASE WHEN product_weight_g <= 0 THEN 1 ELSE 0 END,
            CASE WHEN product_length_cm <= 0 THEN 1 ELSE 0 END,
            CASE WHEN product_height_cm <= 0 THEN 1 ELSE 0 END,
            CASE WHEN product_width_cm <= 0 THEN 1 ELSE 0 END
        FROM v
        WHERE row_num > 1 OR product_id IS NULL OR product_category_name IS NULL
           OR product_weight_g <= 0 OR product_length_cm <= 0
           OR product_height_cm <= 0 OR product_width_cm <= 0;

        SET @rows_rejected = @@ROWCOUNT;

        -- Clean table (fix typo column names here)
        TRUNCATE TABLE clean.products;
        ;WITH v AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS row_num
            FROM stg.products
        )
        INSERT INTO clean.products (
            product_id, product_category_name,
            product_name_length,          -- fixed typo
            product_description_length,   -- fixed typo
            product_photos_qty,
            product_weight_g, product_length_cm, product_height_cm, product_width_cm
        )
        SELECT
            product_id, product_category_name,
            product_name_lenght, product_description_lenght, product_photos_qty,
            product_weight_g, product_length_cm, product_height_cm, product_width_cm
        FROM v
        WHERE row_num = 1 AND product_id IS NOT NULL AND product_category_name IS NOT NULL
          AND product_weight_g > 0 AND product_length_cm > 0
          AND product_height_cm > 0 AND product_width_cm > 0;

        SET @rows_loaded = @@ROWCOUNT;

        -- Audit success
        INSERT INTO audit.etl_runs (table_name, rows_loaded, rows_rejected)
        VALUES ('products', @rows_loaded, @rows_rejected);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        -- Audit failure
        INSERT INTO audit.etl_runs (table_name, rows_loaded, rows_rejected)
        VALUES ('products', -1, -1);  -- -1 signals a failed run

        THROW;  -- re-raise so the caller knows it failed
    END CATCH;
END;