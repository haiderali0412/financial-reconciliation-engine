-- =============================================================================
-- Enterprise Financial Data Reconciliation & Exception Management Engine
-- File: database/views.sql
-- Description: Analytical views for reporting, dashboards, and ad-hoc queries
--
-- Execution Order: 5th (after procedures.sql)
-- Dependencies: schema.sql, sample_data.sql, procedures.sql
--
-- Views defined:
--   vw_reconciliation_dashboard   - Live KPI snapshot for BI tools
--   vw_exception_summary          - Grouped exception counts by type & date
--   vw_matched_transactions       - Full detail of matched transactions
--   vw_unresolved_exceptions      - Open exceptions requiring human action
--   vw_duplicate_transactions     - All flagged duplicates across sources
--   vw_monthly_recon_trend        - Month-over-month reconciliation rates
--   vw_top_customers_by_variance  - Customers with the highest total variance
--   vw_daily_cash_position        - Net daily cash flow reconciled view
-- =============================================================================

USE fin_reconciliation;

-- ============================================================
-- View 1: vw_reconciliation_dashboard
-- Live KPI snapshot — joins the latest run to aggregated results.
-- Uses a correlated subquery to get the most recent run.
-- ============================================================
CREATE OR REPLACE VIEW vw_reconciliation_dashboard AS
WITH latest_run AS (
    SELECT run_id, run_date, completed_at, status,
           total_company_txns, total_bank_txns, total_gateway_txns
    FROM recon_run_log
    WHERE run_id = (SELECT MAX(run_id) FROM recon_run_log WHERE status = 'COMPLETED')
),
exception_counts AS (
    SELECT
        rr.run_id,
        COUNT(*)                                                                 AS total_recon_records,
        SUM(CASE WHEN rr.result_type = 'MATCHED'          THEN 1 ELSE 0 END)    AS matched,
        SUM(CASE WHEN rr.result_type = 'MISSING_BANK'     THEN 1 ELSE 0 END)    AS missing_bank,
        SUM(CASE WHEN rr.result_type = 'MISSING_GATEWAY'  THEN 1 ELSE 0 END)    AS missing_gateway,
        SUM(CASE WHEN rr.result_type = 'AMOUNT_MISMATCH'  THEN 1 ELSE 0 END)    AS amount_mismatch,
        SUM(CASE WHEN rr.result_type LIKE 'DUPLICATE%'    THEN 1 ELSE 0 END)    AS duplicates,
        SUM(CASE WHEN rr.result_type LIKE 'UNMATCHED%'    THEN 1 ELSE 0 END)    AS unmatched,
        COALESCE(SUM(ABS(rr.amount_variance)), 0)                                AS total_abs_variance,
        SUM(CASE WHEN rr.resolved = 0
                  AND rr.result_type NOT IN ('MATCHED')    THEN 1 ELSE 0 END)   AS open_exceptions
    FROM reconciliation_results rr
    JOIN latest_run lr ON lr.run_id = rr.run_id
    GROUP BY rr.run_id
)
SELECT
    lr.run_id,
    lr.run_date                     AS reconciliation_date,
    lr.status                       AS run_status,
    lr.completed_at,
    lr.total_company_txns,
    lr.total_bank_txns,
    lr.total_gateway_txns,
    ec.matched,
    ec.missing_bank,
    ec.missing_gateway,
    ec.amount_mismatch,
    ec.duplicates,
    ec.unmatched,
    ec.open_exceptions,
    ec.total_abs_variance,
    -- Reconciliation rate = matched / total company (non-duplicate) txns
    CASE
        WHEN lr.total_company_txns = 0 THEN 0
        ELSE ROUND((ec.matched / lr.total_company_txns) * 100, 2)
    END                             AS reconciliation_rate_pct
FROM latest_run lr
LEFT JOIN exception_counts ec ON ec.run_id = lr.run_id;

-- ============================================================
-- View 2: vw_exception_summary
-- Daily exception counts grouped by result_type for trend analysis.
-- ============================================================
CREATE OR REPLACE VIEW vw_exception_summary AS
SELECT
    rr.recon_date,
    rr.result_type,
    rrt.description                        AS result_description,
    rr.currency_code,
    COUNT(*)                               AS exception_count,
    COALESCE(SUM(rr.company_amount), 0)   AS total_company_amount,
    COALESCE(SUM(ABS(rr.amount_variance)),0) AS total_variance,
    SUM(CASE WHEN rr.resolved = 1 THEN 1 ELSE 0 END) AS resolved_count,
    SUM(CASE WHEN rr.resolved = 0 THEN 1 ELSE 0 END) AS open_count
