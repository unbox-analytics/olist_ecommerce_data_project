"""
============================================================
 Olist ETL Pipeline — products table
 Automated data cleaning pipeline in Python
 Mirrors the SQL pipeline: raw → staging → error → clean
 with audit logging and transaction-safe writes.
============================================================

HOW TO RUN
----------
1. Install dependencies:
       pip install pandas pyodbc sqlalchemy python-dotenv

2. Create a .env file next to this script:
       DB_SERVER=your_server_name
       DB_NAME=Olist
       DB_DRIVER=ODBC Driver 17 for SQL Server

3. Run:
       python olist_etl_pipeline.py

The pipeline will:
  - Load raw.products from SQL Server
  - Validate and flag bad rows
  - Write flagged rows  → error.products
  - Write clean rows    → clean.products
  - Log every run       → audit.etl_runs
"""

# ============================================================
# STEP 1 — IMPORTS & CONFIGURATION
# ============================================================
# We use:
#   pandas      — dataframe manipulation (the workhorse)
#   sqlalchemy  — database connection & write-back
#   pyodbc      — low-level SQL Server driver (used by sqlalchemy)
#   dotenv      — keeps credentials out of source code
#   logging     — structured run logs to console + file

import os
import logging
import traceback
from datetime import datetime

import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# Load .env file so credentials never live in code
load_dotenv()

# ── Logging setup ──────────────────────────────────────────
# Logs go to both console and a daily log file.
# Every run is timestamped so you can diagnose failures later.
log_filename = f"etl_products_{datetime.now().strftime('%Y%m%d')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    handlers=[
        logging.StreamHandler(),            # console
        logging.FileHandler(log_filename),  # file
    ],
)
log = logging.getLogger(__name__)

# ── Database config ────────────────────────────────────────
# Credentials come from environment variables, not hardcoded.
# Change DB_DRIVER to match your installed ODBC driver version.
DB_SERVER = os.getenv("DB_SERVER", "localhost")
DB_NAME   = os.getenv("DB_NAME",   "Olist")
DB_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server")

CONNECTION_STRING = (
    f"mssql+pyodbc://{DB_SERVER}/{DB_NAME}"
    f"?driver={DB_DRIVER.replace(' ', '+')}"
    f"&trusted_connection=yes"       # Windows auth — replace with user/pass if needed
)

# Table routing — all schema.table names in one place.
# If you rename a schema, change it here only.
TABLE_RAW   = "raw.products"
TABLE_STG   = "stg.products"
TABLE_ERROR = "error.products"
TABLE_CLEAN = "clean.products"
TABLE_AUDIT = "audit.etl_runs"


# ============================================================
# STEP 2 — DATABASE CONNECTION
# ============================================================
# SQLAlchemy's create_engine() creates a connection pool.
# We call it once and reuse the engine throughout the pipeline.
# fast_executemany=True speeds up bulk INSERTs significantly.

def get_engine():
    """Create and return a SQLAlchemy engine."""
    log.info("Connecting to database: %s / %s", DB_SERVER, DB_NAME)
    engine = create_engine(
        CONNECTION_STRING,
        fast_executemany=True,   # batch inserts — much faster for large tables
        echo=False,              # set True to print every SQL statement (debugging)
    )
    # Test the connection immediately so failures are obvious
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    log.info("Connection successful.")
    return engine


# ============================================================
# STEP 3 — EXTRACT (raw → staging dataframe)
# ============================================================
# We read raw.products into a pandas DataFrame — this is your
# in-memory "staging layer". No transformations yet; just a
# faithful copy of what's in the database.

def extract(engine) -> pd.DataFrame:
    """Read raw.products into a DataFrame."""
    log.info("Extracting from %s ...", TABLE_RAW)
    query = f"SELECT * FROM {TABLE_RAW}"
    df = pd.read_sql(query, engine)
    log.info("Extracted %d rows, %d columns.", len(df), len(df.columns))
    return df


# ============================================================
# STEP 4 — VALIDATE (add flag columns)
# ============================================================
# This is the heart of the pipeline. We add one boolean column
# per validation rule — identical logic to the SQL CASE WHEN
# flags — then derive a master `is_valid` flag.
#
# Validation rules:
#   flag_duplicates         — product_id appears more than once
#   flag_null_product       — product_id is NULL
#   flag_category_not_found — product_category_name is NULL
#   flag_invalid_weight     — product_weight_g <= 0 or NULL
#   flag_invalid_length     — product_length_cm <= 0 or NULL
#   flag_invalid_height     — product_height_cm <= 0 or NULL
#   flag_invalid_width      — product_width_cm <= 0 or NULL

