-- Description: Data cleaning, validation, deduplication, and staging-to-core ETL
-- Execution Order: 3rd (after sample_data.sql)
-- Dependencies: schema.sql, sample_data.sql
-- HOW IT WORKS:
--   1. Validate staging rows and stamp validation_errors for bad records.
--   2. Load only valid, non-duplicate rows into the core tables.
--   3. All operations are wrapped in explicit transactions with audit logging.

USE financial_reconciliation;

INSERT INTO stg_company_transactions
    (raw_transaction_id, raw_transaction_date, raw_customer_id,
     raw_amount, raw_currency, raw_payment_method, raw_status,
     raw_reference_no, raw_description)
VALUES
-- Good rows
('TXN-STG-001','2025-12-22','CUST-1050','1500.00','USD','CARD_CREDIT','COMPLETED','REF-N001','Stg clean row 1'),
('TXN-STG-002','2025-12-23','CUST-1051','2300.00','USD','ACH',        'COMPLETED','REF-N002','Stg clean row 2'),
-- Bad amount (non-numeric)
('TXN-STG-003','2025-12-24','CUST-1052','N/A',    'USD','WIRE',       'COMPLETED','REF-N003','Stg bad amount'),
-- Bad date
('TXN-STG-004','99-13-2025','CUST-1053','900.00', 'USD','UPI',        'COMPLETED','REF-N004','Stg bad date'),
-- Missing customer
('TXN-STG-005','2025-12-25','',         '750.00', 'USD','WIRE',       'COMPLETED','REF-N005','Stg missing cust'),
-- Duplicate reference
('TXN-STG-006','2025-01-03','CUST-1001','1250.00','USD','CARD_CREDIT','COMPLETED','REF-A001','Stg dup ref');

INSERT INTO stg_bank_transactions
    (raw_bank_ref, raw_value_date, raw_account_no,
     raw_debit_amount, raw_credit_amount, raw_currency, raw_description, raw_status)
VALUES
('BNK-STG-001','2025-12-22','ACC-5001','0','1500.00','USD','REF-N001 Stg 1','CLEARED'),
('BNK-STG-002','2025-12-23','ACC-5001','0','2300.00','USD','REF-N002 Stg 2','CLEARED'),
('BNK-STG-003','2025-12-24','',        '0','900.00', 'USD','REF-N003 no acct','CLEARED');

INSERT INTO stg_gateway_transactions
    (raw_gateway_txn_id, raw_txn_datetime, raw_merchant_id, raw_order_id,
     raw_amount, raw_currency, raw_gateway_status, raw_payment_method)
VALUES
('GW-STG-001','2025-12-22 10:00:00','MERCH-001','REF-N001','1500.00','USD','CAPTURED','CARD_CREDIT'),
('GW-STG-002','2025-12-23 11:00:00','MERCH-001','REF-N002','2300.00','USD','CAPTURED','ACH'),
('GW-STG-003','bad-date',           'MERCH-001','REF-N003','900.00', 'USD','CAPTURED','UPI');

-- -----------------------------------------------------------------------
-- SECTION B: Validation — stamp validation_errors on staging rows
-- -----------------------------------------------------------------------
-- We use a single UPDATE per staging table. The CONCAT_WS approach
-- accumulates multiple error messages into one field.

-- Company staging validation
UPDATE stg_company_transactions
SET validation_errors = CONCAT_WS(' | ',
    CASE WHEN raw_transaction_id IS NULL OR raw_transaction_id = ''
         THEN 'MISSING transaction_id' END,
    CASE WHEN raw_customer_id IS NULL OR raw_customer_id = ''
         THEN 'MISSING customer_id' END,
    CASE WHEN raw_amount REGEXP '^[0-9]+(\\.[0-9]+)?$' = 0
         THEN CONCAT('INVALID amount: ', raw_amount) END,
    CASE WHEN STR_TO_DATE(raw_transaction_date, '%Y-%m-%d') IS NULL
         THEN CONCAT('INVALID date: ', raw_transaction_date) END,
    CASE WHEN raw_currency NOT IN (SELECT currency_code FROM ref_currency)
         THEN CONCAT('UNKNOWN currency: ', raw_currency) END,
    CASE WHEN raw_payment_method NOT IN (SELECT method_code FROM ref_payment_method)
         THEN CONCAT('UNKNOWN payment_method: ', raw_payment_method) END
)
WHERE is_processed = 0;

-- Treat NULL validation_errors as valid (no errors found)
UPDATE stg_company_transactions
SET validation_errors = NULL
WHERE validation_errors = ''
   OR validation_errors IS NULL
   AND is_processed = 0;

