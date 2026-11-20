# Enterprise Financial Data Reconciliation & Exception Management Engine

<div align="center">

![MySQL](https://img.shields.io/badge/MySQL-8.0-blue?logo=mysql&logoColor=white)
![SQL](https://img.shields.io/badge/Language-SQL-orange)
![Status](https://img.shields.io/badge/Status-Portfolio%20Ready-brightgreen)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

**A production-grade MySQL 8.0 database project demonstrating advanced data engineering patterns for financial reconciliation.**

</div>

---

## 📋 Business Problem

A B2B SaaS company processes thousands of payments daily through **three independent systems**: its own ERP, its banking partner, and a third-party payment gateway. Due to timing differences, bank fees, system outages, and double-submissions, these systems regularly disagree.

The finance team was spending **~40 hours/month** manually reconciling in Excel, with high-value mismatches going undetected until month-end close.

**This project automates the entire reconciliation workflow:**
- Ingests raw data from all three sources
- Cleans, validates, and deduplicates records
- Classifies every transaction (Matched / Missing / Mismatch / Duplicate)
- Routes exceptions to the right team for resolution
- Generates nightly summary reports and audit trails

---

## 🏗️ Project Structure

```
fin-reconciliation-engine/
│
├── database/
│   ├── schema.sql          ← All tables, FKs, generated columns, indexes (run 1st)
│   ├── sample_data.sql     ← 500+ realistic transaction records (run 2nd)
│   ├── transformations.sql ← Staging ETL, validation, deduplication (run 3rd)
│   ├── procedures.sql      ← 6 stored procedures + reconciliation run (run 4th)
│   ├── views.sql           ← 8 analytical views for reporting (run 5th)
│   ├── indexes.sql         ← Composite/FULLTEXT indexes + EXPLAIN plans (run 6th)
│   └── tests.sql           ← 25+ test cases with PASS/FAIL assertions (run 7th)
│
├── documentation/
│   └── architecture.md     ← ERD, flow diagrams, algorithm documentation
│
└── README.md               ← This file
```

---

## 🚀 Setup Instructions (MySQL Workbench)

### Prerequisites
- MySQL Server **8.0+** installed and running
- MySQL Workbench **8.0+** (or any MySQL 8.0-compatible client)
- `utf8mb4` character set support (default in MySQL 8.0)

### Step-by-Step Setup

**1. Open MySQL Workbench** and connect to your local MySQL instance.

**2. Run scripts in order** using `File → Open SQL Script` then `⚡ Execute`:

| Order | File | What it does |
|-------|------|-------------|
| 1 | `database/schema.sql` | Creates `fin_reconciliation` database + 14 tables |
| 2 | `database/sample_data.sql` | Seeds 200 company + 200 bank + 160 gateway records |
| 3 | `database/transformations.sql` | Runs staging ETL with validation and dedup |
| 4 | `database/procedures.sql` | Creates 6 stored procedures and runs reconciliation |
| 5 | `database/views.sql` | Creates 8 analytical views |
| 6 | `database/indexes.sql` | Adds covering indexes and shows EXPLAIN plans |
| 7 | `database/tests.sql` | Runs 25+ assertions to verify correctness |

> [!IMPORTANT]
> Run each file completely before moving to the next. Each script depends on the previous ones.

**3. Quick verification** — after all scripts run:

```sql
USE fin_reconciliation;

-- Check reconciliation results
SELECT result_type, COUNT(*) AS count
FROM reconciliation_results
GROUP BY result_type
ORDER BY count DESC;

-- Check daily summary
SELECT * FROM vw_reconciliation_dashboard;

-- View open exceptions
SELECT * FROM vw_unresolved_exceptions LIMIT 20;
```

---

## 📊 Data Model at a Glance

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `company_transactions` | ERP/accounting ledger | `transaction_id`, `reference_no`, `amount` |
| `bank_transactions` | Bank statement feed | `bank_ref`, `net_amount` (generated), `value_date` |
| `gateway_transactions` | Payment gateway events | `gateway_txn_ref`, `order_id`, `amount` |
| `reconciliation_results` | Classification output | `result_type`, `amount_variance` (generated) |
| `recon_run_log` | Nightly run tracker | `run_id`, `status`, `matched_count` |
| `daily_recon_summary` | Pre-aggregated KPIs | `reconciliation_rate` (generated) |
| `exception_workflow` | Human resolution tracker | `priority`, `workflow_status` |
| `audit_log` | Full audit trail | `log_level`, `operation`, `message` |
| `stg_*` (3 tables) | Staging/raw data | `validation_errors`, `is_processed` |
| `ref_*` (4 tables) | Lookup/reference data | Currency, Status, Payment Method |

---

## 🔍 Reconciliation Classifications

| Classification | Description | Sample Count |
|---------------|-------------|-------------|
| `MATCHED` | All 3 sources agree (within \$0.01) | ~140 |
| `MISSING_BANK` | In company ledger, absent from bank | ~7 |
| `MISSING_GATEWAY` | In company ledger, absent from gateway | ~40 |
| `AMOUNT_MISMATCH` | Matched by reference, amounts differ | ~10 |
| `UNMATCHED_BANK` | Bank-only credit (no company record) | 5 |
| `UNMATCHED_GATEWAY` | Gateway-only transaction | 4 |
| `DUPLICATE_COMPANY` | Double-entry in ERP | 3 |
| `DUPLICATE_BANK` | Double-entry in bank feed | 3 |
| `DUPLICATE_GATEWAY` | Double-entry from gateway | 2 |

---

## 🛠️ Key SQL Techniques Demonstrated

### Window Functions
```sql
-- Duplicate detection using ROW_NUMBER()
ROW_NUMBER() OVER (PARTITION BY reference_no, amount ORDER BY company_txn_id)

-- Running variance balance using SUM() OVER
SUM(daily_variance) OVER (PARTITION BY currency_code ORDER BY txn_date ROWS UNBOUNDED PRECEDING)

-- Month-over-month rate change using LAG()
recon_rate_pct - LAG(recon_rate_pct, 1) OVER (ORDER BY month_key)

-- Customer variance ranking using RANK()
RANK() OVER (ORDER BY SUM(ABS(amount_variance)) DESC)
```

### CTEs (Common Table Expressions)
```sql
-- Multi-step reconciliation matching
WITH company_base AS (...),
     bank_base    AS (...),
     gateway_base AS (...),
     comp_bank    AS (...),
     full_match   AS (...)
SELECT ... FROM full_match WHERE ...
```

### Generated Columns
```sql
-- Bank net amount (computed, never stored twice)
net_amount DECIMAL(18,2) GENERATED ALWAYS AS (credit_amount - debit_amount) STORED

-- Reconciliation variance
amount_variance DECIMAL(18,2) GENERATED ALWAYS AS (
    COALESCE(company_amount, 0) - COALESCE(bank_amount, 0)
) STORED

-- Reconciliation rate
reconciliation_rate DECIMAL(5,2) GENERATED ALWAYS AS (
    CASE WHEN total_transactions = 0 THEN 0
    ELSE ROUND((matched_count / total_transactions) * 100, 2) END
) STORED
```

### Transaction Handling & Error Recovery
```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
    GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
    UPDATE recon_run_log SET status = 'FAILED', error_message = @msg WHERE run_id = v_run_id;
    INSERT INTO audit_log ... VALUES ('ERROR', ...);
    RESIGNAL;
END;
```

---

## ⚡ Running the Reconciliation Procedure

After setup, you can run reconciliation for any date:

```sql
-- Run for today
CALL sp_run_full_reconciliation(CURDATE());

-- Run for a specific historical date
CALL sp_run_full_reconciliation('2025-03-31');

-- Resolve a specific exception manually
CALL sp_resolve_exception(
    42,                              -- recon_id
    'finance_analyst@company.com',   -- resolved_by
    'Bank confirmed: processing delay on 2025-03-31. No action needed.'
);
```

---

## 📈 Key Reports (Views)

```sql
-- 1. Live dashboard KPIs
SELECT * FROM vw_reconciliation_dashboard;

-- 2. All open exceptions, sorted by severity
SELECT * FROM vw_unresolved_exceptions LIMIT 50;

-- 3. Month-over-month reconciliation trend
SELECT month_key, recon_rate_pct, mom_rate_change_pct
FROM vw_monthly_recon_trend;

-- 4. Top 10 customers by outstanding variance
SELECT customer_id, total_variance, variance_rank
FROM vw_top_customers_by_variance
LIMIT 10;

-- 5. Daily cash position
SELECT txn_date, company_ledger_total, bank_statement_total,
       daily_variance, running_variance_balance
FROM vw_daily_cash_position
ORDER BY txn_date DESC;

-- 6. Exception breakdown by type and date
SELECT recon_date, result_type, exception_count, total_variance
FROM vw_exception_summary
ORDER BY recon_date DESC;
```

---

## 🧪 Running Tests

```sql
-- Run all tests (produces PASS/FAIL per test case)
SOURCE database/tests.sql;

-- Or in MySQL Workbench: File → Open SQL Script → tests.sql → Execute
```

Expected output: **25+ test rows**, all showing `PASS`.

---

## 🧰 Technologies & Concepts

| Category | Details |
|----------|---------|
| **Database** | MySQL 8.0 |
| **Normalization** | 3NF with lookup/reference tables |
| **Window Functions** | `ROW_NUMBER`, `RANK`, `LAG`, `LEAD`, `FIRST_VALUE`, `SUM OVER` |
| **CTEs** | Multi-step reconciliation logic |
| **Stored Procedures** | 6 procedures with error handlers and audit logging |
| **Views** | 8 analytical views including `CREATE OR REPLACE` |
| **Indexes** | Composite covering indexes + FULLTEXT + EXPLAIN analysis |
| **Transactions** | `START TRANSACTION` / `COMMIT` with `EXIT HANDLER` |
| **Generated Columns** | `GENERATED ALWAYS AS ... STORED` for computed fields |
| **Upserts** | `INSERT ... ON DUPLICATE KEY UPDATE` |
| **Data Types** | `DECIMAL(18,2)`, `DATETIME(3)`, `TINYINT(1)`, `ENUM`, `CHAR(3)` |
| **Character Set** | `utf8mb4` / `utf8mb4_unicode_ci` |

---

## 📁 Suitable For

- **Fresher / Junior Data Engineer portfolio** — demonstrates real-world ETL, reconciliation, and reporting patterns
- **Data Analyst with SQL focus** — advanced query techniques and aggregation
- **Database Developer** — stored procedures, views, indexes, generated columns
- **Finance Tech / FinTech domains** — domain-specific problem with industry patterns

---

## 📄 License

MIT — free to use, modify, and share with attribution.

---

<div align="center">
<b>Built with ❤️ as a portfolio-grade Data Engineering showcase project.</b>
</div>
