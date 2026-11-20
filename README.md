# Financial Data Reconciliation and Exception Management

## About the Project

This project is about comparing financial transaction records from three different sources:

- Company transactions
- Bank transactions
- Payment gateway transactions

In real-world businesses, transaction details may not always match between these systems. Some records may be missing, duplicated, or have different transaction amounts.

I built this project using MySQL and Power BI to identify these differences, manage exceptions, and display the reconciliation results in a dashboard.

## Technologies Used

- MySQL
- SQL
- Power BI
- DAX
- MySQL Workbench

## Project Features

- Created database tables for company, bank, and gateway transactions.
- Loaded sample transaction data into the database.
- Used staging tables to validate incoming records.
- Identified invalid records and duplicate transactions.
- Compared transactions between the three sources.
- Identified matched transactions, missing records, amount mismatches, and unmatched transactions.
- Created stored procedures to generate reconciliation reports.
- Used indexes to improve query performance and checked query execution using EXPLAIN.
- Created a trigger to maintain audit records when company transaction data is updated.
- Managed exceptions based on priority.
- Connected the MySQL database to Power BI.
- Created dashboards to view reconciliation results, source records, workflow status, and audit activity.

## How the Project Works

The project follows this process:

1. Transaction data is stored from company, bank, and payment gateway sources.
2. Data is checked and validated using staging tables.
3. Valid records are loaded into the main transaction tables.
4. Transactions are compared using their reference numbers and transaction details.
5. Differences are identified and classified.
6. Exceptions are added to the workflow table with priority levels.
7. Audit records are maintained for important activities.
8. Power BI is used to visualize the final results.

## Database Details

Database name: `financial_reconciliation`

Main tables include:

- `company_transactions`
- `bank_transactions`
- `gateway_transactions`
- `stg_company_transactions`
- `stg_bank_transactions`
- `stg_gateway_transactions`
- `reconciliation_results`
- `exception_workflow`
- `audit_log`
- `recon_run_log`
- `daily_recon_summary`

Reference tables are also used to maintain transaction-related values.

## SQL Concepts Used

- Primary Key and Foreign Key
- Joins and Subqueries
- Aggregate Functions
- Common Table Expressions
- CASE Statements
- Stored Procedures
- Views
- Indexes
- Triggers
- Transactions
- COMMIT and ROLLBACK
- Data Validation
- Duplicate Detection
- EXPLAIN

## Project Results

The sample dataset produced the following results after loading and reconciliation.

| Description | Count |
|---|---:|
| Company Records | 202 |
| Bank Records | 210 |
| Gateway Records | 135 |
| Total Source Records | 547 |
| Matched Transactions | 126 |
| Total Exceptions | 103 |
| Exception Workflows | 103 |
| Audit Log Records | 9 |

The reconciliation results include amount mismatches, duplicate records, missing bank transactions, missing gateway transactions, and unmatched records.

The match rate among the 229 reconciliation results was 55.02%.

## Power BI Dashboard

The Power BI report contains two pages.

### 1. Reconciliation Overview

![Reconciliation Overview](./Screenshot%20(114).png)

This page displays:

- Total reconciliation results
- Matched transactions
- Total exceptions
- Match rate
- Exception breakdown
- Exception priority distribution
- Financial summary

### 2. Data Quality and Audit

![Data Quality and Audit](./Screenshot%20(115).png)

This page displays:

- Company, bank, and gateway record counts
- Total source records
- Completed reconciliation runs
- Audit activity
- Audit log details
- Exception workflow status
- Priority breakdown

## Project Files

| File | Description |
|---|---|
| `schema.sql` | Creates database tables |
| `sample_data.sql` | Inserts sample transaction data |
| `transformations.sql` | Handles data validation and loading |
| `procedures.sql` | Contains stored procedures |
| `views.sql` | Contains database views |
| `indexes.sql` | Creates indexes |
| `tests.sql` | Contains SQL test scripts |
| `architecture.md` | Project architecture details |
| `Financial_Reconciliation_Dashboard.pbix` | Power BI report |

## How to Run the Project

1. Install MySQL Server and MySQL Workbench.
2. Open the SQL files in MySQL Workbench.
3. Execute `schema.sql` to create the database and tables.
4. Execute `sample_data.sql` to insert the sample records.
5. Execute `transformations.sql` to validate and load the data.
6. Execute the remaining SQL scripts for procedures, views, indexes, and tests.
7. Open the Power BI file and connect it to your MySQL database if required.

Run the scripts in a fresh project database. Do not rerun the sample data and transformation scripts on an already populated database unless you have reset it appropriately.

## Note

This is a learning and portfolio project developed using sample data. It is not connected to any live bank or payment gateway system.

## What I Learned

While working on this project, I got practical experience with MySQL database design, data validation, SQL queries, stored procedures, triggers, indexes, transaction reconciliation, and Power BI reporting.

I also learned how transaction differences can be identified and organized for further investigation.

## Author

**Haider Ali**

GitHub: [haiderali0412](https://github.com/haiderali0412)
