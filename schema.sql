-- =============================================================================
-- Enterprise Financial Data Reconciliation & Exception Management Engine
-- File: database/schema.sql
-- Author: Data Engineering Team
-- Version: 1.0
-- Description: Core schema definition - Run this FIRST
--
-- Execution Order: 1st
-- Dependencies: None
-- =============================================================================

-- -----------------------------------------------------------------------
-- Step 1: Create and select the database
-- -----------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS financial_reconciliation
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE financial_reconciliation;

-- -----------------------------------------------------------------------
-- Step 2: Lookup / Reference Tables (no foreign key dependencies)
-- -----------------------------------------------------------------------

-- Currency master (ISO 4217)
CREATE TABLE IF NOT EXISTS ref_currency (
    currency_code   CHAR(3)      NOT NULL,
    currency_name   VARCHAR(60)  NOT NULL,
    is_active       TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (currency_code)
) ENGINE=InnoDB COMMENT='ISO 4217 currency master';

-- Transaction-status lookup
CREATE TABLE IF NOT EXISTS ref_transaction_status (
    status_code     VARCHAR(30)  NOT NULL,
    status_label    VARCHAR(80)  NOT NULL,
    is_terminal     TINYINT(1)   NOT NULL DEFAULT 0,  -- TRUE = no further state changes expected
    PRIMARY KEY (status_code)
) ENGINE=InnoDB COMMENT='Allowed transaction lifecycle statuses';

-- Payment method lookup
CREATE TABLE IF NOT EXISTS ref_payment_method (
    method_code     VARCHAR(30)  NOT NULL,
    method_label    VARCHAR(80)  NOT NULL,
    PRIMARY KEY (method_code)
) ENGINE=InnoDB COMMENT='Supported payment methods';

-- Reconciliation-result-type lookup
CREATE TABLE IF NOT EXISTS ref_recon_result_type (
    result_type     VARCHAR(40)  NOT NULL,
    description     VARCHAR(200) NOT NULL,
    PRIMARY KEY (result_type)
) ENGINE=InnoDB COMMENT='Classification codes for reconciliation outcomes';

-- -----------------------------------------------------------------------
-- Step 3: Audit / Logging Infrastructure
-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_log (
    log_id          BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    log_timestamp   DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    log_level       ENUM('INFO','WARN','ERROR') NOT NULL DEFAULT 'INFO',
    source_table    VARCHAR(100)     NULL,
    operation       VARCHAR(50)      NOT NULL,
    record_id       VARCHAR(100)     NULL,
    performed_by    VARCHAR(100)     NOT NULL DEFAULT 'SYSTEM',
    message         TEXT             NULL,
    PRIMARY KEY (log_id),
    INDEX idx_audit_timestamp (log_timestamp),
    INDEX idx_audit_level     (log_level),
    INDEX idx_audit_source    (source_table)
) ENGINE=InnoDB COMMENT='Centralised audit trail for all ETL and reconciliation events';

-- -----------------------------------------------------------------------
-- Step 4: Staging Tables (raw inbound data, schema-on-write)
-- -----------------------------------------------------------------------
-- Staging tables intentionally use VARCHAR for every column so that
-- poorly-formatted external data is accepted first and validated later.

CREATE TABLE IF NOT EXISTS stg_company_transactions (
    stg_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    raw_transaction_id  VARCHAR(100)    NULL,
    raw_transaction_date VARCHAR(50)   NULL,
    raw_customer_id     VARCHAR(100)   NULL,
    raw_amount          VARCHAR(50)    NULL,
    raw_currency        VARCHAR(10)    NULL,
    raw_payment_method  VARCHAR(50)    NULL,
    raw_status          VARCHAR(50)    NULL,
    raw_reference_no    VARCHAR(100)   NULL,
    raw_description     VARCHAR(500)   NULL,
    loaded_at           DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    is_processed        TINYINT(1)     NOT NULL DEFAULT 0,
    validation_errors   TEXT           NULL,
    PRIMARY KEY (stg_id),
    INDEX idx_stg_comp_processed (is_processed)
) ENGINE=InnoDB COMMENT='Staging: raw company ERP export';

