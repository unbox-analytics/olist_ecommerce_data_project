

    CREATE OR ALTER PROCEDURE stg.usp_load_products
    AS
    BEGIN

        SET NOCOUNT ON;
            DECLARE @rows_loaded INT = 0, @rows_rejected INT = 0;
            BEGIN TRY
                BEGIN TRANSACTION;
                TRUNCATE TABLE stg.products;
                TRUNCATE TABLE error.products;
                TRUNCATE TABLE clean.products;
                -- creates staging customers table

                DECLARE @batch_id INT = (SELECT ISNULL(MAX(run_id), 0) + 1 FROM audit.etl_runs);
                INSERT INTO stg.products
                (
                    product_id,
                    product_category_name,
                    product_name_length,
                    product_description_length,
                    product_photos_qty,
                    product_weight_g,
                    product_length_cm,
                    product_height_cm,
                    product_width_cm,
                    load_datetime,
                    source_file,
                    batch_id
                )
                SELECT
                    product_id,
                    product_category_name,
                    product_name_lenght as product_name_length,
                    product_description_lenght as product_description_length,
                    product_photos_qty,
                    product_weight_g,
                    product_length_cm,
                    product_height_cm,
                    product_width_cm,
                    getdate() as load_datetime,
                    'product.csv' as source_file,
                    @batch_id
                FROM raw.products;

                -- creates Temporary table to identofy errors
                drop table if exists #validations;
                ;WITH V as (
                    SELECT * , 
                    ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS row_num 
                FROM stg.products
                ),
                validations as (
                    select 
                    product_id,
                    product_category_name,
                    product_name_length,
                    product_description_length,
                    product_photos_qty,
                    product_weight_g,
                    product_length_cm,
                    product_height_cm,
                    product_width_cm,
                    Nullif(
                        concat(
                        case when product_category_name is null then 'Product category name is null; ' end,
                        case when product_id is null then 'Product id is null; ' end,
                        case when product_weight_g < 0 then 'Product weight is negative; ' end,
                        case when product_length_cm < 0 then 'Product length is negative; ' end,
                        case when product_height_cm < 0 then 'Product height is negative; ' end,
                        case when row_num > 1 then 'Duplicate product; ' end,
                        case when product_width_cm < 0 then 'Product width is negative; ' end),
                        '')as error_flags,
                    load_datetime,
                    source_file,
                    batch_id
                from v
                )   select * into #validations
                    from validations;

-- insert error records into error table
                INSERT INTO error.products(
                    product_id,
                    product_category_name,
                    product_name_length,
                    product_description_length,
                    product_photos_qty,
                    product_weight_g,
                    product_length_cm,
                    product_height_cm,
                    product_width_cm,
                    error_flags,
                    load_datetime,
                    source_file,
                    batch_id
                )
                SELECT 
                    product_id,
                    product_category_name,
                    product_name_length,
                    product_description_length,
                    product_photos_qty,
                    product_weight_g,
                    product_length_cm,
                    product_height_cm,
                    product_width_cm,
                    error_flags,
                    load_datetime,
                    source_file,
                    batch_id
                    FROM #validations
                    WHERE error_flags IS NOT NULL;
            SET @rows_rejected = @@ROWCOUNT;

-- insert clean records into clean table
                    INSERT INTO clean.products (
                        product_id, product_category_name,
                        product_name_length,          -- fixed typo
                        product_description_length,   -- fixed typo
                        product_photos_qty,
                        product_weight_g, product_length_cm, product_height_cm, product_width_cm,
                        load_datetime,
                        batch_id
                    )
                    SELECT
                        product_id, product_category_name,
                        product_name_length, product_description_length, product_photos_qty,
                        product_weight_g, product_length_cm, product_height_cm, product_width_cm,load_datetime,
                        batch_id
                    FROM #validations
                    WHERE error_flags IS NULL;
                    SET @rows_loaded = @@ROWCOUNT;

                drop table #validations;
                    -- Audit success
                    INSERT INTO audit.etl_runs
                    (table_name, rows_loaded, rows_rejected, status, error_message)
                    VALUES
                    (
                        'products', @rows_loaded, @rows_rejected, 'SUCCESS', NULL
                    );
            COMMIT TRANSACTION;
            END TRY

            BEGIN CATCH

                IF @@TRANCOUNT > 0 
                    ROLLBACK TRANSACTION;

                INSERT INTO audit.etl_runs
                (
                    table_name,
                    rows_loaded,
                    rows_rejected,
                    status,
                    error_message
                )
                VALUES
                (
                    'products',
                    0,
                    0,
                    'FAILED',
                    ERROR_MESSAGE()
                );

                THROW
            END CATCH
    END;