def validate(df: pd.DataFrame) -> pd.DataFrame:
    """Add flag columns; return the annotated DataFrame."""
    log.info("Running validation checks ...")

    # ── duplicate detection ──────────────────────────────
    # duplicated() marks every occurrence after the first as True.
    # keep='first' mirrors ROW_NUMBER() > 1 in SQL.
    df["flag_duplicates"] = df.duplicated(subset=["product_id"], keep="first")

    # ── null checks ──────────────────────────────────────
    df["flag_null_product"]       = df["product_id"].isna()
    df["flag_category_not_found"] = df["product_category_name"].isna()

    # ── numeric range checks ─────────────────────────────
    # fillna(0) treats NULL dimensions as invalid (<=0 fails).
    # This is a deliberate choice — a product with no weight
    # recorded is as bad as one with weight = -1.
    for col, flag in [
        ("product_weight_g",  "flag_invalid_weight"),
        ("product_length_cm", "flag_invalid_length"),
        ("product_height_cm", "flag_invalid_height"),
        ("product_width_cm",  "flag_invalid_width"),
    ]:
        df[flag] = df[col].fillna(0) <= 0

    # ── master validity flag ──────────────────────────────
    # A row is valid only if NONE of the flags are True.
    flag_cols = [
        "flag_duplicates", "flag_null_product", "flag_category_not_found",
        "flag_invalid_weight", "flag_invalid_length",
        "flag_invalid_height", "flag_invalid_width",
    ]
    df["is_valid"] = ~df[flag_cols].any(axis=1)

    # ── summary report ───────────────────────────────────
    total    = len(df)
    valid    = df["is_valid"].sum()
    invalid  = total - valid
    log.info("Validation complete: %d valid | %d rejected out of %d total.", valid, invalid, total)

    # Per-flag counts — useful for a data quality dashboard
    for flag in flag_cols:
        count = df[flag].sum()
        if count:
            log.warning("  %-35s %d rows", flag, count)

    return df


# ============================================================
# STEP 5 — TRANSFORM (clean the valid rows)
# ============================================================
# The clean layer is where we fix source-data issues that
# don't make a row invalid but still need correcting:
#   - Rename typo columns (lenght → length)
#   - Cast data types explicitly
#   - Strip whitespace from string columns
#
# Note: we only transform the VALID subset. Invalid rows go
# to the error table as-is (with their flags) so analysts
# can investigate the originals.

CLEAN_COLUMN_RENAME = {
    "product_name_lenght":        "product_name_length",        # fix source typo
    "product_description_lenght": "product_description_length", # fix source typo
}

CLEAN_COLUMNS = [
    "product_id",
    "product_category_name",
    "product_name_length",
    "product_description_length",
    "product_photos_qty",
    "product_weight_g",
    "product_length_cm",
    "product_height_cm",
    "product_width_cm",
]

def transform(df: pd.DataFrame) -> pd.DataFrame:
    """Return a clean DataFrame — only valid rows, renamed columns, correct types."""
    log.info("Transforming valid rows ...")

    clean = df[df["is_valid"]].copy()

    # Rename typo columns
    clean = clean.rename(columns=CLEAN_COLUMN_RENAME)

    # Strip leading/trailing whitespace from string columns
    str_cols = clean.select_dtypes(include="object").columns
    for col in str_cols:
        clean[col] = clean[col].str.strip()

    # Explicit type casting for safety
    clean["product_weight_g"]         = clean["product_weight_g"].astype(float)
    clean["product_length_cm"]        = clean["product_length_cm"].astype(float)
    clean["product_height_cm"]        = clean["product_height_cm"].astype(float)
    clean["product_width_cm"]         = clean["product_width_cm"].astype(float)
    clean["product_photos_qty"]       = clean["product_photos_qty"].astype("Int64")  # nullable int
    clean["product_name_length"]      = clean["product_name_length"].astype("Int64")
    clean["product_description_length"] = clean["product_description_length"].astype("Int64")

    # Keep only the columns that belong in the clean table
    clean = clean[CLEAN_COLUMNS]

    log.info("Transform complete: %d clean rows ready to load.", len(clean))
    return clean


# ============================================================
# STEP 6 — LOAD (write back to SQL Server)
# ============================================================
# We use pandas .to_sql() with if_exists='replace' — this
# truncates and reloads each run, matching the SQL TRUNCATE
# pattern. 'append' would be used for incremental loads.
#
# The entire load (error + clean + audit) is wrapped in a
# single SQLAlchemy connection with begin()/rollback() so
# that if the clean write fails, the error table is also
# rolled back — the two tables stay in sync.

