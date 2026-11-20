-- =============================================================================
-- Enterprise Financial Data Reconciliation & Exception Management Engine
-- File: database/procedures.sql
-- Description: Stored procedures for the full reconciliation workflow
--
-- Execution Order: 4th (after transformations.sql)
-- Dependencies: schema.sql, sample_data.sql
--
-- Procedures defined:
--   sp_start_recon_run         - Open a new run, return run_id
--   sp_detect_duplicates       - Flag duplicates in all three tables
--   sp_reconcile_transactions  - Core 5-way matching & exception classification
--   sp_generate_daily_summary  - Aggregate results into daily_recon_summary
--   sp_run_full_reconciliation - Orchestrator: calls all of the above
--   sp_resolve_exception       - Manually mark an exception as resolved
-- =============================================================================

USE fin_reconciliation;

DELIMITER $$

-- ============================================================
-- Procedure 1: sp_start_recon_run
-- Opens a new recon_run_log entry and returns the new run_id.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_start_recon_run$$
CREATE PROCEDURE sp_start_recon_run(
    IN  p_run_date DATE,
    OUT p_run_id   BIGINT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            @msg = MESSAGE_TEXT;
        INSERT INTO audit_log (log_level, operation, performed_by, message)
        VALUES ('ERROR', 'sp_start_recon_run', 'SYSTEM', @msg);
        RESIGNAL;
    END;

    INSERT INTO recon_run_log (run_date, started_at, status)
    VALUES (p_run_date, NOW(3), 'RUNNING');

    SET p_run_id = LAST_INSERT_ID();

    INSERT INTO audit_log (log_level, source_table, operation, record_id, performed_by, message)
    VALUES ('INFO', 'recon_run_log', 'RUN_STARTED', p_run_id, 'SYSTEM',
            CONCAT('Reconciliation run started for date: ', p_run_date));
END$$

-- ============================================================
-- Procedure 2: sp_detect_duplicates
-- Uses ROW_NUMBER() to identify and flag duplicate transactions.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_detect_duplicates$$
CREATE PROCEDURE sp_detect_duplicates(
    IN p_run_id BIGINT UNSIGNED
)
BEGIN
    DECLARE v_dup_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        INSERT INTO audit_log (log_level, operation, performed_by, message)
        VALUES ('ERROR', 'sp_detect_duplicates', 'SYSTEM', @msg);
        RESIGNAL;
    END;

    -- ---- Company table: duplicate detection ----
    -- A "duplicate" = same reference_no and amount, different PK.
    -- We flag the later occurrences (rn > 1) as duplicates of the first (rn = 1).
    UPDATE company_transactions ct
    JOIN (
        SELECT
            company_txn_id,
            ROW_NUMBER() OVER (
                PARTITION BY reference_no, amount
                ORDER BY company_txn_id
            ) AS rn,
            FIRST_VALUE(company_txn_id) OVER (
                PARTITION BY reference_no, amount
                ORDER BY company_txn_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS first_id
        FROM company_transactions
        WHERE is_duplicate = 0
    ) ranked ON ranked.company_txn_id = ct.company_txn_id
    SET ct.is_duplicate = 1,
        ct.duplicate_of_id = ranked.first_id
    WHERE ranked.rn > 1;

    SET v_dup_count = ROW_COUNT();

    -- Insert duplicate exceptions into reconciliation_results
    INSERT INTO reconciliation_results
        (recon_date, result_type, company_txn_id, company_amount, currency_code,
         exception_notes, run_id)
    SELECT
        ct.transaction_date,
        'DUPLICATE_COMPANY',
        ct.company_txn_id,
        ct.amount,
        ct.currency_code,
        CONCAT('Duplicate of company_txn_id ', ct.duplicate_of_id,
               ' — reference_no: ', ct.reference_no),
        p_run_id
    FROM company_transactions ct
    WHERE ct.is_duplicate = 1
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.company_txn_id = ct.company_txn_id
              AND rr.result_type = 'DUPLICATE_COMPANY'
              AND rr.run_id = p_run_id
          );

    -- ---- Bank table: duplicate detection ----
    UPDATE bank_transactions bt
    JOIN (
        SELECT
            bank_txn_id,
            ROW_NUMBER() OVER (
                PARTITION BY net_amount, value_date
                ORDER BY bank_txn_id
            ) AS rn,
            FIRST_VALUE(bank_txn_id) OVER (
                PARTITION BY net_amount, value_date
                ORDER BY bank_txn_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS first_id
        FROM bank_transactions
        WHERE is_duplicate = 0
    ) ranked ON ranked.bank_txn_id = bt.bank_txn_id
    SET bt.is_duplicate = 1,
        bt.duplicate_of_id = ranked.first_id
    WHERE ranked.rn > 1;

    INSERT INTO reconciliation_results
        (recon_date, result_type, bank_txn_id, bank_amount, currency_code,
         exception_notes, run_id)
    SELECT
        bt.value_date,
        'DUPLICATE_BANK',
        bt.bank_txn_id,
        bt.net_amount,
        bt.currency_code,
        CONCAT('Duplicate of bank_txn_id ', bt.duplicate_of_id,
               ' — net_amount: ', bt.net_amount, ' on ', bt.value_date),
        p_run_id
    FROM bank_transactions bt
    WHERE bt.is_duplicate = 1
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.bank_txn_id = bt.bank_txn_id
              AND rr.result_type = 'DUPLICATE_BANK'
              AND rr.run_id = p_run_id
          );

    -- ---- Gateway table: duplicate detection ----
    UPDATE gateway_transactions gt
    JOIN (
        SELECT
            gateway_txn_id,
            ROW_NUMBER() OVER (
                PARTITION BY order_id, amount
                ORDER BY gateway_txn_id
            ) AS rn,
            FIRST_VALUE(gateway_txn_id) OVER (
                PARTITION BY order_id, amount
                ORDER BY gateway_txn_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS first_id
        FROM gateway_transactions
        WHERE is_duplicate = 0
    ) ranked ON ranked.gateway_txn_id = gt.gateway_txn_id
    SET gt.is_duplicate = 1,
        gt.duplicate_of_id = ranked.first_id
    WHERE ranked.rn > 1;

    INSERT INTO reconciliation_results
        (recon_date, result_type, gateway_txn_id, gateway_amount, currency_code,
         exception_notes, run_id)
    SELECT
        DATE(gt.txn_datetime),
        'DUPLICATE_GATEWAY',
        gt.gateway_txn_id,
        gt.amount,
        gt.currency_code,
        CONCAT('Duplicate of gateway_txn_id ', gt.duplicate_of_id,
               ' — order_id: ', gt.order_id),
        p_run_id
    FROM gateway_transactions gt
    WHERE gt.is_duplicate = 1
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.gateway_txn_id = gt.gateway_txn_id
              AND rr.result_type = 'DUPLICATE_GATEWAY'
              AND rr.run_id = p_run_id
          );

    INSERT INTO audit_log (log_level, source_table, operation, record_id, performed_by, message)
    VALUES ('INFO', 'ALL', 'DUPLICATE_DETECTION', p_run_id, 'SYSTEM',
            CONCAT('Duplicate detection complete for run_id=', p_run_id));
END$$

-- ============================================================
-- Procedure 3: sp_reconcile_transactions
-- Core reconciliation logic using CTEs and LEFT JOINs.
-- Identifies: MATCHED, MISSING_BANK, MISSING_GATEWAY, AMOUNT_MISMATCH,
--             UNMATCHED_BANK, UNMATCHED_GATEWAY
-- ============================================================
DROP PROCEDURE IF EXISTS sp_reconcile_transactions$$
CREATE PROCEDURE sp_reconcile_transactions(
    IN p_run_id   BIGINT UNSIGNED,
    IN p_run_date DATE
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        INSERT INTO audit_log (log_level, operation, performed_by, message)
        VALUES ('ERROR', 'sp_reconcile_transactions', 'SYSTEM', @msg);
        RESIGNAL;
    END;

    -- ----------------------------------------------------------------
    -- STEP 1: MATCHED — company ↔ bank ↔ gateway all agree
    -- Matching key: company.reference_no = bank.description contains ref
    --               company.reference_no = gateway.order_id
    --               amounts agree within $0.01 tolerance
    -- ----------------------------------------------------------------
    INSERT INTO reconciliation_results
        (recon_date, result_type,
         company_txn_id, bank_txn_id, gateway_txn_id,
         company_amount, bank_amount, gateway_amount,
         currency_code, matched_on, exception_notes, run_id)
    WITH company_base AS (
        -- Use only non-duplicate company transactions
        SELECT ct.company_txn_id, ct.transaction_id, ct.reference_no,
               ct.transaction_date, ct.amount, ct.currency_code
        FROM company_transactions ct
        WHERE ct.is_duplicate = 0
    ),
    bank_base AS (
        SELECT bt.bank_txn_id, bt.bank_ref, bt.value_date,
               bt.net_amount, bt.currency_code, bt.description
        FROM bank_transactions bt
        WHERE bt.is_duplicate = 0
    ),
    gateway_base AS (
        SELECT gt.gateway_txn_id, gt.gateway_txn_ref, gt.order_id,
               DATE(gt.txn_datetime) AS txn_date,
               gt.amount, gt.currency_code
        FROM gateway_transactions gt
        WHERE gt.is_duplicate = 0
    ),
    -- Match company ↔ bank on reference in description
    comp_bank AS (
        SELECT
            cb.company_txn_id,
            cb.reference_no,
            cb.transaction_date,
            cb.amount          AS comp_amount,
            cb.currency_code,
            bb.bank_txn_id,
            bb.net_amount      AS bank_amount,
            ABS(cb.amount - bb.net_amount) AS bank_variance
        FROM company_base cb
        JOIN bank_base bb ON bb.description LIKE CONCAT('%', cb.reference_no, '%')
                         AND cb.currency_code = bb.currency_code
    ),
    -- Match comp_bank ↔ gateway on order_id
    full_match AS (
        SELECT
            compb.company_txn_id,
            compb.reference_no,
            compb.transaction_date,
            compb.comp_amount,
            compb.currency_code,
            compb.bank_txn_id,
            compb.bank_amount,
            compb.bank_variance,
            gb.gateway_txn_id,
            gb.amount AS gw_amount,
            ABS(compb.comp_amount - gb.amount) AS gw_variance
        FROM comp_bank compb
        JOIN gateway_base gb ON gb.order_id = compb.reference_no
                             AND gb.currency_code = compb.currency_code
    )
    SELECT
        fm.transaction_date,
        'MATCHED',
        fm.company_txn_id,
        fm.bank_txn_id,
        fm.gateway_txn_id,
        fm.comp_amount,
        fm.bank_amount,
        fm.gw_amount,
        fm.currency_code,
        'reference_no, currency_code',
        CASE
            WHEN fm.bank_variance > 0.01 OR fm.gw_variance > 0.01
            THEN CONCAT('Warning: bank_var=', fm.bank_variance,
                        ', gw_var=', fm.gw_variance)
            ELSE NULL
        END,
        p_run_id
    FROM full_match fm
    WHERE fm.bank_variance <= 0.01
      AND fm.gw_variance   <= 0.01
      -- Don't insert if already reconciled in this run
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.company_txn_id = fm.company_txn_id
              AND rr.run_id = p_run_id
          );

    -- ----------------------------------------------------------------
    -- STEP 2: AMOUNT_MISMATCH — matched by reference but amounts differ
    -- ----------------------------------------------------------------
    INSERT INTO reconciliation_results
        (recon_date, result_type,
         company_txn_id, bank_txn_id, gateway_txn_id,
         company_amount, bank_amount, gateway_amount,
         currency_code, matched_on, exception_notes, run_id)
    WITH company_base AS (
        SELECT ct.company_txn_id, ct.reference_no, ct.transaction_date,
               ct.amount, ct.currency_code
        FROM company_transactions ct WHERE ct.is_duplicate = 0
    ),
    bank_base AS (
        SELECT bt.bank_txn_id, bt.description, bt.net_amount, bt.value_date,
               bt.currency_code
        FROM bank_transactions bt WHERE bt.is_duplicate = 0
    ),
    gateway_base AS (
        SELECT gt.gateway_txn_id, gt.order_id, gt.amount, gt.currency_code,
               DATE(gt.txn_datetime) AS txn_date
        FROM gateway_transactions gt WHERE gt.is_duplicate = 0
    )
    SELECT
        cb.transaction_date,
        'AMOUNT_MISMATCH',
        cb.company_txn_id,
        bb.bank_txn_id,
        gb.gateway_txn_id,
        cb.amount,
        bb.net_amount,
        gb.amount,
        cb.currency_code,
        'reference_no',
        CONCAT('Company=', cb.amount,
               ' | Bank=', IFNULL(bb.net_amount,'N/A'),
               ' | Gateway=', IFNULL(gb.amount,'N/A'),
               ' | bank_var=', ABS(cb.amount - IFNULL(bb.net_amount, cb.amount)),
               ' | gw_var=',   ABS(cb.amount - IFNULL(gb.amount,     cb.amount))),
        p_run_id
    FROM company_base cb
    LEFT JOIN bank_base bb ON bb.description LIKE CONCAT('%', cb.reference_no, '%')
                           AND bb.currency_code = cb.currency_code
    LEFT JOIN gateway_base gb ON gb.order_id = cb.reference_no
                              AND gb.currency_code = cb.currency_code
    WHERE (ABS(cb.amount - IFNULL(bb.net_amount, cb.amount)) > 0.01
        OR ABS(cb.amount - IFNULL(gb.amount,     cb.amount)) > 0.01)
      AND (bb.bank_txn_id IS NOT NULL OR gb.gateway_txn_id IS NOT NULL)
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.company_txn_id = cb.company_txn_id
              AND rr.result_type IN ('MATCHED','AMOUNT_MISMATCH')
              AND rr.run_id = p_run_id
          );

    -- ----------------------------------------------------------------
    -- STEP 3: MISSING_BANK — company record but no bank counterpart
    -- ----------------------------------------------------------------
    INSERT INTO reconciliation_results
        (recon_date, result_type,
         company_txn_id, company_amount, currency_code,
         exception_notes, run_id)
    SELECT
        ct.transaction_date,
        'MISSING_BANK',
        ct.company_txn_id,
        ct.amount,
        ct.currency_code,
        CONCAT('No bank record for company txn ', ct.transaction_id,
               ' ref=', ct.reference_no, ' amount=', ct.amount),
        p_run_id
    FROM company_transactions ct
    WHERE ct.is_duplicate = 0
      AND NOT EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.description LIKE CONCAT('%', ct.reference_no, '%')
              AND bt.is_duplicate = 0
              AND bt.currency_code = ct.currency_code
          )
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.company_txn_id = ct.company_txn_id
              AND rr.run_id = p_run_id
          );

    -- ----------------------------------------------------------------
    -- STEP 4: MISSING_GATEWAY — company record but no gateway counterpart
    -- ----------------------------------------------------------------
    INSERT INTO reconciliation_results
        (recon_date, result_type,
         company_txn_id, company_amount, currency_code,
         exception_notes, run_id)
    SELECT
        ct.transaction_date,
        'MISSING_GATEWAY',
        ct.company_txn_id,
        ct.amount,
        ct.currency_code,
        CONCAT('No gateway record for company txn ', ct.transaction_id,
               ' ref=', ct.reference_no, ' amount=', ct.amount),
        p_run_id
    FROM company_transactions ct
    WHERE ct.is_duplicate = 0
      AND NOT EXISTS (
            SELECT 1 FROM gateway_transactions gt
            WHERE gt.order_id = ct.reference_no
              AND gt.is_duplicate = 0
              AND gt.currency_code = ct.currency_code
          )
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.company_txn_id = ct.company_txn_id
              AND rr.result_type IN ('MISSING_GATEWAY','MATCHED','AMOUNT_MISMATCH','MISSING_BANK')
              AND rr.run_id = p_run_id
          );

    -- ----------------------------------------------------------------
    -- STEP 5: UNMATCHED_BANK — bank entry with no company record
    -- ----------------------------------------------------------------
    INSERT INTO reconciliation_results
        (recon_date, result_type,
         bank_txn_id, bank_amount, currency_code,
         exception_notes, run_id)
    SELECT
        bt.value_date,
        'UNMATCHED_BANK',
        bt.bank_txn_id,
        bt.net_amount,
        bt.currency_code,
        CONCAT('Bank record ', bt.bank_ref, ' (amount=', bt.net_amount,
               ') has no matching company transaction'),
        p_run_id
    FROM bank_transactions bt
    WHERE bt.is_duplicate = 0
      AND NOT EXISTS (
            SELECT 1 FROM company_transactions ct
            WHERE bt.description LIKE CONCAT('%', ct.reference_no, '%')
              AND bt.currency_code = ct.currency_code
              AND ct.is_duplicate = 0
          )
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.bank_txn_id = bt.bank_txn_id
              AND rr.run_id = p_run_id
          );

    -- ----------------------------------------------------------------
    -- STEP 6: UNMATCHED_GATEWAY — gateway entry with no company record
    -- ----------------------------------------------------------------
    INSERT INTO reconciliation_results
        (recon_date, result_type,
         gateway_txn_id, gateway_amount, currency_code,
         exception_notes, run_id)
    SELECT
        DATE(gt.txn_datetime),
        'UNMATCHED_GATEWAY',
        gt.gateway_txn_id,
        gt.amount,
        gt.currency_code,
        CONCAT('Gateway record ', gt.gateway_txn_ref, ' order=', gt.order_id,
               ' (amount=', gt.amount, ') has no matching company transaction'),
        p_run_id
    FROM gateway_transactions gt
    WHERE gt.is_duplicate = 0
      AND NOT EXISTS (
            SELECT 1 FROM company_transactions ct
            WHERE ct.reference_no = gt.order_id
              AND ct.currency_code = gt.currency_code
              AND ct.is_duplicate = 0
          )
      AND NOT EXISTS (
            SELECT 1 FROM reconciliation_results rr
            WHERE rr.gateway_txn_id = gt.gateway_txn_id
              AND rr.run_id = p_run_id
          );

    INSERT INTO audit_log (log_level, source_table, operation, record_id, performed_by, message)
    VALUES ('INFO', 'reconciliation_results', 'RECONCILE', p_run_id, 'SYSTEM',
            CONCAT('Reconciliation complete for run_id=', p_run_id));