CREATE TABLE IF NOT EXISTS stg_bank_transactions (
    stg_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    raw_bank_ref        VARCHAR(100)    NULL,
    raw_value_date      VARCHAR(50)    NULL,
    raw_account_no      VARCHAR(50)    NULL,
    raw_debit_amount    VARCHAR(50)    NULL,
    raw_credit_amount   VARCHAR(50)    NULL,
    raw_currency        VARCHAR(10)    NULL,
    raw_description     VARCHAR(500)   NULL,
    raw_status          VARCHAR(50)    NULL,
    loaded_at           DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    is_processed        TINYINT(1)     NOT NULL DEFAULT 0,
    validation_errors   TEXT           NULL,
    PRIMARY KEY (stg_id),
    INDEX idx_stg_bank_processed (is_processed)
) ENGINE=InnoDB COMMENT='Staging: raw bank statement feed';

CREATE TABLE IF NOT EXISTS stg_gateway_transactions (
    stg_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    raw_gateway_txn_id  VARCHAR(100)    NULL,
    raw_txn_datetime    VARCHAR(50)     NULL,
    raw_merchant_id     VARCHAR(100)    NULL,
    raw_order_id        VARCHAR(100)    NULL,
    raw_amount          VARCHAR(50)     NULL,
    raw_currency        VARCHAR(10)     NULL,
    raw_gateway_status  VARCHAR(50)     NULL,
    raw_payment_method  VARCHAR(50)     NULL,
    loaded_at           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    is_processed        TINYINT(1)      NOT NULL DEFAULT 0,
    validation_errors   TEXT            NULL,
    PRIMARY KEY (stg_id),
    INDEX idx_stg_gw_processed (is_processed)
) ENGINE=InnoDB COMMENT='Staging: raw payment-gateway webhook export';

-- -----------------------------------------------------------------------
-- Step 5: Core Transaction Tables (cleaned, normalised)
-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS company_transactions (
    company_txn_id      BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    transaction_id      VARCHAR(50)      NOT NULL,          -- Business key from ERP
    transaction_date    DATE             NOT NULL,
    customer_id         VARCHAR(50)      NOT NULL,
    amount              DECIMAL(18,2)    NOT NULL,
    currency_code       CHAR(3)          NOT NULL DEFAULT 'USD',
    payment_method      VARCHAR(30)      NOT NULL,
    status              VARCHAR(30)      NOT NULL,
    reference_no        VARCHAR(100)     NULL,
    description         VARCHAR(500)     NULL,
    created_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    source_stg_id       BIGINT UNSIGNED  NULL,              -- Traceability to staging row
    is_duplicate        TINYINT(1)       NOT NULL DEFAULT 0,
    duplicate_of_id     BIGINT UNSIGNED  NULL,
    PRIMARY KEY (company_txn_id),
    UNIQUE KEY uq_comp_transaction_id (transaction_id),
    INDEX idx_comp_date        (transaction_date),
    INDEX idx_comp_customer    (customer_id),
    INDEX idx_comp_status      (status),
    INDEX idx_comp_amount      (amount),
    INDEX idx_comp_ref         (reference_no),
    CONSTRAINT fk_comp_currency FOREIGN KEY (currency_code)
        REFERENCES ref_currency (currency_code),
    CONSTRAINT fk_comp_status  FOREIGN KEY (status)
        REFERENCES ref_transaction_status (status_code),
    CONSTRAINT fk_comp_method  FOREIGN KEY (payment_method)
        REFERENCES ref_payment_method (method_code)
) ENGINE=InnoDB COMMENT='Cleaned company ERP transactions';

CREATE TABLE IF NOT EXISTS bank_transactions (
    bank_txn_id         BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    bank_ref            VARCHAR(50)      NOT NULL,          -- Bank-assigned reference
    value_date          DATE             NOT NULL,
    account_no          VARCHAR(30)      NOT NULL,
    debit_amount        DECIMAL(18,2)    NOT NULL DEFAULT 0.00,
    credit_amount       DECIMAL(18,2)    NOT NULL DEFAULT 0.00,
    net_amount          DECIMAL(18,2)    GENERATED ALWAYS AS (credit_amount - debit_amount) STORED,
    currency_code       CHAR(3)          NOT NULL DEFAULT 'USD',
    description         VARCHAR(500)     NULL,
    status              VARCHAR(30)      NOT NULL,
    created_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    source_stg_id       BIGINT UNSIGNED  NULL,
    is_duplicate        TINYINT(1)       NOT NULL DEFAULT 0,
    duplicate_of_id     BIGINT UNSIGNED  NULL,
    PRIMARY KEY (bank_txn_id),
    UNIQUE KEY uq_bank_ref (bank_ref),
    INDEX idx_bank_date    (value_date),
    INDEX idx_bank_account (account_no),
    INDEX idx_bank_net     (net_amount),
    CONSTRAINT fk_bank_currency FOREIGN KEY (currency_code)
        REFERENCES ref_currency (currency_code),
    CONSTRAINT fk_bank_status   FOREIGN KEY (status)
        REFERENCES ref_transaction_status (status_code)
) ENGINE=InnoDB COMMENT='Cleaned bank statement transactions';

