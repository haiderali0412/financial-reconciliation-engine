-- =============================================================================
-- Enterprise Financial Data Reconciliation & Exception Management Engine
-- File: database/indexes.sql
-- Description: Performance indexes + EXPLAIN execution plan analysis
--
-- Execution Order: 6th (after views.sql)
-- Dependencies: schema.sql
--
-- Indexes are grouped by:
--   A. Composite covering indexes for the reconciliation join queries
--   B. Full-text index for description search
--   C. EXPLAIN plans showing before/after index usage
-- =============================================================================

USE fin_reconciliation;

-- -----------------------------------------------------------------------
-- A. COMPOSITE COVERING INDEXES
-- -----------------------------------------------------------------------
-- Strategy: "covering index" = index includes all columns the query needs,
-- so MySQL reads only the index (no table row lookup = Index Only Scan).

-- ---- company_transactions ----

-- Supports: reconciliation join on reference_no + currency + duplicate flag
-- Query pattern: WHERE is_duplicate=0 AND currency_code=? → ORDER BY transaction_date
ALTER TABLE company_transactions
    ADD INDEX IF NOT EXISTS idx_comp_ref_curr_dup
        (reference_no, currency_code, is_duplicate, transaction_date, amount);

-- Supports: customer-level aggregation and variance view
ALTER TABLE company_transactions
    ADD INDEX IF NOT EXISTS idx_comp_cust_date_amt
        (customer_id, transaction_date, amount, currency_code);

-- ---- bank_transactions ----

-- Supports: bank ↔ company match via description LIKE '%REF%'
-- Note: LIKE '%...%' cannot use a prefix B-Tree index; use FULLTEXT instead (see below).
-- This composite index helps when description is used with status filters:
ALTER TABLE bank_transactions
    ADD INDEX IF NOT EXISTS idx_bank_status_date_net
        (status, is_duplicate, value_date, net_amount, currency_code);

-- Supports: duplicate detection join on (net_amount, value_date)
ALTER TABLE bank_transactions
    ADD INDEX IF NOT EXISTS idx_bank_dup_detect
        (net_amount, value_date, is_duplicate);

-- ---- gateway_transactions ----

-- Supports: gateway ↔ company match on order_id = reference_no
ALTER TABLE gateway_transactions
    ADD INDEX IF NOT EXISTS idx_gw_order_curr_dup
        (order_id, currency_code, is_duplicate, amount);

-- Supports: gateway duplicate detection (order_id + amount)
ALTER TABLE gateway_transactions
    ADD INDEX IF NOT EXISTS idx_gw_dup_detect
        (order_id, amount, is_duplicate);

-- ---- reconciliation_results ----

-- Supports: vw_unresolved_exceptions WHERE resolved=0 ORDER BY amount_variance
ALTER TABLE reconciliation_results
    ADD INDEX IF NOT EXISTS idx_recon_unresolved
        (resolved, result_type, recon_date, amount_variance);

-- Supports: sp_generate_daily_summary aggregation
ALTER TABLE reconciliation_results
    ADD INDEX IF NOT EXISTS idx_recon_date_type_curr
        (recon_date, result_type, currency_code, run_id);

-- Supports: exception resolution lookup
ALTER TABLE reconciliation_results
    ADD INDEX IF NOT EXISTS idx_recon_comp_run
        (company_txn_id, run_id, result_type);

-- ---- daily_recon_summary ----

-- Supports: vw_monthly_recon_trend GROUP BY month
ALTER TABLE daily_recon_summary
    ADD INDEX IF NOT EXISTS idx_drs_date_curr
        (summary_date, currency_code, run_id);

-- ---- audit_log ----

-- Supports: audit trail queries filtered by date range + level
ALTER TABLE audit_log
    ADD INDEX IF NOT EXISTS idx_audit_ts_level
        (log_timestamp, log_level, source_table);

-- -----------------------------------------------------------------------
-- B. FULL-TEXT INDEX for description search
-- -----------------------------------------------------------------------
-- MySQL FULLTEXT index enables fast MATCH() AGAINST() searches,
-- which is vastly more efficient than LIKE '%keyword%' for large tables.

ALTER TABLE bank_transactions
    ADD FULLTEXT INDEX IF NOT EXISTS ft_bank_description (description);

ALTER TABLE company_transactions
    ADD FULLTEXT INDEX IF NOT EXISTS ft_comp_description (description);

