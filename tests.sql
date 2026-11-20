-- =============================================================================
-- Enterprise Financial Data Reconciliation & Exception Management Engine
-- File: database/tests.sql
-- Description: Test suite with assertions — verifies data integrity and
--              reconciliation logic correctness.
--
-- Execution Order: 7th (after all other scripts have run)
-- Dependencies: All previous scripts
--
-- HOW TESTS WORK:
--   Each test uses a SELECT that returns 'PASS' or 'FAIL'.
--   A result set is printed showing test_name, status, and details.
--   No external framework required — pure MySQL 8.0 compatible SQL.
-- =============================================================================

USE fin_reconciliation;

-- -----------------------------------------------------------------------
-- Helper procedure to run a single assertion
-- -----------------------------------------------------------------------
DELIMITER $$
DROP PROCEDURE IF EXISTS assert_test$$
CREATE PROCEDURE assert_test(
    IN p_test_name    VARCHAR(200),
    IN p_actual       BIGINT,
    IN p_expected_min BIGINT,
    IN p_expected_max BIGINT,
    IN p_description  TEXT
)
BEGIN
    IF p_actual BETWEEN p_expected_min AND p_expected_max THEN
        SELECT p_test_name AS test_name, 'PASS' AS status,
               CONCAT('actual=', p_actual, ', expected=[', p_expected_min,'-', p_expected_max,']')
               AS details, p_description AS description;
    ELSE
        SELECT p_test_name AS test_name, 'FAIL' AS status,
               CONCAT('actual=', p_actual, ', expected=[', p_expected_min,'-', p_expected_max,
                      '] — OUT OF RANGE') AS details, p_description AS description;
    END IF;
END$$
DELIMITER ;

-- =====================================================================
-- TEST GROUP 1: Schema Integrity Tests
-- =====================================================================

-- TC-S01: All reference tables populated
CALL assert_test(
    'TC-S01: ref_currency has rows',
    (SELECT COUNT(*) FROM ref_currency),
    5, 20,
    'At least 5 currencies should be seeded'
);

CALL assert_test(
    'TC-S02: ref_transaction_status has rows',
    (SELECT COUNT(*) FROM ref_transaction_status),
    5, 20,
    'At least 5 statuses should be seeded'
);

CALL assert_test(
    'TC-S03: ref_payment_method has rows',
    (SELECT COUNT(*) FROM ref_payment_method),
    5, 15,
    'At least 5 payment methods should be seeded'
);

CALL assert_test(
    'TC-S04: ref_recon_result_type has all 9 types',
    (SELECT COUNT(*) FROM ref_recon_result_type),
    9, 9,
    'Exactly 9 result types expected'
);

-- =====================================================================
-- TEST GROUP 2: Data Volume Tests
-- =====================================================================

CALL assert_test(
    'TC-V01: company_transactions >= 200 rows',
    (SELECT COUNT(*) FROM company_transactions),
    200, 999,
    'At least 200 company transaction records expected'
);

CALL assert_test(
    'TC-V02: bank_transactions >= 200 rows',
    (SELECT COUNT(*) FROM bank_transactions),
    200, 999,
    'At least 200 bank transaction records expected'
);

CALL assert_test(
    'TC-V03: gateway_transactions >= 150 rows',
    (SELECT COUNT(*) FROM gateway_transactions),
    150, 999,
    'At least 150 gateway transaction records expected'
);

CALL assert_test(
    'TC-V04: Total records across all sources >= 550',
    (SELECT
        (SELECT COUNT(*) FROM company_transactions)
      + (SELECT COUNT(*) FROM bank_transactions)
      + (SELECT COUNT(*) FROM gateway_transactions)),
    550, 9999,
    'Combined total should exceed 550 records'
);

-- =====================================================================
-- TEST GROUP 3: Duplicate Detection Tests
-- =====================================================================

CALL assert_test(
    'TC-D01: At least 3 company duplicates flagged',
    (SELECT COUNT(*) FROM company_transactions WHERE is_duplicate = 1),
    3, 100,
    'TXN-00191,192,193 should be flagged as duplicates'
);

CALL assert_test(
    'TC-D02: At least 3 bank duplicates flagged',
    (SELECT COUNT(*) FROM bank_transactions WHERE is_duplicate = 1),
    3, 100,
    'BNK-DUP-01,02,03 should be flagged'
);

CALL assert_test(
    'TC-D03: At least 2 gateway duplicates flagged',
    (SELECT COUNT(*) FROM gateway_transactions WHERE is_duplicate = 1),
    2, 100,
    'GW-DUP-01,02 should be flagged'
);

-- TC-D04: Verify duplicates point to valid original records
CALL assert_test(
    'TC-D04: All company duplicate_of_id values are valid FKs',
    (SELECT COUNT(*) FROM company_transactions ct
     WHERE ct.is_duplicate = 1
       AND ct.duplicate_of_id NOT IN (SELECT company_txn_id FROM company_transactions)),
    0, 0,
    'No duplicate_of_id should reference a non-existent row'
);