CREATE TABLE IF NOT EXISTS gateway_transactions (
    gateway_txn_id      BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    gateway_txn_ref     VARCHAR(50)      NOT NULL,          -- Gateway-assigned ID
    txn_datetime        DATETIME(3)      NOT NULL,
    merchant_id         VARCHAR(50)      NOT NULL,
    order_id            VARCHAR(100)     NOT NULL,
    amount              DECIMAL(18,2)    NOT NULL,
    currency_code       CHAR(3)          NOT NULL DEFAULT 'USD',
    gateway_status      VARCHAR(30)      NOT NULL,
    payment_method      VARCHAR(30)      NOT NULL,
    created_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    source_stg_id       BIGINT UNSIGNED  NULL,
    is_duplicate        TINYINT(1)       NOT NULL DEFAULT 0,
    duplicate_of_id     BIGINT UNSIGNED  NULL,
    PRIMARY KEY (gateway_txn_id),
    UNIQUE KEY uq_gw_ref (gateway_txn_ref),
    INDEX idx_gw_date     (txn_datetime),
    INDEX idx_gw_merchant (merchant_id),
    INDEX idx_gw_order    (order_id),
    INDEX idx_gw_amount   (amount),
    CONSTRAINT fk_gw_currency FOREIGN KEY (currency_code)
        REFERENCES ref_currency (currency_code),
    CONSTRAINT fk_gw_status   FOREIGN KEY (gateway_status)
        REFERENCES ref_transaction_status (status_code),
    CONSTRAINT fk_gw_method   FOREIGN KEY (payment_method)
        REFERENCES ref_payment_method (method_code)
) ENGINE=InnoDB COMMENT='Cleaned payment-gateway transactions';

-- -----------------------------------------------------------------------
-- Step 6: Reconciliation Results Table
-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS reconciliation_results (
    recon_id            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    recon_date          DATE             NOT NULL,          -- Date being reconciled
    result_type         VARCHAR(40)      NOT NULL,          -- FK → ref_recon_result_type
    company_txn_id      BIGINT UNSIGNED  NULL,
    bank_txn_id         BIGINT UNSIGNED  NULL,
    gateway_txn_id      BIGINT UNSIGNED  NULL,
    company_amount      DECIMAL(18,2)    NULL,
    bank_amount         DECIMAL(18,2)    NULL,
    gateway_amount      DECIMAL(18,2)    NULL,
    amount_variance     DECIMAL(18,2)    GENERATED ALWAYS AS (
                            COALESCE(company_amount, 0)
                          - COALESCE(bank_amount, 0)
                        ) STORED,
    currency_code       CHAR(3)          NOT NULL DEFAULT 'USD',
    matched_on          VARCHAR(100)     NULL,              -- e.g. 'reference_no, amount'
    exception_notes     TEXT             NULL,
    resolved            TINYINT(1)       NOT NULL DEFAULT 0,
    resolved_at         DATETIME(3)      NULL,
    resolved_by         VARCHAR(100)     NULL,
    created_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    run_id              BIGINT UNSIGNED  NOT NULL,          -- Links to recon_run_log
    PRIMARY KEY (recon_id),
    INDEX idx_recon_date        (recon_date),
    INDEX idx_recon_result_type (result_type),
    INDEX idx_recon_company     (company_txn_id),
    INDEX idx_recon_bank        (bank_txn_id),
    INDEX idx_recon_gateway     (gateway_txn_id),
    INDEX idx_recon_resolved    (resolved),
    INDEX idx_recon_run         (run_id),
    CONSTRAINT fk_recon_result_type FOREIGN KEY (result_type)
        REFERENCES ref_recon_result_type (result_type),
    CONSTRAINT fk_recon_company     FOREIGN KEY (company_txn_id)
        REFERENCES company_transactions (company_txn_id),
    CONSTRAINT fk_recon_bank        FOREIGN KEY (bank_txn_id)
        REFERENCES bank_transactions (bank_txn_id),
    CONSTRAINT fk_recon_gateway     FOREIGN KEY (gateway_txn_id)
        REFERENCES gateway_transactions (gateway_txn_id)
) ENGINE=InnoDB COMMENT='Reconciliation outcomes - one row per exception or match';

