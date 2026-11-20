# Architecture — Enterprise Financial Data Reconciliation & Exception Management Engine

## Business Problem Statement

> **Scenario:** A mid-sized B2B SaaS company processes thousands of financial transactions daily through three independent systems: its own ERP/accounting system, its banking partner, and a third-party payment gateway. Due to timing differences, bank fees, system outages, and occasional double-submissions, these three systems regularly disagree.
>
> The finance team currently reconciles these records **manually in Excel**, spending ~40 hours per month identifying discrepancies. Even then, mismatches worth thousands of dollars go undetected until the monthly close. The company needs a **fully automated, auditable reconciliation engine** that runs nightly, classifies every exception, and routes it to the right team for resolution.

---

## System Overview

```mermaid
flowchart TD
    subgraph Sources["Data Sources"]
        ERP["🏢 Company ERP\ncompany_transactions"]
        BANK["🏦 Bank Statement\nbank_transactions"]
        GW["💳 Payment Gateway\ngateway_transactions"]
    end

    subgraph Staging["Staging Layer (Raw Ingest)"]
        SCOMP["stg_company_transactions"]
        SBANK["stg_bank_transactions"]
        SGW["stg_gateway_transactions"]
    end

    subgraph ETL["Transformations (transformations.sql)"]
        VAL["Validation\nData Type Checks\nNull Checks"]
        DEDUP["Duplicate Detection\nROW_NUMBER() Window"]
        LOAD["Clean Load\nINSERT … SELECT"]
    end

    subgraph Core["Core Tables (Normalized)"]
        CT["company_transactions"]
        BT["bank_transactions"]
        GT["gateway_transactions"]
    end

    subgraph Recon["Reconciliation Engine (procedures.sql)"]
        RUN["sp_start_recon_run"]
        DUP["sp_detect_duplicates"]
        MATCH["sp_reconcile_transactions\nMatched | Missing Bank | Missing GW\nAmount Mismatch | Unmatched"]
        SUM["sp_generate_daily_summary"]
    end

    subgraph Output["Outputs"]
        RR["reconciliation_results"]
        DRS["daily_recon_summary"]
        AUDIT["audit_log"]
        EW["exception_workflow"]
    end

    subgraph Views["Analytical Views (views.sql)"]
        DASH["vw_reconciliation_dashboard"]
        EXC["vw_unresolved_exceptions"]
        TREND["vw_monthly_recon_trend"]
    end

    ERP  --> SCOMP --> VAL
    BANK --> SBANK --> VAL
    GW   --> SGW   --> VAL
    VAL  --> DEDUP --> LOAD
    LOAD --> CT & BT & GT
    CT & BT & GT --> RUN --> DUP --> MATCH --> SUM
    MATCH --> RR --> EW
    SUM --> DRS
    RUN & DUP & MATCH --> AUDIT
    RR & DRS --> DASH & EXC & TREND
```

---

## Database Schema (ERD)

```mermaid
erDiagram
    ref_currency ||--o{ company_transactions  : "currency_code"
    ref_currency ||--o{ bank_transactions     : "currency_code"
    ref_currency ||--o{ gateway_transactions  : "currency_code"
    ref_transaction_status ||--o{ company_transactions  : "status"
    ref_transaction_status ||--o{ bank_transactions     : "status"
    ref_transaction_status ||--o{ gateway_transactions  : "gateway_status"
    ref_payment_method ||--o{ company_transactions  : "payment_method"
    ref_payment_method ||--o{ gateway_transactions  : "payment_method"
    ref_recon_result_type ||--o{ reconciliation_results : "result_type"

    company_transactions {
        BIGINT company_txn_id PK
        VARCHAR transaction_id UK
        DATE transaction_date
        VARCHAR customer_id
        DECIMAL amount
        CHAR currency_code FK
        VARCHAR payment_method FK
        VARCHAR status FK
        VARCHAR reference_no
        TINYINT is_duplicate
    }

    bank_transactions {
        BIGINT bank_txn_id PK
        VARCHAR bank_ref UK
        DATE value_date
        VARCHAR account_no
        DECIMAL debit_amount
        DECIMAL credit_amount
        DECIMAL net_amount "GENERATED"
        CHAR currency_code FK
        VARCHAR status FK
        TINYINT is_duplicate
    }

    gateway_transactions {
        BIGINT gateway_txn_id PK
        VARCHAR gateway_txn_ref UK
        DATETIME txn_datetime
        VARCHAR merchant_id
        VARCHAR order_id
        DECIMAL amount
        CHAR currency_code FK
        VARCHAR gateway_status FK
        VARCHAR payment_method FK
        TINYINT is_duplicate
    }

    reconciliation_results {
        BIGINT recon_id PK
        DATE recon_date
        VARCHAR result_type FK
        BIGINT company_txn_id FK
        BIGINT bank_txn_id FK
        BIGINT gateway_txn_id FK
        DECIMAL amount_variance "GENERATED"
        TINYINT resolved
        BIGINT run_id FK
    }

    recon_run_log {
        BIGINT run_id PK
        DATE run_date
        ENUM status
        INT matched_count
        INT missing_bank_count
        INT duplicate_count
    }

    exception_workflow {
        BIGINT workflow_id PK
        BIGINT recon_id FK
        ENUM priority
        ENUM workflow_status
    }

    daily_recon_summary {
        BIGINT summary_id PK
        DATE summary_date
        CHAR currency_code
        DECIMAL reconciliation_rate "GENERATED"
    }

    reconciliation_results }o--|| recon_run_log : "run_id"
    exception_workflow }o--|| reconciliation_results : "recon_id"
    daily_recon_summary }o--|| recon_run_log : "run_id"
```