-- =====================================================================
-- TEST GROUP 4: Reconciliation Run Tests
-- =====================================================================

CALL assert_test(
    'TC-R01: At least one reconciliation run exists',
    (SELECT COUNT(*) FROM recon_run_log),
    1, 9999,
    'sp_run_full_reconciliation should have been called at least once'
);

CALL assert_test(
    'TC-R02: At least one COMPLETED run',
    (SELECT COUNT(*) FROM recon_run_log WHERE status = 'COMPLETED'),
    1, 9999,
    'At least one run should have status=COMPLETED'
);

CALL assert_test(
    'TC-R03: reconciliation_results has records',
    (SELECT COUNT(*) FROM reconciliation_results),
    1, 999999,
    'Reconciliation should have produced result rows'
);

-- =====================================================================
-- TEST GROUP 5: Reconciliation Logic Tests
-- =====================================================================

-- TC-L01: MATCHED count — expect at least 100 (we have 180 clean matching rows)
CALL assert_test(
    'TC-L01: MATCHED count >= 100',
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type = 'MATCHED'),
    100, 9999,
    'At least 100 clean matches expected from seeded data'
);

-- TC-L02: MISSING_BANK exceptions exist (TXN-00194..200 have no bank)
CALL assert_test(
    'TC-L02: MISSING_BANK exceptions exist',
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type = 'MISSING_BANK'),
    1, 9999,
    'Company transactions without bank counterparts should be flagged'
);

-- TC-L03: MISSING_GATEWAY exceptions exist
CALL assert_test(
    'TC-L03: MISSING_GATEWAY exceptions exist',
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type = 'MISSING_GATEWAY'),
    1, 9999,
    'Company transactions without gateway counterparts should be flagged'
);

-- TC-L04: AMOUNT_MISMATCH exceptions exist (BNK-MIS rows have small deltas)
CALL assert_test(
    'TC-L04: AMOUNT_MISMATCH exceptions exist',
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type = 'AMOUNT_MISMATCH'),
    1, 9999,
    'Bank/gateway rows with fee-adjusted amounts should produce mismatches'
);

-- TC-L05: UNMATCHED_BANK exceptions exist (BNK-UNM rows)
CALL assert_test(
    'TC-L05: UNMATCHED_BANK exceptions exist',
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type = 'UNMATCHED_BANK'),
    1, 9999,
    'BNK-UNM-01..05 should be classified UNMATCHED_BANK'
);

-- TC-L06: UNMATCHED_GATEWAY exceptions exist (GW-UNM rows)
CALL assert_test(
    'TC-L06: UNMATCHED_GATEWAY exceptions exist',
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type = 'UNMATCHED_GATEWAY'),
    1, 9999,
    'GW-UNM-01..04 should be classified UNMATCHED_GATEWAY'
);

-- TC-L07: Every MATCHED row has a valid company_txn_id
CALL assert_test(
    'TC-L07: All MATCHED rows have valid company_txn_id',
    (SELECT COUNT(*) FROM reconciliation_results rr
     WHERE rr.result_type = 'MATCHED'
       AND rr.company_txn_id NOT IN (SELECT company_txn_id FROM company_transactions)),
    0, 0,
    'No MATCHED result should reference a non-existent company transaction'
);

-- TC-L08: amount_variance on MATCHED rows should be <= 0.01
CALL assert_test(
    'TC-L08: MATCHED rows have zero or near-zero variance',
    (SELECT COUNT(*) FROM reconciliation_results
     WHERE result_type = 'MATCHED'
       AND ABS(amount_variance) > 0.01),
    0, 0,
    'All MATCHED rows must have |variance| <= $0.01'
);

-- TC-L09: DUPLICATE exceptions equal total flagged duplicates
CALL assert_test(
    'TC-L09: DUPLICATE result rows >= company+bank+gateway duplicates',
    (SELECT COUNT(*) FROM reconciliation_results
     WHERE result_type LIKE 'DUPLICATE%'),
    (SELECT COUNT(*) FROM company_transactions WHERE is_duplicate = 1)
    + (SELECT COUNT(*) FROM bank_transactions   WHERE is_duplicate = 1)
    + (SELECT COUNT(*) FROM gateway_transactions WHERE is_duplicate = 1),
    999999,
    'Result duplicates should be >= source duplicate flags'
);

-- =====================================================================
-- TEST GROUP 6: View Tests
-- =====================================================================

CALL assert_test(
    'TC-VW01: vw_reconciliation_dashboard returns at least 1 row',
    (SELECT COUNT(*) FROM vw_reconciliation_dashboard),
    1, 9999,
    'Dashboard view must return a result after reconciliation run'
);