FROM reconciliation_results rr
JOIN ref_recon_result_type rrt ON rrt.result_type = rr.result_type
GROUP BY rr.recon_date, rr.result_type, rrt.description, rr.currency_code
ORDER BY rr.recon_date DESC, exception_count DESC;

-- ============================================================
-- View 3: vw_matched_transactions
-- Full detail of MATCHED transactions across all three sources.
-- ============================================================
CREATE OR REPLACE VIEW vw_matched_transactions AS
SELECT
    rr.recon_id,
    rr.recon_date,
    rr.currency_code,
    -- Company fields
    ct.transaction_id      AS company_txn_id,
    ct.transaction_date    AS company_date,
    ct.customer_id,
    ct.amount              AS company_amount,
    ct.payment_method,
    ct.reference_no,
    -- Bank fields
    bt.bank_ref,
    bt.value_date          AS bank_value_date,
    bt.net_amount          AS bank_amount,
    -- Gateway fields
    gt.gateway_txn_ref,
    DATE(gt.txn_datetime)  AS gateway_date,
    gt.amount              AS gateway_amount,
    gt.gateway_status,
    -- Variance
    rr.amount_variance,
    rr.matched_on
FROM reconciliation_results rr
JOIN company_transactions ct ON ct.company_txn_id = rr.company_txn_id
LEFT JOIN bank_transactions bt ON bt.bank_txn_id  = rr.bank_txn_id
LEFT JOIN gateway_transactions gt ON gt.gateway_txn_id = rr.gateway_txn_id
WHERE rr.result_type = 'MATCHED'
ORDER BY rr.recon_date DESC;

-- ============================================================
-- View 4: vw_unresolved_exceptions
-- All open exceptions enriched with source-table details.
-- Useful as a worklist for the operations team.
-- ============================================================
CREATE OR REPLACE VIEW vw_unresolved_exceptions AS
SELECT
    rr.recon_id,
    rr.recon_date,
    rr.result_type,
    rr.currency_code,
    -- Company side
    ct.transaction_id      AS company_txn_id,
    ct.customer_id,
    ct.amount              AS company_amount,
    ct.reference_no        AS company_ref,
    -- Bank side
    bt.bank_ref,
    bt.net_amount          AS bank_amount,
    -- Gateway side
    gt.gateway_txn_ref,
    gt.amount              AS gateway_amount,
    -- Variance
    rr.amount_variance,
    rr.exception_notes,
    -- Days open
    DATEDIFF(CURDATE(), rr.recon_date)  AS days_open,
    -- Priority hint based on amount
    CASE
        WHEN ABS(rr.amount_variance) >= 10000 THEN 'CRITICAL'
        WHEN ABS(rr.amount_variance) >= 1000  THEN 'HIGH'
        WHEN ABS(rr.amount_variance) >= 100   THEN 'MEDIUM'
        ELSE                                       'LOW'
    END                               AS suggested_priority
FROM reconciliation_results rr
LEFT JOIN company_transactions  ct ON ct.company_txn_id  = rr.company_txn_id
LEFT JOIN bank_transactions     bt ON bt.bank_txn_id     = rr.bank_txn_id
LEFT JOIN gateway_transactions  gt ON gt.gateway_txn_id  = rr.gateway_txn_id
WHERE rr.resolved = 0
  AND rr.result_type <> 'MATCHED'
ORDER BY ABS(rr.amount_variance) DESC, rr.recon_date;

-- ============================================================
-- View 5: vw_duplicate_transactions
-- All flagged duplicates across all three source tables.
-- ============================================================
CREATE OR REPLACE VIEW vw_duplicate_transactions AS
SELECT
    'COMPANY'               AS source_table,
    ct.company_txn_id       AS txn_pk,
    ct.transaction_id       AS business_key,
    ct.transaction_date     AS txn_date,
    ct.amount,
    ct.currency_code,
    ct.reference_no,
    ct.duplicate_of_id      AS original_pk
FROM company_transactions ct
WHERE ct.is_duplicate = 1

UNION ALL

SELECT
    'BANK'                  AS source_table,
    bt.bank_txn_id          AS txn_pk,
    bt.bank_ref             AS business_key,
    bt.value_date           AS txn_date,
    bt.net_amount           AS amount,
    bt.currency_code,
    bt.description          AS reference_no,
    bt.duplicate_of_id      AS original_pk
FROM bank_transactions bt
WHERE bt.is_duplicate = 1

UNION ALL

SELECT
    'GATEWAY'               AS source_table,
    gt.gateway_txn_id       AS txn_pk,
    gt.gateway_txn_ref      AS business_key,
    DATE(gt.txn_datetime)   AS txn_date,
    gt.amount,
    gt.currency_code,
    gt.order_id             AS reference_no,
    gt.duplicate_of_id      AS original_pk
FROM gateway_transactions gt
WHERE gt.is_duplicate = 1