END$$

-- ============================================================
-- Procedure 4: sp_generate_daily_summary
-- Aggregates reconciliation_results into daily_recon_summary.
-- Uses INSERT ... ON DUPLICATE KEY UPDATE (upsert pattern).
-- ============================================================
DROP PROCEDURE IF EXISTS sp_generate_daily_summary$$
CREATE PROCEDURE sp_generate_daily_summary(
    IN p_run_id   BIGINT UNSIGNED,
    IN p_run_date DATE
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        INSERT INTO audit_log (log_level, operation, performed_by, message)
        VALUES ('ERROR', 'sp_generate_daily_summary', 'SYSTEM', @msg);
        RESIGNAL;
    END;

    INSERT INTO daily_recon_summary
        (summary_date, currency_code,
         total_transactions,
         matched_count,
         missing_bank_count,
         missing_gw_count,
         mismatch_count,
         duplicate_count,
         total_company_amount,
         total_bank_amount,
         total_variance,
         generated_at,
         run_id)
    SELECT
        rr.recon_date,
        rr.currency_code,
        COUNT(*)                                                                    AS total_transactions,
        SUM(CASE WHEN rr.result_type = 'MATCHED'          THEN 1 ELSE 0 END)       AS matched_count,
        SUM(CASE WHEN rr.result_type = 'MISSING_BANK'     THEN 1 ELSE 0 END)       AS missing_bank_count,
        SUM(CASE WHEN rr.result_type = 'MISSING_GATEWAY'  THEN 1 ELSE 0 END)       AS missing_gw_count,
        SUM(CASE WHEN rr.result_type = 'AMOUNT_MISMATCH'  THEN 1 ELSE 0 END)       AS mismatch_count,
        SUM(CASE WHEN rr.result_type LIKE 'DUPLICATE%'    THEN 1 ELSE 0 END)       AS duplicate_count,
        COALESCE(SUM(rr.company_amount), 0)                                         AS total_company_amount,
        COALESCE(SUM(rr.bank_amount), 0)                                            AS total_bank_amount,
        COALESCE(SUM(rr.amount_variance), 0)                                        AS total_variance,
        NOW(3),
        p_run_id
    FROM reconciliation_results rr
    WHERE rr.run_id = p_run_id
    GROUP BY rr.recon_date, rr.currency_code
    ON DUPLICATE KEY UPDATE
        total_transactions  = VALUES(total_transactions),
        matched_count       = VALUES(matched_count),
        missing_bank_count  = VALUES(missing_bank_count),
        missing_gw_count    = VALUES(missing_gw_count),
        mismatch_count      = VALUES(mismatch_count),
        duplicate_count     = VALUES(duplicate_count),
        total_company_amount = VALUES(total_company_amount),
        total_bank_amount   = VALUES(total_bank_amount),
        total_variance      = VALUES(total_variance),
        generated_at        = VALUES(generated_at),
        run_id              = VALUES(run_id);

    INSERT INTO audit_log (log_level, source_table, operation, record_id, performed_by, message)
    VALUES ('INFO', 'daily_recon_summary', 'SUMMARY_GENERATED', p_run_id, 'SYSTEM',
            CONCAT('Daily summary generated for run_id=', p_run_id));
END$$

-- ============================================================
-- Procedure 5: sp_run_full_reconciliation
-- Orchestrator — runs the entire pipeline end to end.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_run_full_reconciliation$$
CREATE PROCEDURE sp_run_full_reconciliation(
    IN p_run_date DATE
)
BEGIN
    DECLARE v_run_id BIGINT UNSIGNED;
    DECLARE v_comp_count INT;
    DECLARE v_bank_count INT;
    DECLARE v_gw_count   INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        IF v_run_id IS NOT NULL THEN
            UPDATE recon_run_log
            SET status = 'FAILED', error_message = @msg, completed_at = NOW(3)
            WHERE run_id = v_run_id;
        END IF;
        INSERT INTO audit_log (log_level, operation, performed_by, message)
        VALUES ('ERROR', 'sp_run_full_reconciliation', 'SYSTEM', @msg);
        RESIGNAL;
    END;

    -- Step 1: Open run
    CALL sp_start_recon_run(p_run_date, v_run_id);

    -- Step 2: Count source records (for run log)
    SELECT COUNT(*) INTO v_comp_count FROM company_transactions WHERE is_duplicate = 0;
    SELECT COUNT(*) INTO v_bank_count FROM bank_transactions   WHERE is_duplicate = 0;
    SELECT COUNT(*) INTO v_gw_count   FROM gateway_transactions WHERE is_duplicate = 0;

    UPDATE recon_run_log
    SET total_company_txns = v_comp_count,
        total_bank_txns    = v_bank_count,
        total_gateway_txns = v_gw_count
    WHERE run_id = v_run_id;

    -- Step 3: Detect duplicates
    CALL sp_detect_duplicates(v_run_id);

    -- Step 4: Core reconciliation
    CALL sp_reconcile_transactions(v_run_id, p_run_date);

    -- Step 5: Update run counts
    UPDATE recon_run_log rl
    JOIN (
        SELECT
            SUM(CASE WHEN result_type = 'MATCHED'         THEN 1 ELSE 0 END) AS m,
            SUM(CASE WHEN result_type = 'MISSING_BANK'    THEN 1 ELSE 0 END) AS mb,
            SUM(CASE WHEN result_type = 'MISSING_GATEWAY' THEN 1 ELSE 0 END) AS mg,
            SUM(CASE WHEN result_type = 'AMOUNT_MISMATCH' THEN 1 ELSE 0 END) AS mm,
            SUM(CASE WHEN result_type LIKE 'DUPLICATE%'   THEN 1 ELSE 0 END) AS dup
        FROM reconciliation_results
        WHERE run_id = v_run_id
    ) agg
    SET rl.matched_count      = agg.m,
        rl.missing_bank_count = agg.mb,
        rl.missing_gw_count   = agg.mg,
        rl.mismatch_count     = agg.mm,
        rl.duplicate_count    = agg.dup
    WHERE rl.run_id = v_run_id;

    -- Step 6: Generate daily summary
    CALL sp_generate_daily_summary(v_run_id, p_run_date);

    -- Step 7: Close run
    UPDATE recon_run_log
    SET status = 'COMPLETED', completed_at = NOW(3)
    WHERE run_id = v_run_id;

    INSERT INTO audit_log (log_level, source_table, operation, record_id, performed_by, message)
    VALUES ('INFO', 'recon_run_log', 'RUN_COMPLETED', v_run_id, 'SYSTEM',
            CONCAT('Full reconciliation COMPLETED. run_id=', v_run_id,
                   ', date=', p_run_date));

    -- Return summary to caller
    SELECT
        v_run_id                AS run_id,
        p_run_date              AS reconciliation_date,
        v_comp_count            AS total_company_txns,
        v_bank_count            AS total_bank_txns,
        v_gw_count              AS total_gateway_txns,
        matched_count,
        missing_bank_count,
        missing_gw_count,
        mismatch_count,
        duplicate_count,
        status,
        completed_at
    FROM recon_run_log
    WHERE run_id = v_run_id;
END$$

-- ============================================================
-- Procedure 6: sp_resolve_exception
-- Marks a reconciliation exception as resolved.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_resolve_exception$$
CREATE PROCEDURE sp_resolve_exception(
    IN p_recon_id      BIGINT UNSIGNED,
    IN p_resolved_by   VARCHAR(100),
    IN p_notes         TEXT
)
BEGIN
    DECLARE v_exists INT;

    SELECT COUNT(*) INTO v_exists
    FROM reconciliation_results
    WHERE recon_id = p_recon_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Exception record not found';
    END IF;

    UPDATE reconciliation_results
    SET resolved     = 1,
        resolved_at  = NOW(3),
        resolved_by  = p_resolved_by,
        exception_notes = CONCAT_WS(' | RESOLUTION: ', exception_notes, p_notes)
    WHERE recon_id = p_recon_id;

    -- Also close any open workflow items
    UPDATE exception_workflow
    SET workflow_status  = 'RESOLVED',
        resolution_notes = p_notes,
        closed_at        = NOW(3)
    WHERE recon_id = p_recon_id
      AND workflow_status NOT IN ('RESOLVED','ESCALATED');

    INSERT INTO audit_log (log_level, source_table, operation, record_id, performed_by, message)
    VALUES ('INFO', 'reconciliation_results', 'EXCEPTION_RESOLVED',
            p_recon_id, p_resolved_by,
            CONCAT('Exception ', p_recon_id, ' resolved: ', LEFT(p_notes, 200)));
END$$

DELIMITER ;

-- ================================================================
-- Execute the full reconciliation for today's date
-- ================================================================
CALL sp_run_full_reconciliation(CURDATE());

-- -----------------------------------------------------------------------
-- End of procedures.sql
-- -----------------------------------------------------------------------