CALL assert_test(
    'TC-VW02: vw_unresolved_exceptions returns rows',
    (SELECT COUNT(*) FROM vw_unresolved_exceptions),
    1, 9999,
    'There should be open exceptions after first run'
);

CALL assert_test(
    'TC-VW03: vw_duplicate_transactions returns rows from all 3 sources',
    (SELECT COUNT(DISTINCT source_table) FROM vw_duplicate_transactions),
    3, 3,
    'Duplicates should be present in COMPANY, BANK, and GATEWAY'
);

CALL assert_test(
    'TC-VW04: vw_matched_transactions returns rows',
    (SELECT COUNT(*) FROM vw_matched_transactions),
    1, 9999,
    'At least one matched transaction should appear in the view'
);

-- =====================================================================
-- TEST GROUP 7: Audit Log Tests
-- =====================================================================

CALL assert_test(
    'TC-A01: audit_log has records',
    (SELECT COUNT(*) FROM audit_log),
    5, 9999,
    'Audit log should capture at least 5 events from ETL + reconciliation'
);

CALL assert_test(
    'TC-A02: No ERROR entries in audit_log',
    (SELECT COUNT(*) FROM audit_log WHERE log_level = 'ERROR'),
    0, 0,
    'A clean run should produce zero ERROR audit entries'
);

-- =====================================================================
-- TEST GROUP 8: Stored Procedure Tests
-- =====================================================================

-- TC-P01: Resolve an exception and verify it is marked resolved
SET @test_recon_id = (
    SELECT MIN(recon_id) FROM reconciliation_results
    WHERE result_type = 'MISSING_BANK' AND resolved = 0
    LIMIT 1
);

CALL sp_resolve_exception(
    @test_recon_id,
    'TEST_USER',
    'Resolved by automated test TC-P01 — bank delay confirmed'
);

CALL assert_test(
    'TC-P01: sp_resolve_exception marks record as resolved',
    (SELECT COUNT(*) FROM reconciliation_results
     WHERE recon_id = @test_recon_id AND resolved = 1),
    1, 1,
    'The resolved flag should be set to 1 after calling sp_resolve_exception'
);

-- TC-P02: Second reconciliation run increments run count
CALL sp_run_full_reconciliation(CURDATE());

CALL assert_test(
    'TC-P02: Running reconciliation twice creates >= 2 run log entries',
    (SELECT COUNT(*) FROM recon_run_log WHERE status = 'COMPLETED'),
    2, 9999,
    'Two completed runs should exist after calling the procedure twice'
);

-- =====================================================================
-- TEST GROUP 9: Data Quality / Business Rule Tests
-- =====================================================================

-- TC-BR01: No company transaction should have amount <= 0
CALL assert_test(
    'TC-BR01: All company amounts > 0',
    (SELECT COUNT(*) FROM company_transactions WHERE amount <= 0),
    0, 0,
    'Business rule: all transaction amounts must be positive'
);

-- TC-BR02: No bank transaction should have both debit and credit > 0
CALL assert_test(
    'TC-BR02: Bank transactions have exclusive debit/credit',
    (SELECT COUNT(*) FROM bank_transactions
     WHERE debit_amount > 0 AND credit_amount > 0),
    0, 0,
    'A bank row cannot be both a debit and a credit simultaneously'
);

-- TC-BR03: All company currency codes exist in ref_currency
CALL assert_test(
    'TC-BR03: All company currency codes are valid',
    (SELECT COUNT(*) FROM company_transactions ct
     WHERE ct.currency_code NOT IN (SELECT currency_code FROM ref_currency)),
    0, 0,
    'FK constraint ensures validity; this tests data integrity at application level'
);

-- TC-BR04: Reconciliation rate >= 50% (data quality baseline)
CALL assert_test(
    'TC-BR04: Reconciliation rate >= 50%',
    (SELECT FLOOR(reconciliation_rate_pct) FROM vw_reconciliation_dashboard LIMIT 1),
    50, 100,
    'At least 50% of company transactions should match — baseline quality gate'
);

-- =====================================================================
-- FINAL SUMMARY REPORT
-- =====================================================================

SELECT
    'TEST EXECUTION COMPLETE' AS message,
    NOW()                     AS run_at,
    (SELECT COUNT(*) FROM recon_run_log WHERE status = 'COMPLETED')  AS completed_runs,
    (SELECT COUNT(*) FROM reconciliation_results)                     AS total_recon_records,
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type = 'MATCHED')
                                                                      AS matched,
    (SELECT COUNT(*) FROM reconciliation_results WHERE result_type <> 'MATCHED'
                                                   AND resolved = 0)  AS open_exceptions,
    (SELECT COUNT(*) FROM audit_log WHERE log_level = 'ERROR')        AS error_count;

-- -----------------------------------------------------------------------
-- End of tests.sql
-- -----------------------------------------------------------------------