-- -----------------------------------------------------------------------
-- Step 7: Reconciliation Run Log (tracks each nightly batch run)
-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS recon_run_log (
    run_id              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    run_date            DATE             NOT NULL,
    started_at          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    completed_at        DATETIME(3)      NULL,
    status              ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    total_company_txns  INT UNSIGNED     NOT NULL DEFAULT 0,
    total_bank_txns     INT UNSIGNED     NOT NULL DEFAULT 0,
    total_gateway_txns  INT UNSIGNED     NOT NULL DEFAULT 0,
    matched_count       INT UNSIGNED     NOT NULL DEFAULT 0,
    missing_bank_count  INT UNSIGNED     NOT NULL DEFAULT 0,
    missing_gw_count    INT UNSIGNED     NOT NULL DEFAULT 0,
    mismatch_count      INT UNSIGNED     NOT NULL DEFAULT 0,
    duplicate_count     INT UNSIGNED     NOT NULL DEFAULT 0,
    error_message       TEXT             NULL,
    PRIMARY KEY (run_id),
    INDEX idx_run_date   (run_date),
    INDEX idx_run_status (status)
) ENGINE=InnoDB COMMENT='One row per reconciliation batch execution';

-- -----------------------------------------------------------------------
-- Step 8: Daily Summary Report Table (pre-aggregated for dashboards)
-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS daily_recon_summary (
    summary_id          BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    summary_date        DATE             NOT NULL,
    currency_code       CHAR(3)          NOT NULL DEFAULT 'USD',
    total_transactions  INT UNSIGNED     NOT NULL DEFAULT 0,
    matched_count       INT UNSIGNED     NOT NULL DEFAULT 0,
    missing_bank_count  INT UNSIGNED     NOT NULL DEFAULT 0,
    missing_gw_count    INT UNSIGNED     NOT NULL DEFAULT 0,
    mismatch_count      INT UNSIGNED     NOT NULL DEFAULT 0,
    duplicate_count     INT UNSIGNED     NOT NULL DEFAULT 0,
    total_company_amount DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    total_bank_amount   DECIMAL(18,2)    NOT NULL DEFAULT 0.00,
    total_variance      DECIMAL(18,2)    NOT NULL DEFAULT 0.00,
    reconciliation_rate DECIMAL(5,2)     GENERATED ALWAYS AS (
                            CASE WHEN total_transactions = 0 THEN 0
                            ELSE ROUND((matched_count / total_transactions) * 100, 2)
                            END
                        ) STORED,
    generated_at        DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    run_id              BIGINT UNSIGNED  NOT NULL,
    PRIMARY KEY (summary_id),
    UNIQUE KEY uq_summary_date_currency (summary_date, currency_code),
    INDEX idx_summary_date (summary_date),
    INDEX idx_summary_run  (run_id)
) ENGINE=InnoDB COMMENT='Pre-aggregated daily reconciliation KPIs for reporting';

-- -----------------------------------------------------------------------
-- Step 9: Exception Workflow Table (manual resolution tracking)
-- -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS exception_workflow (
    workflow_id         BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    recon_id            BIGINT UNSIGNED  NOT NULL,
    assigned_to         VARCHAR(100)     NULL,
    priority            ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL DEFAULT 'MEDIUM',
    workflow_status     ENUM('OPEN','IN_PROGRESS','RESOLVED','ESCALATED') NOT NULL DEFAULT 'OPEN',
    opened_at           DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    due_by              DATE             NULL,
    resolution_notes    TEXT             NULL,
    closed_at           DATETIME(3)      NULL,
    PRIMARY KEY (workflow_id),
    INDEX idx_wf_recon    (recon_id),
    INDEX idx_wf_status   (workflow_status),
    INDEX idx_wf_priority (priority),
    CONSTRAINT fk_wf_recon FOREIGN KEY (recon_id)
        REFERENCES reconciliation_results (recon_id)
) ENGINE=InnoDB COMMENT='Human-in-the-loop exception resolution workflow';