def load(engine, df_flagged: pd.DataFrame, df_clean: pd.DataFrame):
    """Write error rows, clean rows, and audit record in one transaction."""

    # ── build error DataFrame ─────────────────────────────
    # Error rows = original columns + flag columns (no renaming).
    flag_cols = [c for c in df_flagged.columns if c.startswith("flag_")]
    raw_cols  = [c for c in df_flagged.columns if not c.startswith("flag_") and c != "is_valid"]
    df_error  = df_flagged[~df_flagged["is_valid"]][raw_cols + flag_cols].copy()

    rows_loaded   = len(df_clean)
    rows_rejected = len(df_error)

    log.info("Loading %d rows → %s", rows_rejected, TABLE_ERROR)
    log.info("Loading %d rows → %s", rows_loaded,   TABLE_CLEAN)

    # ── transaction boundary ──────────────────────────────
    # All three writes (error, clean, audit) succeed together
    # or all roll back. This prevents a half-loaded state.
    with engine.begin() as conn:
        try:
            # Write error table
            df_error.to_sql(
                name=TABLE_ERROR.split(".")[1],
                schema=TABLE_ERROR.split(".")[0],
                con=conn,
                if_exists="replace",   # truncate + reload each run
                index=False,
                chunksize=1000,        # commit in batches of 1000 rows
            )

            # Write clean table
            df_clean.to_sql(
                name=TABLE_CLEAN.split(".")[1],
                schema=TABLE_CLEAN.split(".")[0],
                con=conn,
                if_exists="replace",
                index=False,
                chunksize=1000,
            )

            # Write audit record — success
            audit_row = pd.DataFrame([{
                "table_name":     "products",
                "rows_loaded":    rows_loaded,
                "rows_rejected":  rows_rejected,
                "load_datetime":  datetime.now(),
                "status":         "SUCCESS",
                "error_message":  None,
            }])
            audit_row.to_sql(
                name=TABLE_AUDIT.split(".")[1],
                schema=TABLE_AUDIT.split(".")[0],
                con=conn,
                if_exists="append",   # never truncate audit history
                index=False,
            )

            log.info("All writes committed successfully.")

        except Exception as e:
            # SQLAlchemy's engine.begin() auto-rolls back on exception.
            # We still log the failure to the audit table in a
            # separate connection so the record is preserved.
            log.error("Load failed — rolling back. Error: %s", e)
            _write_audit_failure(engine, str(e))
            raise  # re-raise so the caller's except block fires


def _write_audit_failure(engine, error_message: str):
    """Write a FAILED audit row outside the main transaction."""
    try:
        with engine.begin() as conn:
            audit_row = pd.DataFrame([{
                "table_name":     "products",
                "rows_loaded":    -1,
                "rows_rejected":  -1,
                "load_datetime":  datetime.now(),
                "status":         "FAILED",
                "error_message":  error_message[:500],  # truncate long stack traces
            }])
            audit_row.to_sql(
                name=TABLE_AUDIT.split(".")[1],
                schema=TABLE_AUDIT.split(".")[0],
                con=conn,
                if_exists="append",
                index=False,
            )
    except Exception as audit_err:
        log.error("Could not write failure audit record: %s", audit_err)


# ============================================================
# STEP 7 — ORCHESTRATOR (ties all steps together)
# ============================================================
# run_pipeline() calls each step in order and handles any
# unexpected errors at the top level. This function is what
# you'd schedule via cron, Airflow, or a SQL Agent job.

def run_pipeline():
    """Execute the full ETL pipeline: extract → validate → transform → load."""
    log.info("=" * 60)
    log.info("Pipeline start: olist.products")
    log.info("=" * 60)

    try:
        engine      = get_engine()          # Step 2
        df_raw      = extract(engine)       # Step 3
        df_flagged  = validate(df_raw)      # Step 4
        df_clean    = transform(df_flagged) # Step 5
        load(engine, df_flagged, df_clean)  # Step 6

        log.info("=" * 60)
        log.info("Pipeline COMPLETE.")
        log.info("=" * 60)

    except Exception:
        log.error("Pipeline FAILED.")
        log.error(traceback.format_exc())
        raise


# ============================================================
# STEP 8 — ENTRY POINT
# ============================================================
# Running this file directly triggers the pipeline.
# When imported as a module (e.g. by Airflow or a test suite),
# the pipeline does NOT run automatically.

if __name__ == "__main__":
    run_pipeline()