ORDER BY source_table, txn_date;

-- ============================================================
-- View 6: vw_monthly_recon_trend
-- Month-over-month aggregation using DATE_FORMAT and window functions.
-- Shows running totals and month-on-month change in reconciliation rate.
-- ============================================================
CREATE OR REPLACE VIEW vw_monthly_recon_trend AS
WITH monthly AS (
    SELECT
        DATE_FORMAT(drs.summary_date, '%Y-%m')    AS month_key,
        MIN(drs.summary_date)                      AS month_start,
        SUM(drs.total_transactions)                AS total_txns,
        SUM(drs.matched_count)                     AS matched,
        SUM(drs.missing_bank_count)                AS missing_bank,
        SUM(drs.missing_gw_count)                  AS missing_gateway,
        SUM(drs.mismatch_count)                    AS amount_mismatches,
        SUM(drs.duplicate_count)                   AS duplicates,
        SUM(drs.total_company_amount)              AS total_company_amount,
        SUM(ABS(drs.total_variance))               AS total_variance,
        CASE
            WHEN SUM(drs.total_transactions) = 0 THEN 0
            ELSE ROUND(SUM(drs.matched_count) / SUM(drs.total_transactions) * 100, 2)
        END                                        AS recon_rate_pct
    FROM daily_recon_summary drs
    GROUP BY DATE_FORMAT(drs.summary_date, '%Y-%m')
)
SELECT
    month_key,
    month_start,
    total_txns,
    matched,
    missing_bank,
    missing_gateway,
    amount_mismatches,
    duplicates,
    total_company_amount,
    total_variance,
    recon_rate_pct,
    -- Running cumulative matched count
    SUM(matched) OVER (ORDER BY month_key ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                           AS cumulative_matched,
    -- Month-over-month rate change
    recon_rate_pct - LAG(recon_rate_pct, 1, recon_rate_pct) OVER (ORDER BY month_key)
                                           AS mom_rate_change_pct
FROM monthly
ORDER BY month_key;

-- ============================================================
-- View 7: vw_top_customers_by_variance
-- Customers with the most total amount variance across exceptions.
-- Useful for detecting systemic issues with specific customers.
-- ============================================================
CREATE OR REPLACE VIEW vw_top_customers_by_variance AS
SELECT
    ct.customer_id,
    COUNT(DISTINCT rr.recon_id)              AS exception_count,
    COUNT(DISTINCT ct.company_txn_id)        AS total_transactions,
    COALESCE(SUM(ct.amount), 0)             AS total_amount,
    COALESCE(SUM(ABS(rr.amount_variance)),0) AS total_variance,
    ROUND(
        COALESCE(SUM(ABS(rr.amount_variance)),0)
        / NULLIF(SUM(ct.amount),0) * 100, 2
    )                                        AS variance_pct,
    -- Rank customers by variance descending
    RANK() OVER (ORDER BY COALESCE(SUM(ABS(rr.amount_variance)),0) DESC)
                                             AS variance_rank
FROM company_transactions ct
LEFT JOIN reconciliation_results rr ON rr.company_txn_id = ct.company_txn_id
                                    AND rr.result_type <> 'MATCHED'
WHERE ct.is_duplicate = 0
GROUP BY ct.customer_id
HAVING exception_count > 0
ORDER BY total_variance DESC;

-- ============================================================
-- View 8: vw_daily_cash_position
-- Daily reconciled cash position: bank vs company ledger.
-- ============================================================
CREATE OR REPLACE VIEW vw_daily_cash_position AS
SELECT
    base.txn_date,
    base.currency_code,
    COALESCE(SUM(base.company_amount), 0)    AS company_ledger_total,
    COALESCE(SUM(base.bank_amount),    0)    AS bank_statement_total,
    COALESCE(SUM(base.company_amount), 0)
        - COALESCE(SUM(base.bank_amount), 0) AS daily_variance,
    COUNT(*)                                 AS transaction_count,
    -- Running balance of variance
    SUM(
        COALESCE(SUM(base.company_amount), 0)
        - COALESCE(SUM(base.bank_amount), 0)
    ) OVER (
        PARTITION BY base.currency_code
        ORDER BY base.txn_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                        AS running_variance_balance
FROM (
    SELECT
        rr.recon_date     AS txn_date,
        rr.currency_code,
        rr.company_amount,
        rr.bank_amount
    FROM reconciliation_results rr
    WHERE rr.result_type IN ('MATCHED','AMOUNT_MISMATCH','MISSING_BANK')
) base
GROUP BY base.txn_date, base.currency_code
ORDER BY base.currency_code, base.txn_date;

-- -----------------------------------------------------------------------
-- End of views.sql
-- -----------------------------------------------------------------------