-- Bank staging validation
UPDATE stg_bank_transactions
SET validation_errors = CONCAT_WS(' | ',
    CASE WHEN raw_bank_ref IS NULL OR raw_bank_ref = ''
         THEN 'MISSING bank_ref' END,
    CASE WHEN raw_account_no IS NULL OR raw_account_no = ''
         THEN 'MISSING account_no' END,
    CASE WHEN raw_credit_amount REGEXP '^[0-9]+(\\.[0-9]+)?$' = 0
         THEN CONCAT('INVALID credit_amount: ', raw_credit_amount) END,
    CASE WHEN STR_TO_DATE(raw_value_date, '%Y-%m-%d') IS NULL
         THEN CONCAT('INVALID date: ', raw_value_date) END
)
WHERE is_processed = 0;

UPDATE stg_bank_transactions SET validation_errors = NULL
WHERE (validation_errors = '' OR validation_errors IS NULL) AND is_processed = 0;

-- Gateway staging validation
UPDATE stg_gateway_transactions
SET validation_errors = CONCAT_WS(' | ',
    CASE WHEN raw_gateway_txn_id IS NULL OR raw_gateway_txn_id = ''
         THEN 'MISSING gateway_txn_id' END,
    CASE WHEN raw_merchant_id IS NULL OR raw_merchant_id = ''
         THEN 'MISSING merchant_id' END,
    CASE WHEN raw_amount REGEXP '^[0-9]+(\\.[0-9]+)?$' = 0
         THEN CONCAT('INVALID amount: ', raw_amount) END,
    CASE WHEN STR_TO_DATE(raw_txn_datetime, '%Y-%m-%d %H:%i:%s') IS NULL
         THEN CONCAT('INVALID datetime: ', raw_txn_datetime) END
)
WHERE is_processed = 0;

UPDATE stg_gateway_transactions SET validation_errors = NULL
WHERE (validation_errors = '' OR validation_errors IS NULL) AND is_processed = 0;

-- -----------------------------------------------------------------------
-- SECTION C: Duplicate detection using ROW_NUMBER() window function
-- -----------------------------------------------------------------------
-- This CTE finds duplicate reference numbers that already exist in the
-- company_transactions core table, so staging rows can be excluded.

-- Create a temporary view of duplicate staging company rows for reference
CREATE OR REPLACE VIEW vw_stg_company_duplicates AS
WITH ranked_stg AS (
    SELECT
        stg_id,
        raw_reference_no,
        raw_transaction_id,
        -- Rank each staging row: rank=1 means it's the first occurrence
        ROW_NUMBER() OVER (
            PARTITION BY raw_reference_no
            ORDER BY stg_id
        ) AS rn,
        -- Also flag if reference already exists in core table
        EXISTS (
            SELECT 1 FROM company_transactions ct
            WHERE ct.reference_no = raw_reference_no
        ) AS exists_in_core
    FROM stg_company_transactions
    WHERE is_processed = 0
      AND validation_errors IS NULL
)
SELECT stg_id, raw_reference_no, raw_transaction_id,
       rn, exists_in_core,
       CASE
           WHEN exists_in_core = 1 THEN 'DUPLICATE_CORE'
           WHEN rn > 1             THEN 'DUPLICATE_STAGING'
           ELSE 'NEW'
       END AS dup_status
FROM ranked_stg;

-- -----------------------------------------------------------------------
-- SECTION D: Load valid, non-duplicate staging rows into core tables
-- -----------------------------------------------------------------------
-- Company transactions: load only NEW rows
START TRANSACTION;

INSERT INTO company_transactions
    (transaction_id, transaction_date, customer_id, amount,
     currency_code, payment_method, status, reference_no, description, source_stg_id)
SELECT
    s.raw_transaction_id,
    STR_TO_DATE(s.raw_transaction_date, '%Y-%m-%d'),
    s.raw_customer_id,
    CAST(s.raw_amount AS DECIMAL(18,2)),
    UPPER(TRIM(s.raw_currency)),
    UPPER(TRIM(s.raw_payment_method)),
    UPPER(TRIM(s.raw_status)),
    s.raw_reference_no,
    TRIM(s.raw_description),
    s.stg_id
FROM stg_company_transactions s
JOIN vw_stg_company_duplicates d ON d.stg_id = s.stg_id
WHERE s.is_processed = 0
  AND s.validation_errors IS NULL
  AND d.dup_status = 'NEW';

-- Mark processed
UPDATE stg_company_transactions s
JOIN vw_stg_company_duplicates d ON d.stg_id = s.stg_id
SET s.is_processed = 1
WHERE s.is_processed = 0
  AND s.validation_errors IS NULL
  AND d.dup_status = 'NEW';

-- Mark failed/duplicate rows
UPDATE stg_company_transactions s
JOIN vw_stg_company_duplicates d ON d.stg_id = s.stg_id
SET s.is_processed = 1,
    s.validation_errors = CONCAT_WS(' | ', s.validation_errors, d.dup_status)
WHERE s.is_processed = 0
  AND s.validation_errors IS NULL
  AND d.dup_status <> 'NEW';

