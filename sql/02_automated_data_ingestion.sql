
select * from raw.customers
GO

CREATE OR ALTER PROCEDURE stg.usp_load_customers
AS
BEGIN
    SET NOCOUNT ON;
        DECLARE @rows_loaded INT = 0, @rows_rejected INT = 0;

        BEGIN TRY
            BEGIN TRANSACTION
            -- creates staging customers table
            TRUNCATE TABLE stg.customers;
            INSERT INTO stg.customers SELECT * FROM raw.customers;

            -- creates error table 
            ;WITH V as (
                SELECT * , ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS row_num 
            FROM stg.customers
            )
            INSERT INTO error.customers(
                customer_id, 
                customer_unique_id, 
                customer_zip_code_prefix,
                customer_city, 
                customer_state,
                flag_duplicate_row
            )
            SELECT 
                customer_id, 
                customer_unique_id, 
                customer_zip_code_prefix,
                customer_city, 
                customer_state,
                CASE WHEN row_num > 1 THEN 1 ELSE 0 END AS flag_duplicate_row
            FROM V WHERE row_num > 1;
        
         SET @rows_rejected = @@ROWCOUNT;

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
            THROW;
        END CATCH
END;
GO