-- Usage example (run after index creation):
-- SELECT * FROM bank_transactions
-- WHERE MATCH(description) AGAINST ('REF-A001' IN BOOLEAN MODE);

-- -----------------------------------------------------------------------
-- C. EXPLAIN PLAN ANALYSIS
-- -----------------------------------------------------------------------
-- The EXPLAIN keyword shows MySQL's query execution plan.
-- Key columns to watch:
--   type:  'ALL' = full table scan (BAD), 'ref'/'range'/'index' = index used (GOOD)
--   key:   which index was chosen
--   rows:  estimated rows scanned (lower = better)
--   Extra: 'Using index' = covering index (best), 'Using filesort' (needs index on ORDER BY)

-- ----- Query 1: Reconciliation join (the most critical query) -----
EXPLAIN FORMAT=TRADITIONAL
SELECT
    ct.company_txn_id,
    ct.reference_no,
    ct.amount               AS company_amount,
    bt.bank_txn_id,
    bt.net_amount           AS bank_amount,
    gt.gateway_txn_id,
    gt.amount               AS gateway_amount
FROM company_transactions ct
LEFT JOIN bank_transactions bt
       ON bt.description LIKE CONCAT('%', ct.reference_no, '%')
      AND bt.currency_code = ct.currency_code
      AND bt.is_duplicate  = 0
LEFT JOIN gateway_transactions gt
       ON gt.order_id      = ct.reference_no
      AND gt.currency_code = ct.currency_code
      AND gt.is_duplicate  = 0
WHERE ct.is_duplicate = 0
  AND ct.currency_code = 'USD';

-- Expected plan AFTER indexes:
--   ct  → type: ref,   key: idx_comp_ref_curr_dup  (uses is_duplicate + currency_code)
--   bt  → type: ALL    (LIKE '%...%' still needs full scan; FULLTEXT avoids this)
--   gt  → type: ref,   key: idx_gw_order_curr_dup  (uses order_id + currency_code)

-- ----- Query 2: Unresolved exceptions (worklist) -----
EXPLAIN FORMAT=TRADITIONAL
SELECT rr.recon_id, rr.recon_date, rr.result_type, rr.amount_variance
FROM reconciliation_results rr
WHERE rr.resolved = 0
  AND rr.result_type <> 'MATCHED'
ORDER BY ABS(rr.amount_variance) DESC
LIMIT 50;

-- Expected plan AFTER indexes:
--   rr → type: ref, key: idx_recon_unresolved (resolved=0 → index range on result_type)

-- ----- Query 3: Monthly trend aggregation -----
EXPLAIN FORMAT=TRADITIONAL
SELECT
    DATE_FORMAT(drs.summary_date, '%Y-%m') AS month_key,
    SUM(drs.matched_count)                  AS matched,
    SUM(drs.total_transactions)             AS total
FROM daily_recon_summary drs
WHERE drs.currency_code = 'USD'
GROUP BY DATE_FORMAT(drs.summary_date, '%Y-%m')
ORDER BY month_key;

-- Expected plan AFTER indexes:
--   drs → type: ref, key: idx_drs_date_curr (currency_code lookup + summary_date range)

-- ----- Query 4: Customer variance ranking -----
EXPLAIN FORMAT=TRADITIONAL
SELECT
    ct.customer_id,
    SUM(ABS(rr.amount_variance)) AS total_variance
FROM company_transactions ct
LEFT JOIN reconciliation_results rr ON rr.company_txn_id = ct.company_txn_id
WHERE ct.is_duplicate = 0
GROUP BY ct.customer_id
ORDER BY total_variance DESC
LIMIT 10;

-- Expected plan AFTER indexes:
--   ct  → type: ref, key: idx_comp_cust_date_amt
--   rr  → type: ref, key: idx_recon_comp_run  (company_txn_id lookup)

-- ----- ANALYZE TABLE — updates optimizer statistics -----
-- Run this after bulk inserts to ensure optimizer uses fresh stats:
ANALYZE TABLE company_transactions;
ANALYZE TABLE bank_transactions;
ANALYZE TABLE gateway_transactions;
ANALYZE TABLE reconciliation_results;
ANALYZE TABLE daily_recon_summary;

-- -----------------------------------------------------------------------
-- End of indexes.sql
-- -----------------------------------------------------------------------