-- Mark validation-failed rows as processed
UPDATE stg_company_transactions
SET is_processed = 1
WHERE is_processed = 0
  AND validation_errors IS NOT NULL;

-- Audit
INSERT INTO audit_log (log_level, source_table, operation, performed_by, message)
VALUES ('INFO', 'stg_company_transactions', 'ETL_LOAD', 'SYSTEM',
        CONCAT('Loaded ', ROW_COUNT(), ' company staging rows into core table'));

COMMIT;

-- Bank transactions staging load
START TRANSACTION;

INSERT INTO bank_transactions
    (bank_ref, value_date, account_no, debit_amount, credit_amount,
     currency_code, description, status, source_stg_id)
SELECT
    s.raw_bank_ref,
    STR_TO_DATE(s.raw_value_date, '%Y-%m-%d'),
    TRIM(s.raw_account_no),
    CAST(NULLIF(TRIM(s.raw_debit_amount), '') AS DECIMAL(18,2)),
    CAST(NULLIF(TRIM(s.raw_credit_amount),'') AS DECIMAL(18,2)),
    UPPER(TRIM(s.raw_currency)),
    TRIM(s.raw_description),
    UPPER(TRIM(s.raw_status)),
    s.stg_id
FROM stg_bank_transactions s
WHERE s.is_processed = 0
  AND s.validation_errors IS NULL
  AND NOT EXISTS (
        SELECT 1 FROM bank_transactions bt WHERE bt.bank_ref = s.raw_bank_ref
      );

UPDATE stg_bank_transactions SET is_processed = 1 WHERE is_processed = 0;

INSERT INTO audit_log (log_level, source_table, operation, performed_by, message)
VALUES ('INFO', 'stg_bank_transactions', 'ETL_LOAD', 'SYSTEM',
        CONCAT('Loaded ', ROW_COUNT(), ' bank staging rows into core table'));

COMMIT;

-- Gateway transactions staging load
START TRANSACTION;

INSERT INTO gateway_transactions
    (gateway_txn_ref, txn_datetime, merchant_id, order_id, amount,
     currency_code, gateway_status, payment_method, source_stg_id)
SELECT
    s.raw_gateway_txn_id,
    STR_TO_DATE(s.raw_txn_datetime, '%Y-%m-%d %H:%i:%s'),
    TRIM(s.raw_merchant_id),
    TRIM(s.raw_order_id),
    CAST(s.raw_amount AS DECIMAL(18,2)),
    UPPER(TRIM(s.raw_currency)),
    UPPER(TRIM(s.raw_gateway_status)),
    UPPER(TRIM(s.raw_payment_method)),
    s.stg_id
FROM stg_gateway_transactions s
WHERE s.is_processed = 0
  AND s.validation_errors IS NULL
  AND STR_TO_DATE(s.raw_txn_datetime, '%Y-%m-%d %H:%i:%s') IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 FROM gateway_transactions gt WHERE gt.gateway_txn_ref = s.raw_gateway_txn_id
      );

UPDATE stg_gateway_transactions SET is_processed = 1 WHERE is_processed = 0;

INSERT INTO audit_log (log_level, source_table, operation, performed_by, message)
VALUES ('INFO', 'stg_gateway_transactions', 'ETL_LOAD', 'SYSTEM',
        CONCAT('Loaded ', ROW_COUNT(), ' gateway staging rows into core table'));

COMMIT;

-- -----------------------------------------------------------------------
-- SECTION E: Advanced duplicate detection using window functions
--            on the core tables (catches any residual duplicates)
-- -----------------------------------------------------------------------
-- This query identifies transactions sharing same reference_no and amount
-- that may have slipped through, using LEAD/LAG for sequence analysis.

SELECT
    ct.company_txn_id,
    ct.transaction_id,
    ct.reference_no,
    ct.amount,
    ct.transaction_date,
    -- Partition by reference_no; row_number > 1 = duplicate
    ROW_NUMBER() OVER (
        PARTITION BY ct.reference_no
        ORDER BY ct.created_at
    )                                               AS occurrence_rank,
    -- Amount difference from previous occurrence (should be 0 for exact dups)
    ct.amount - LAG(ct.amount, 1, ct.amount) OVER (
        PARTITION BY ct.reference_no
        ORDER BY ct.created_at
    )                                               AS amount_delta_from_prev,
    -- Days between this and previous occurrence
    DATEDIFF(ct.transaction_date,
        LAG(ct.transaction_date, 1, ct.transaction_date) OVER (
            PARTITION BY ct.reference_no
            ORDER BY ct.created_at
        )
    )                                               AS days_since_prev_occurrence
FROM company_transactions ct
ORDER BY ct.reference_no, ct.created_at;

-- -----------------------------------------------------------------------
-- End of transformations.sql
-- -----------------------------------------------------------------------