---

## Reconciliation Algorithm

The core matching logic runs in this order inside `sp_reconcile_transactions`:

| Step | Classification | Matching Logic |
|------|---------------|----------------|
| 1 | **MATCHED** | `company.reference_no` found in `bank.description` AND = `gateway.order_id`, amounts within \$0.01 tolerance |
| 2 | **AMOUNT_MISMATCH** | Reference matches but `|company.amount − bank.net_amount| > 0.01` or gateway differs |
| 3 | **MISSING_BANK** | Company record exists but no bank row references its `reference_no` |
| 4 | **MISSING_GATEWAY** | Company record exists but no gateway row has `order_id = reference_no` |
| 5 | **UNMATCHED_BANK** | Bank row cannot be linked to any company record |
| 6 | **UNMATCHED_GATEWAY** | Gateway row cannot be linked to any company record |
| 0 (pre-run) | **DUPLICATE_*** | `ROW_NUMBER() OVER (PARTITION BY reference_no, amount)` > 1 |

> [!NOTE]
> Duplicate detection runs **before** matching. Flagged duplicates are excluded from all subsequent matching steps, ensuring the same transaction is never double-counted.

---

## Execution Order

```mermaid
flowchart LR
    S1["1️⃣ schema.sql\nCreate DB + Tables"] --> S2
    S2["2️⃣ sample_data.sql\nSeed 500+ Records"] --> S3
    S3["3️⃣ transformations.sql\nStaging ETL + Dedup"] --> S4
    S4["4️⃣ procedures.sql\nCreate + Run Procedures"] --> S5
    S5["5️⃣ views.sql\nCreate Analytical Views"] --> S6
    S6["6️⃣ indexes.sql\nCreate Indexes + EXPLAIN"] --> S7
    S7["7️⃣ tests.sql\nRun 25+ Test Cases"]
```

---

## Key SQL Techniques Used

| Technique | File | Purpose |
|-----------|------|---------|
| `ROW_NUMBER() OVER (PARTITION BY ...)` | transformations.sql, procedures.sql | Duplicate detection |
| `LAG() / LEAD() / FIRST_VALUE()` | procedures.sql, views.sql | Sequential analysis and window aggregation |
| `SUM(...) OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)` | views.sql | Running totals |
| `RANK() OVER (ORDER BY ...)` | views.sql | Customer variance ranking |
| Common Table Expressions (CTEs) | procedures.sql, views.sql | Readable multi-step reconciliation |
| `LEFT JOIN` with NOT EXISTS | procedures.sql | Identifying missing counterparts |
| `INSERT ... ON DUPLICATE KEY UPDATE` | procedures.sql | Idempotent daily summary upserts |
| `GENERATED ALWAYS AS ... STORED` | schema.sql | `net_amount`, `amount_variance`, `reconciliation_rate` |
| `FULLTEXT INDEX` + `MATCH() AGAINST()` | indexes.sql | Efficient description search |
| `EXPLAIN FORMAT=TRADITIONAL` | indexes.sql | Query plan analysis |
| `SIGNAL SQLSTATE '45000'` | procedures.sql | Custom error raising |
| `DECLARE EXIT HANDLER FOR SQLEXCEPTION` | procedures.sql | Transaction error handling |

---

## Project File Map

```
fin-reconciliation-engine/
├── database/
│   ├── schema.sql          # 1st — All table definitions, FKs, generated columns
│   ├── sample_data.sql     # 2nd — 500+ realistic seed records
│   ├── transformations.sql # 3rd — Staging → Core ETL with validation
│   ├── procedures.sql      # 4th — 6 stored procedures + run execution
│   ├── views.sql           # 5th — 8 analytical views
│   ├── indexes.sql         # 6th — Covering indexes + EXPLAIN plans
│   └── tests.sql           # 7th — 25+ test assertions
├── documentation/
│   └── architecture.md     # This file
└── README.md               # Setup guide + project overview
```

---

## Performance Considerations

| Query Pattern | Index Strategy | Expected Type |
|--------------|----------------|---------------|
| `WHERE is_duplicate=0 AND currency_code=?` | `idx_comp_ref_curr_dup` | `ref` |
| `WHERE order_id=? AND currency_code=?` | `idx_gw_order_curr_dup` | `ref` |
| `WHERE resolved=0 ORDER BY variance` | `idx_recon_unresolved` | `ref` / `range` |
| `MATCH(description) AGAINST (?)` | `ft_bank_description` | `fulltext` |
| `GROUP BY DATE_FORMAT(summary_date,...)` | `idx_drs_date_curr` | `range` |

> [!TIP]
> Run `ANALYZE TABLE` after each bulk data load to refresh optimizer statistics and ensure the query planner picks the correct indexes.

> [!WARNING]
> The `bank.description LIKE '%reference_no%'` join pattern cannot use a standard B-Tree prefix index. For production volumes > 1M rows, migrate to a **FULLTEXT** search or extract the reference number into a dedicated indexed column during the bank statement ingestion step.
