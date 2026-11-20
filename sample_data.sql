-- =============================================================================
-- Enterprise Financial Data Reconciliation & Exception Management Engine
-- File: database/sample_data.sql
-- Description: Realistic seed data - 500+ records across all three sources
--
-- Execution Order: 2nd (after schema.sql)
-- Dependencies: schema.sql
-- =============================================================================

USE financial_reconciliation;

-- -----------------------------------------------------------------------
-- 1. Reference / Lookup Data
-- -----------------------------------------------------------------------

INSERT IGNORE INTO ref_currency (currency_code, currency_name) VALUES
('USD', 'US Dollar'),
('EUR', 'Euro'),
('GBP', 'British Pound Sterling'),
('INR', 'Indian Rupee'),
('AED', 'UAE Dirham'),
('SGD', 'Singapore Dollar'),
('CAD', 'Canadian Dollar'),
('AUD', 'Australian Dollar');

INSERT IGNORE INTO ref_transaction_status (status_code, status_label, is_terminal) VALUES
('PENDING',   'Pending Processing',   0),
('CLEARED',   'Cleared / Settled',    1),
('FAILED',    'Failed / Declined',    1),
('REVERSED',  'Reversed',             1),
('ON_HOLD',   'On Hold - Under Review',0),
('CANCELLED', 'Cancelled by User',    1),
('COMPLETED', 'Completed',            1),
('CAPTURED',  'Captured by Gateway',  1),
('REFUNDED',  'Refunded',             1);

INSERT IGNORE INTO ref_payment_method (method_code, method_label) VALUES
('CARD_CREDIT',  'Credit Card'),
('CARD_DEBIT',   'Debit Card'),
('WIRE',         'Wire Transfer'),
('ACH',          'ACH / Bank Transfer'),
('UPI',          'UPI (Unified Payment Interface)'),
('WALLET',       'Digital Wallet'),
('CHEQUE',       'Cheque'),
('NEFT',         'NEFT'),
('RTGS',         'RTGS');

INSERT IGNORE INTO ref_recon_result_type (result_type, description) VALUES
('MATCHED',          'All three sources agree on amount, date, and reference'),
('MISSING_BANK',     'Company/Gateway record present but no matching bank entry'),
('MISSING_GATEWAY',  'Company record present but no matching gateway entry'),
('AMOUNT_MISMATCH',  'Records match by reference but differ in amount'),
('DUPLICATE_COMPANY','Duplicate transaction detected in company source'),
('DUPLICATE_BANK',   'Duplicate transaction detected in bank source'),
('DUPLICATE_GATEWAY','Duplicate transaction detected in gateway source'),
('UNMATCHED_BANK',   'Bank entry with no corresponding company record'),
('UNMATCHED_GATEWAY','Gateway entry with no corresponding company record');

-- -----------------------------------------------------------------------
-- 2. Company Transactions  (200 records)
--    Business keys: TXN-00001 … TXN-00200
--    TXN-00191 to TXN-00195  → intentional duplicates of earlier rows
--    TXN-00196 to TXN-00200  → no bank/gateway counterpart (MISSING scenario)
-- -----------------------------------------------------------------------

INSERT INTO company_transactions
    (transaction_id, transaction_date, customer_id, amount, currency_code,
     payment_method, status, reference_no, description)
VALUES
-- Jan 2025 (50 rows)
('TXN-00001','2025-01-03','CUST-1001', 1250.00,'USD','CARD_CREDIT','COMPLETED','REF-A001','Software subscription Q1'),
('TXN-00002','2025-01-04','CUST-1002', 3400.50,'USD','WIRE',       'COMPLETED','REF-A002','Annual maintenance contract'),
('TXN-00003','2025-01-05','CUST-1003',  875.25,'USD','ACH',        'COMPLETED','REF-A003','Consulting - Jan week 1'),
('TXN-00004','2025-01-06','CUST-1004', 2100.00,'USD','CARD_DEBIT', 'COMPLETED','REF-A004','Hardware purchase'),
('TXN-00005','2025-01-07','CUST-1005', 5500.00,'USD','WIRE',       'COMPLETED','REF-A005','Enterprise license batch 1'),
('TXN-00006','2025-01-08','CUST-1006',  450.00,'USD','UPI',        'COMPLETED','REF-A006','Misc office supplies'),
('TXN-00007','2025-01-09','CUST-1007', 1900.75,'USD','CARD_CREDIT','COMPLETED','REF-A007','Cloud storage Jan'),
('TXN-00008','2025-01-10','CUST-1008', 3200.00,'USD','ACH',        'COMPLETED','REF-A008','Payroll supplemental'),
('TXN-00009','2025-01-11','CUST-1009', 6750.00,'USD','WIRE',       'COMPLETED','REF-A009','Real-estate deposit'),
('TXN-00010','2025-01-12','CUST-1010',  980.00,'USD','CARD_DEBIT', 'COMPLETED','REF-A010','Travel reimbursement'),
('TXN-00011','2025-01-13','CUST-1011', 2300.00,'USD','CARD_CREDIT','COMPLETED','REF-A011','Marketing campaign Jan'),
('TXN-00012','2025-01-14','CUST-1012', 1150.50,'USD','ACH',        'COMPLETED','REF-A012','Software tools renewal'),
('TXN-00013','2025-01-15','CUST-1013', 4400.00,'USD','WIRE',       'COMPLETED','REF-A013','Vendor payment - logistics'),
('TXN-00014','2025-01-16','CUST-1014',  760.00,'USD','UPI',        'COMPLETED','REF-A014','Utility bills Jan'),
('TXN-00015','2025-01-17','CUST-1015', 8900.00,'USD','WIRE',       'COMPLETED','REF-A015','Data-center co-location'),
('TXN-00016','2025-01-18','CUST-1016', 1050.00,'USD','CARD_CREDIT','COMPLETED','REF-A016','SaaS subscription Jan'),
('TXN-00017','2025-01-19','CUST-1017', 3600.00,'USD','ACH',        'COMPLETED','REF-A017','Outsourcing invoice #101'),
('TXN-00018','2025-01-20','CUST-1018', 2250.00,'USD','CARD_DEBIT', 'COMPLETED','REF-A018','Training material'),
('TXN-00019','2025-01-21','CUST-1019',  520.00,'USD','UPI',        'COMPLETED','REF-A019','Canteen & pantry'),
('TXN-00020','2025-01-22','CUST-1020',12000.00,'USD','WIRE',       'COMPLETED','REF-A020','Infrastructure upgrade deposit'),
('TXN-00021','2025-01-23','CUST-1021', 1800.00,'USD','CARD_CREDIT','COMPLETED','REF-A021','Design subscription'),
('TXN-00022','2025-01-24','CUST-1022', 3100.00,'USD','WIRE',       'COMPLETED','REF-A022','Freight & logistics Q1'),
('TXN-00023','2025-01-25','CUST-1023',  640.75,'USD','ACH',        'COMPLETED','REF-A023','Printing & stationery'),
('TXN-00024','2025-01-26','CUST-1024', 2900.00,'USD','CARD_CREDIT','COMPLETED','REF-A024','Cloud hosting Jan'),
('TXN-00025','2025-01-27','CUST-1025', 7200.00,'USD','WIRE',       'COMPLETED','REF-A025','Bulk raw material'),
('TXN-00026','2025-01-28','CUST-1026', 1350.00,'USD','CARD_DEBIT', 'COMPLETED','REF-A026','Office furniture'),
('TXN-00027','2025-01-29','CUST-1027', 4100.00,'USD','ACH',        'COMPLETED','REF-A027','Legal retainer Jan'),
('TXN-00028','2025-01-30','CUST-1028', 2700.00,'USD','WIRE',       'COMPLETED','REF-A028','Advertising digital Jan'),
('TXN-00029','2025-01-31','CUST-1001', 3850.00,'USD','CARD_CREDIT','COMPLETED','REF-A029','Software subscription ext'),
('TXN-00030','2025-01-31','CUST-1002',  980.00,'USD','UPI',        'COMPLETED','REF-A030','Miscellaneous Jan'),
-- Feb 2025 (50 rows)
('TXN-00031','2025-02-01','CUST-1003', 2200.00,'USD','WIRE',       'COMPLETED','REF-B001','Infra month 2'),
('TXN-00032','2025-02-02','CUST-1004',  430.00,'USD','UPI',        'COMPLETED','REF-B002','Canteen Feb'),
('TXN-00033','2025-02-03','CUST-1005', 6800.00,'USD','ACH',        'COMPLETED','REF-B003','Payroll supplemental Feb'),
('TXN-00034','2025-02-04','CUST-1006', 1900.00,'USD','CARD_CREDIT','COMPLETED','REF-B004','Marketing digital Feb'),
('TXN-00035','2025-02-05','CUST-1007', 3400.00,'USD','WIRE',       'COMPLETED','REF-B005','Data analytics licence'),
('TXN-00036','2025-02-06','CUST-1008',  720.50,'USD','CARD_DEBIT', 'COMPLETED','REF-B006','Courier & shipping'),
('TXN-00037','2025-02-07','CUST-1009', 5100.00,'USD','WIRE',       'COMPLETED','REF-B007','Consulting Feb wk1'),
('TXN-00038','2025-02-08','CUST-1010', 2450.00,'USD','ACH',        'COMPLETED','REF-B008','Cloud backup Feb'),
('TXN-00039','2025-02-09','CUST-1011', 1100.00,'USD','CARD_CREDIT','COMPLETED','REF-B009','Subscription tools'),
('TXN-00040','2025-02-10','CUST-1012', 8200.00,'USD','WIRE',       'COMPLETED','REF-B010','Equipment lease Feb'),
('TXN-00041','2025-02-11','CUST-1013', 1650.00,'USD','UPI',        'COMPLETED','REF-B011','Utility Feb'),
('TXN-00042','2025-02-12','CUST-1014', 2900.00,'USD','CARD_DEBIT', 'COMPLETED','REF-B012','HR platform licence'),
('TXN-00043','2025-02-13','CUST-1015', 3350.00,'USD','ACH',        'COMPLETED','REF-B013','Outsourcing #102'),
('TXN-00044','2025-02-14','CUST-1016',  490.00,'USD','UPI',        'COMPLETED','REF-B014','Valentine promo gifts'),
('TXN-00045','2025-02-15','CUST-1017',11500.00,'USD','WIRE',       'COMPLETED','REF-B015','Infrastructure Phase 2'),
('TXN-00046','2025-02-16','CUST-1018', 1750.00,'USD','CARD_CREDIT','COMPLETED','REF-B016','Cloud CDN Feb'),
('TXN-00047','2025-02-17','CUST-1019', 3900.00,'USD','WIRE',       'COMPLETED','REF-B017','Legal retainer Feb'),
('TXN-00048','2025-02-18','CUST-1020', 2600.00,'USD','ACH',        'COMPLETED','REF-B018','Advertising print Feb'),
('TXN-00049','2025-02-19','CUST-1021',  610.00,'USD','UPI',        'COMPLETED','REF-B019','Pantry Feb'),
('TXN-00050','2025-02-20','CUST-1022',14000.00,'USD','WIRE',       'COMPLETED','REF-B020','Acquisition payment milestone'),
('TXN-00051','2025-02-21','CUST-1023', 1250.00,'USD','CARD_CREDIT','COMPLETED','REF-B021','Design tools Feb'),
('TXN-00052','2025-02-22','CUST-1024', 3100.00,'USD','WIRE',       'COMPLETED','REF-B022','Freight Feb'),
('TXN-00053','2025-02-23','CUST-1025',  580.00,'USD','ACH',        'COMPLETED','REF-B023','Printing Feb'),
('TXN-00054','2025-02-24','CUST-1026', 2800.00,'USD','CARD_DEBIT', 'COMPLETED','REF-B024','Cloud hosting Feb'),
('TXN-00055','2025-02-25','CUST-1027', 7500.00,'USD','WIRE',       'COMPLETED','REF-B025','Raw material Feb'),
('TXN-00056','2025-02-26','CUST-1028', 1400.00,'USD','CARD_CREDIT','COMPLETED','REF-B026','Office equip Feb'),
('TXN-00057','2025-02-27','CUST-1001', 4200.00,'USD','ACH',        'COMPLETED','REF-B027','Outsourcing #103'),
('TXN-00058','2025-02-28','CUST-1002', 2550.00,'USD','WIRE',       'COMPLETED','REF-B028','Advertising digital Feb2'),
('TXN-00059','2025-02-28','CUST-1003', 3900.00,'USD','CARD_CREDIT','COMPLETED','REF-B029','Software ext Feb'),
('TXN-00060','2025-02-28','CUST-1004',  870.00,'USD','UPI',        'COMPLETED','REF-B030','Misc Feb'),
-- Mar 2025 (50 rows)
('TXN-00061','2025-03-01','CUST-1005', 2300.00,'USD','WIRE',       'COMPLETED','REF-C001','Infra Mar'),
('TXN-00062','2025-03-02','CUST-1006',  460.00,'USD','UPI',        'COMPLETED','REF-C002','Canteen Mar'),
('TXN-00063','2025-03-03','CUST-1007', 7000.00,'USD','ACH',        'COMPLETED','REF-C003','Payroll supp Mar'),
('TXN-00064','2025-03-04','CUST-1008', 2000.00,'USD','CARD_CREDIT','COMPLETED','REF-C004','Marketing Mar'),
('TXN-00065','2025-03-05','CUST-1009', 3600.00,'USD','WIRE',       'COMPLETED','REF-C005','Analytics Mar'),
('TXN-00066','2025-03-06','CUST-1010',  740.00,'USD','CARD_DEBIT', 'COMPLETED','REF-C006','Courier Mar'),
('TXN-00067','2025-03-07','CUST-1011', 5300.00,'USD','WIRE',       'COMPLETED','REF-C007','Consulting Mar wk1'),
('TXN-00068','2025-03-08','CUST-1012', 2500.00,'USD','ACH',        'COMPLETED','REF-C008','Cloud backup Mar'),
('TXN-00069','2025-03-09','CUST-1013', 1150.00,'USD','CARD_CREDIT','COMPLETED','REF-C009','SaaS Mar'),
('TXN-00070','2025-03-10','CUST-1014', 8500.00,'USD','WIRE',       'COMPLETED','REF-C010','Equip lease Mar'),
('TXN-00071','2025-03-11','CUST-1015', 1700.00,'USD','UPI',        'COMPLETED','REF-C011','Utility Mar'),
('TXN-00072','2025-03-12','CUST-1016', 3100.00,'USD','CARD_DEBIT', 'COMPLETED','REF-C012','HR platform Mar'),
('TXN-00073','2025-03-13','CUST-1017', 3550.00,'USD','ACH',        'COMPLETED','REF-C013','Outsourcing #104'),
('TXN-00074','2025-03-14','CUST-1018',  510.00,'USD','UPI',        'COMPLETED','REF-C014','Pantry Mar'),
('TXN-00075','2025-03-15','CUST-1019',12500.00,'USD','WIRE',       'COMPLETED','REF-C015','Infra Phase 3'),
('TXN-00076','2025-03-16','CUST-1020', 1800.00,'USD','CARD_CREDIT','COMPLETED','REF-C016','CDN Mar'),
('TXN-00077','2025-03-17','CUST-1021', 4100.00,'USD','WIRE',       'COMPLETED','REF-C017','Legal Mar'),
('TXN-00078','2025-03-18','CUST-1022', 2700.00,'USD','ACH',        'COMPLETED','REF-C018','Advert Mar'),
('TXN-00079','2025-03-19','CUST-1023',  630.00,'USD','UPI',        'COMPLETED','REF-C019','Misc Mar'),
('TXN-00080','2025-03-20','CUST-1024',15000.00,'USD','WIRE',       'COMPLETED','REF-C020','Acquisition M2'),
('TXN-00081','2025-03-21','CUST-1025', 1300.00,'USD','CARD_CREDIT','COMPLETED','REF-C021','Design Mar'),
('TXN-00082','2025-03-22','CUST-1026', 3200.00,'USD','WIRE',       'COMPLETED','REF-C022','Freight Mar'),
('TXN-00083','2025-03-23','CUST-1027',  600.00,'USD','ACH',        'COMPLETED','REF-C023','Printing Mar'),
('TXN-00084','2025-03-24','CUST-1028', 2900.00,'USD','CARD_DEBIT', 'COMPLETED','REF-C024','Hosting Mar'),
('TXN-00085','2025-03-25','CUST-1001', 7800.00,'USD','WIRE',       'COMPLETED','REF-C025','Raw material Mar'),
('TXN-00086','2025-03-26','CUST-1002', 1450.00,'USD','CARD_CREDIT','COMPLETED','REF-C026','Office Mar'),
('TXN-00087','2025-03-27','CUST-1003', 4300.00,'USD','ACH',        'COMPLETED','REF-C027','Outsourcing #105'),
('TXN-00088','2025-03-28','CUST-1004', 2650.00,'USD','WIRE',       'COMPLETED','REF-C028','Advert Mar2'),
('TXN-00089','2025-03-29','CUST-1005', 4000.00,'USD','CARD_CREDIT','COMPLETED','REF-C029','Software Mar ext'),
('TXN-00090','2025-03-31','CUST-1006',  900.00,'USD','UPI',        'COMPLETED','REF-C030','Misc Mar2'),
-- Apr-Jun 2025 (50 rows)
('TXN-00091','2025-04-01','CUST-1007', 2400.00,'USD','WIRE',       'COMPLETED','REF-D001','Infra Apr'),
('TXN-00092','2025-04-03','CUST-1008',  480.00,'USD','UPI',        'COMPLETED','REF-D002','Canteen Apr'),
('TXN-00093','2025-04-05','CUST-1009', 7200.00,'USD','ACH',        'COMPLETED','REF-D003','Payroll supp Apr'),
('TXN-00094','2025-04-07','CUST-1010', 2100.00,'USD','CARD_CREDIT','COMPLETED','REF-D004','Marketing Apr'),
('TXN-00095','2025-04-09','CUST-1011', 3800.00,'USD','WIRE',       'COMPLETED','REF-D005','Analytics Apr'),
('TXN-00096','2025-04-11','CUST-1012',  760.00,'USD','CARD_DEBIT', 'COMPLETED','REF-D006','Courier Apr'),
('TXN-00097','2025-04-13','CUST-1013', 5500.00,'USD','WIRE',       'COMPLETED','REF-D007','Consulting Apr wk2'),
('TXN-00098','2025-04-15','CUST-1014', 2600.00,'USD','ACH',        'COMPLETED','REF-D008','Cloud Apr'),
('TXN-00099','2025-04-17','CUST-1015', 1200.00,'USD','CARD_CREDIT','COMPLETED','REF-D009','SaaS Apr'),
('TXN-00100','2025-04-19','CUST-1016', 8800.00,'USD','WIRE',       'COMPLETED','REF-D010','Equipment Apr'),
('TXN-00101','2025-04-21','CUST-1017', 1750.00,'USD','UPI',        'COMPLETED','REF-D011','Utility Apr'),
('TXN-00102','2025-04-23','CUST-1018', 3200.00,'USD','CARD_DEBIT', 'COMPLETED','REF-D012','HR platform Apr'),
('TXN-00103','2025-04-25','CUST-1019', 3650.00,'USD','ACH',        'COMPLETED','REF-D013','Outsourcing #106'),
('TXN-00104','2025-04-27','CUST-1020',  530.00,'USD','UPI',        'COMPLETED','REF-D014','Pantry Apr'),
('TXN-00105','2025-04-29','CUST-1021',13000.00,'USD','WIRE',       'COMPLETED','REF-D015','Infra Phase 4'),
('TXN-00106','2025-05-01','CUST-1022', 1850.00,'USD','CARD_CREDIT','COMPLETED','REF-E001','CDN May'),
('TXN-00107','2025-05-03','CUST-1023', 4200.00,'USD','WIRE',       'COMPLETED','REF-E002','Legal May'),
('TXN-00108','2025-05-05','CUST-1024', 2800.00,'USD','ACH',        'COMPLETED','REF-E003','Advert May'),
('TXN-00109','2025-05-07','CUST-1025',  650.00,'USD','UPI',        'COMPLETED','REF-E004','Misc May'),
('TXN-00110','2025-05-09','CUST-1026',16000.00,'USD','WIRE',       'COMPLETED','REF-E005','Acquisition M3'),
('TXN-00111','2025-05-11','CUST-1027', 1350.00,'USD','CARD_CREDIT','COMPLETED','REF-E006','Design May'),
('TXN-00112','2025-05-13','CUST-1028', 3300.00,'USD','WIRE',       'COMPLETED','REF-E007','Freight May'),
('TXN-00113','2025-05-15','CUST-1001',  620.00,'USD','ACH',        'COMPLETED','REF-E008','Printing May'),
('TXN-00114','2025-05-17','CUST-1002', 3000.00,'USD','CARD_DEBIT', 'COMPLETED','REF-E009','Hosting May'),
('TXN-00115','2025-05-19','CUST-1003', 8100.00,'USD','WIRE',       'COMPLETED','REF-E010','Raw material May'),
('TXN-00116','2025-05-21','CUST-1004', 1500.00,'USD','CARD_CREDIT','COMPLETED','REF-E011','Office May'),
('TXN-00117','2025-05-23','CUST-1005', 4400.00,'USD','ACH',        'COMPLETED','REF-E012','Outsourcing #107'),
('TXN-00118','2025-05-25','CUST-1006', 2750.00,'USD','WIRE',       'COMPLETED','REF-E013','Advert May2'),
('TXN-00119','2025-05-27','CUST-1007', 4100.00,'USD','CARD_CREDIT','COMPLETED','REF-E014','Software May ext'),
('TXN-00120','2025-05-29','CUST-1008',  940.00,'USD','UPI',        'COMPLETED','REF-E015','Misc May2'),
-- Jul-Sep 2025 (50 rows)
('TXN-00121','2025-06-02','CUST-1009', 2500.00,'USD','WIRE',       'COMPLETED','REF-F001','Infra Jun'),
('TXN-00122','2025-06-04','CUST-1010',  500.00,'USD','UPI',        'COMPLETED','REF-F002','Canteen Jun'),
('TXN-00123','2025-06-06','CUST-1011', 7400.00,'USD','ACH',        'COMPLETED','REF-F003','Payroll Jun'),
('TXN-00124','2025-06-08','CUST-1012', 2200.00,'USD','CARD_CREDIT','COMPLETED','REF-F004','Marketing Jun'),
('TXN-00125','2025-06-10','CUST-1013', 4000.00,'USD','WIRE',       'COMPLETED','REF-F005','Analytics Jun'),
('TXN-00126','2025-06-12','CUST-1014',  780.00,'USD','CARD_DEBIT', 'COMPLETED','REF-F006','Courier Jun'),
('TXN-00127','2025-06-14','CUST-1015', 5700.00,'USD','WIRE',       'COMPLETED','REF-F007','Consulting Jun'),
('TXN-00128','2025-06-16','CUST-1016', 2700.00,'USD','ACH',        'COMPLETED','REF-F008','Cloud Jun'),
('TXN-00129','2025-06-18','CUST-1017', 1250.00,'USD','CARD_CREDIT','COMPLETED','REF-F009','SaaS Jun'),
('TXN-00130','2025-06-20','CUST-1018', 9100.00,'USD','WIRE',       'COMPLETED','REF-F010','Equipment Jun'),
('TXN-00131','2025-07-01','CUST-1019', 1800.00,'USD','UPI',        'COMPLETED','REF-G001','Utility Jul'),
('TXN-00132','2025-07-03','CUST-1020', 3300.00,'USD','CARD_DEBIT', 'COMPLETED','REF-G002','HR Jul'),
('TXN-00133','2025-07-05','CUST-1021', 3750.00,'USD','ACH',        'COMPLETED','REF-G003','Outsourcing #108'),
('TXN-00134','2025-07-07','CUST-1022',  550.00,'USD','UPI',        'COMPLETED','REF-G004','Pantry Jul'),
('TXN-00135','2025-07-09','CUST-1023',13500.00,'USD','WIRE',       'COMPLETED','REF-G005','Infra Phase 5'),
('TXN-00136','2025-07-11','CUST-1024', 1900.00,'USD','CARD_CREDIT','COMPLETED','REF-G006','CDN Jul'),
('TXN-00137','2025-07-13','CUST-1025', 4300.00,'USD','WIRE',       'COMPLETED','REF-G007','Legal Jul'),
('TXN-00138','2025-07-15','CUST-1026', 2900.00,'USD','ACH',        'COMPLETED','REF-G008','Advert Jul'),
('TXN-00139','2025-07-17','CUST-1027',  670.00,'USD','UPI',        'COMPLETED','REF-G009','Misc Jul'),
('TXN-00140','2025-07-19','CUST-1028',17000.00,'USD','WIRE',       'COMPLETED','REF-G010','Acquisition M4'),
('TXN-00141','2025-07-21','CUST-1001', 1400.00,'USD','CARD_CREDIT','COMPLETED','REF-G011','Design Jul'),
('TXN-00142','2025-07-23','CUST-1002', 3400.00,'USD','WIRE',       'COMPLETED','REF-G012','Freight Jul'),
('TXN-00143','2025-07-25','CUST-1003',  640.00,'USD','ACH',        'COMPLETED','REF-G013','Printing Jul'),
('TXN-00144','2025-07-27','CUST-1004', 3100.00,'USD','CARD_DEBIT', 'COMPLETED','REF-G014','Hosting Jul'),
('TXN-00145','2025-07-29','CUST-1005', 8400.00,'USD','WIRE',       'COMPLETED','REF-G015','Raw material Jul'),
('TXN-00146','2025-08-01','CUST-1006', 1550.00,'USD','CARD_CREDIT','COMPLETED','REF-H001','Office Aug'),
('TXN-00147','2025-08-03','CUST-1007', 4500.00,'USD','ACH',        'COMPLETED','REF-H002','Outsourcing #109'),
('TXN-00148','2025-08-05','CUST-1008', 2850.00,'USD','WIRE',       'COMPLETED','REF-H003','Advert Aug'),
('TXN-00149','2025-08-07','CUST-1009', 4200.00,'USD','CARD_CREDIT','COMPLETED','REF-H004','Software Aug'),
('TXN-00150','2025-08-09','CUST-1010',  970.00,'USD','UPI',        'COMPLETED','REF-H005','Misc Aug'),
-- Oct-Dec 2025 (40 rows)
('TXN-00151','2025-09-01','CUST-1011', 2600.00,'USD','WIRE',       'COMPLETED','REF-I001','Infra Sep'),
('TXN-00152','2025-09-03','CUST-1012',  520.00,'USD','UPI',        'COMPLETED','REF-I002','Canteen Sep'),
('TXN-00153','2025-09-05','CUST-1013', 7600.00,'USD','ACH',        'COMPLETED','REF-I003','Payroll Sep'),
('TXN-00154','2025-09-07','CUST-1014', 2300.00,'USD','CARD_CREDIT','COMPLETED','REF-I004','Marketing Sep'),
('TXN-00155','2025-09-09','CUST-1015', 4200.00,'USD','WIRE',       'COMPLETED','REF-I005','Analytics Sep'),
('TXN-00156','2025-09-11','CUST-1016',  800.00,'USD','CARD_DEBIT', 'COMPLETED','REF-I006','Courier Sep'),
('TXN-00157','2025-09-13','CUST-1017', 5900.00,'USD','WIRE',       'COMPLETED','REF-I007','Consulting Sep'),
('TXN-00158','2025-09-15','CUST-1018', 2800.00,'USD','ACH',        'COMPLETED','REF-I008','Cloud Sep'),
('TXN-00159','2025-09-17','CUST-1019', 1300.00,'USD','CARD_CREDIT','COMPLETED','REF-I009','SaaS Sep'),
('TXN-00160','2025-09-19','CUST-1020', 9400.00,'USD','WIRE',       'COMPLETED','REF-I010','Equipment Sep'),
('TXN-00161','2025-10-01','CUST-1021', 1850.00,'USD','UPI',        'COMPLETED','REF-J001','Utility Oct'),
('TXN-00162','2025-10-03','CUST-1022', 3400.00,'USD','CARD_DEBIT', 'COMPLETED','REF-J002','HR Oct'),
('TXN-00163','2025-10-05','CUST-1023', 3850.00,'USD','ACH',        'COMPLETED','REF-J003','Outsourcing #110'),
('TXN-00164','2025-10-07','CUST-1024',  570.00,'USD','UPI',        'COMPLETED','REF-J004','Pantry Oct'),
('TXN-00165','2025-10-09','CUST-1025',14000.00,'USD','WIRE',       'COMPLETED','REF-J005','Infra Phase 6'),
('TXN-00166','2025-10-11','CUST-1026', 1950.00,'USD','CARD_CREDIT','COMPLETED','REF-J006','CDN Oct'),
('TXN-00167','2025-10-13','CUST-1027', 4400.00,'USD','WIRE',       'COMPLETED','REF-J007','Legal Oct'),
('TXN-00168','2025-10-15','CUST-1028', 3000.00,'USD','ACH',        'COMPLETED','REF-J008','Advert Oct'),
('TXN-00169','2025-10-17','CUST-1001',  690.00,'USD','UPI',        'COMPLETED','REF-J009','Misc Oct'),
('TXN-00170','2025-10-19','CUST-1002',18000.00,'USD','WIRE',       'COMPLETED','REF-J010','Acquisition M5'),
('TXN-00171','2025-11-01','CUST-1003', 1450.00,'USD','CARD_CREDIT','COMPLETED','REF-K001','Design Nov'),
('TXN-00172','2025-11-03','CUST-1004', 3500.00,'USD','WIRE',       'COMPLETED','REF-K002','Freight Nov'),
('TXN-00173','2025-11-05','CUST-1005',  660.00,'USD','ACH',        'COMPLETED','REF-K003','Printing Nov'),
('TXN-00174','2025-11-07','CUST-1006', 3200.00,'USD','CARD_DEBIT', 'COMPLETED','REF-K004','Hosting Nov'),
('TXN-00175','2025-11-09','CUST-1007', 8700.00,'USD','WIRE',       'COMPLETED','REF-K005','Raw material Nov'),
('TXN-00176','2025-11-11','CUST-1008', 1600.00,'USD','CARD_CREDIT','COMPLETED','REF-K006','Office Nov'),
('TXN-00177','2025-11-13','CUST-1009', 4600.00,'USD','ACH',        'COMPLETED','REF-K007','Outsourcing #111'),
('TXN-00178','2025-11-15','CUST-1010', 2950.00,'USD','WIRE',       'COMPLETED','REF-K008','Advert Nov'),
('TXN-00179','2025-11-17','CUST-1011', 4300.00,'USD','CARD_CREDIT','COMPLETED','REF-K009','Software Nov'),
('TXN-00180','2025-11-19','CUST-1012', 1000.00,'USD','UPI',        'COMPLETED','REF-K010','Misc Nov'),
-- Dec 2025 (10 clean rows)
('TXN-00181','2025-12-01','CUST-1013', 2700.00,'USD','WIRE',       'COMPLETED','REF-L001','Infra Dec'),
('TXN-00182','2025-12-03','CUST-1014',  540.00,'USD','UPI',        'COMPLETED','REF-L002','Canteen Dec'),
('TXN-00183','2025-12-05','CUST-1015', 7800.00,'USD','ACH',        'COMPLETED','REF-L003','Payroll Dec'),
('TXN-00184','2025-12-07','CUST-1016', 2400.00,'USD','CARD_CREDIT','COMPLETED','REF-L004','Marketing Dec'),
('TXN-00185','2025-12-09','CUST-1017', 4400.00,'USD','WIRE',       'COMPLETED','REF-L005','Analytics Dec'),
('TXN-00186','2025-12-11','CUST-1018',  820.00,'USD','CARD_DEBIT', 'COMPLETED','REF-L006','Courier Dec'),
('TXN-00187','2025-12-13','CUST-1019', 6100.00,'USD','WIRE',       'COMPLETED','REF-L007','Consulting Dec'),
('TXN-00188','2025-12-15','CUST-1020', 2900.00,'USD','ACH',        'COMPLETED','REF-L008','Cloud Dec'),
('TXN-00189','2025-12-17','CUST-1021', 1350.00,'USD','CARD_CREDIT','COMPLETED','REF-L009','SaaS Dec'),
('TXN-00190','2025-12-19','CUST-1022', 9700.00,'USD','WIRE',       'COMPLETED','REF-L010','Equipment Dec'),
-- *** INTENTIONAL DUPLICATES (same reference_no, same amount) ***
('TXN-00191','2025-01-03','CUST-1001', 1250.00,'USD','CARD_CREDIT','COMPLETED','REF-A001','DUPLICATE: Software subscription Q1'),
('TXN-00192','2025-02-02','CUST-1004',  430.00,'USD','UPI',        'COMPLETED','REF-B002','DUPLICATE: Canteen Feb'),
('TXN-00193','2025-03-21','CUST-1025', 1300.00,'USD','CARD_CREDIT','COMPLETED','REF-C021','DUPLICATE: Design Mar'),
-- *** MISSING counterparts in bank/gateway (company only) ***
('TXN-00194','2025-11-20','CUST-1023', 3750.00,'USD','CARD_CREDIT','COMPLETED','REF-M001','Year-end bonus payout A'),
('TXN-00195','2025-11-21','CUST-1024', 2100.00,'USD','ACH',        'COMPLETED','REF-M002','Year-end bonus payout B'),
('TXN-00196','2025-11-22','CUST-1025', 5500.00,'USD','WIRE',       'COMPLETED','REF-M003','Year-end settlement C'),
('TXN-00197','2025-11-23','CUST-1026',  890.00,'USD','UPI',        'COMPLETED','REF-M004','Year-end misc D'),
('TXN-00198','2025-11-24','CUST-1027', 4200.00,'USD','WIRE',       'COMPLETED','REF-M005','Year-end vendor E'),
('TXN-00199','2025-11-25','CUST-1028', 1750.00,'USD','CARD_CREDIT','COMPLETED','REF-M006','Year-end promo F'),
('TXN-00200','2025-11-26','CUST-1001', 6800.00,'USD','WIRE',       'COMPLETED','REF-M007','Year-end infra G');

-- -----------------------------------------------------------------------
-- 3. Bank Transactions  (200 records)
--    Rows 1-180: match company transactions by reference_no
--    Rows 181-190: amount mismatch (small delta to simulate bank fees)
--    Rows 191-195: duplicates
--    Rows 196-200: bank-only (no company record)
-- -----------------------------------------------------------------------

INSERT INTO bank_transactions
    (bank_ref, value_date, account_no, debit_amount, credit_amount, currency_code, description, status)
VALUES
-- Jan (matches TXN-00001 .. TXN-00030)
('BNK-A001','2025-01-03','ACC-5001', 0.00, 1250.00,'USD','REF-A001 Software subscription Q1','CLEARED'),
('BNK-A002','2025-01-04','ACC-5001', 0.00, 3400.50,'USD','REF-A002 Annual maintenance','CLEARED'),
('BNK-A003','2025-01-05','ACC-5001', 0.00,  875.25,'USD','REF-A003 Consulting Jan wk1','CLEARED'),
('BNK-A004','2025-01-06','ACC-5001', 0.00, 2100.00,'USD','REF-A004 Hardware','CLEARED'),
('BNK-A005','2025-01-07','ACC-5001', 0.00, 5500.00,'USD','REF-A005 Enterprise lic','CLEARED'),
('BNK-A006','2025-01-08','ACC-5001', 0.00,  450.00,'USD','REF-A006 Misc supplies','CLEARED'),
('BNK-A007','2025-01-09','ACC-5001', 0.00, 1900.75,'USD','REF-A007 Cloud storage','CLEARED'),
('BNK-A008','2025-01-10','ACC-5001', 0.00, 3200.00,'USD','REF-A008 Payroll','CLEARED'),
('BNK-A009','2025-01-11','ACC-5001', 0.00, 6750.00,'USD','REF-A009 Real estate dep','CLEARED'),
('BNK-A010','2025-01-12','ACC-5001', 0.00,  980.00,'USD','REF-A010 Travel reimb','CLEARED'),
('BNK-A011','2025-01-13','ACC-5001', 0.00, 2300.00,'USD','REF-A011 Marketing Jan','CLEARED'),
('BNK-A012','2025-01-14','ACC-5001', 0.00, 1150.50,'USD','REF-A012 Tools renewal','CLEARED'),
('BNK-A013','2025-01-15','ACC-5001', 0.00, 4400.00,'USD','REF-A013 Vendor logistics','CLEARED'),
('BNK-A014','2025-01-16','ACC-5001', 0.00,  760.00,'USD','REF-A014 Utility Jan','CLEARED'),
('BNK-A015','2025-01-17','ACC-5001', 0.00, 8900.00,'USD','REF-A015 Data-center','CLEARED'),
('BNK-A016','2025-01-18','ACC-5001', 0.00, 1050.00,'USD','REF-A016 SaaS Jan','CLEARED'),
('BNK-A017','2025-01-19','ACC-5001', 0.00, 3600.00,'USD','REF-A017 Outsourcing 101','CLEARED'),
('BNK-A018','2025-01-20','ACC-5001', 0.00, 2250.00,'USD','REF-A018 Training','CLEARED'),
('BNK-A019','2025-01-21','ACC-5001', 0.00,  520.00,'USD','REF-A019 Canteen','CLEARED'),
('BNK-A020','2025-01-22','ACC-5001', 0.00,12000.00,'USD','REF-A020 Infra deposit','CLEARED'),
('BNK-A021','2025-01-23','ACC-5001', 0.00, 1800.00,'USD','REF-A021 Design sub','CLEARED'),
('BNK-A022','2025-01-24','ACC-5001', 0.00, 3100.00,'USD','REF-A022 Freight Q1','CLEARED'),
('BNK-A023','2025-01-25','ACC-5001', 0.00,  640.75,'USD','REF-A023 Printing','CLEARED'),
('BNK-A024','2025-01-26','ACC-5001', 0.00, 2900.00,'USD','REF-A024 Cloud hosting','CLEARED'),
('BNK-A025','2025-01-27','ACC-5001', 0.00, 7200.00,'USD','REF-A025 Raw material','CLEARED'),
('BNK-A026','2025-01-28','ACC-5001', 0.00, 1350.00,'USD','REF-A026 Furniture','CLEARED'),
('BNK-A027','2025-01-29','ACC-5001', 0.00, 4100.00,'USD','REF-A027 Legal Jan','CLEARED'),
('BNK-A028','2025-01-30','ACC-5001', 0.00, 2700.00,'USD','REF-A028 Advertising','CLEARED'),
('BNK-A029','2025-01-31','ACC-5001', 0.00, 3850.00,'USD','REF-A029 Sub ext','CLEARED'),
('BNK-A030','2025-01-31','ACC-5001', 0.00,  980.00,'USD','REF-A030 Misc Jan','CLEARED'),
-- Feb (matches TXN-00031..TXN-00060)
('BNK-B001','2025-02-01','ACC-5001', 0.00, 2200.00,'USD','REF-B001 Infra m2','CLEARED'),
('BNK-B002','2025-02-02','ACC-5001', 0.00,  430.00,'USD','REF-B002 Canteen','CLEARED'),
('BNK-B003','2025-02-03','ACC-5001', 0.00, 6800.00,'USD','REF-B003 Payroll supp','CLEARED'),
('BNK-B004','2025-02-04','ACC-5001', 0.00, 1900.00,'USD','REF-B004 Marketing','CLEARED'),
('BNK-B005','2025-02-05','ACC-5001', 0.00, 3400.00,'USD','REF-B005 Data analytics','CLEARED'),
('BNK-B006','2025-02-06','ACC-5001', 0.00,  720.50,'USD','REF-B006 Courier','CLEARED'),
('BNK-B007','2025-02-07','ACC-5001', 0.00, 5100.00,'USD','REF-B007 Consulting','CLEARED'),
('BNK-B008','2025-02-08','ACC-5001', 0.00, 2450.00,'USD','REF-B008 Cloud backup','CLEARED'),
('BNK-B009','2025-02-09','ACC-5001', 0.00, 1100.00,'USD','REF-B009 Sub tools','CLEARED'),
('BNK-B010','2025-02-10','ACC-5001', 0.00, 8200.00,'USD','REF-B010 Equipment','CLEARED'),
('BNK-B011','2025-02-11','ACC-5001', 0.00, 1650.00,'USD','REF-B011 Utility','CLEARED'),
('BNK-B012','2025-02-12','ACC-5001', 0.00, 2900.00,'USD','REF-B012 HR platform','CLEARED'),
('BNK-B013','2025-02-13','ACC-5001', 0.00, 3350.00,'USD','REF-B013 Outsourcing 102','CLEARED'),
('BNK-B014','2025-02-14','ACC-5001', 0.00,  490.00,'USD','REF-B014 Gifts','CLEARED'),
('BNK-B015','2025-02-15','ACC-5001', 0.00,11500.00,'USD','REF-B015 Infra ph2','CLEARED'),
('BNK-B016','2025-02-16','ACC-5001', 0.00, 1750.00,'USD','REF-B016 Cloud CDN','CLEARED'),
('BNK-B017','2025-02-17','ACC-5001', 0.00, 3900.00,'USD','REF-B017 Legal Feb','CLEARED'),
('BNK-B018','2025-02-18','ACC-5001', 0.00, 2600.00,'USD','REF-B018 Advert print','CLEARED'),
('BNK-B019','2025-02-19','ACC-5001', 0.00,  610.00,'USD','REF-B019 Pantry','CLEARED'),
('BNK-B020','2025-02-20','ACC-5001', 0.00,14000.00,'USD','REF-B020 Acquisition M1','CLEARED'),
('BNK-B021','2025-02-21','ACC-5001', 0.00, 1250.00,'USD','REF-B021 Design tools','CLEARED'),
('BNK-B022','2025-02-22','ACC-5001', 0.00, 3100.00,'USD','REF-B022 Freight Feb','CLEARED'),
('BNK-B023','2025-02-23','ACC-5001', 0.00,  580.00,'USD','REF-B023 Printing Feb','CLEARED'),
('BNK-B024','2025-02-24','ACC-5001', 0.00, 2800.00,'USD','REF-B024 Cloud hosting','CLEARED'),
('BNK-B025','2025-02-25','ACC-5001', 0.00, 7500.00,'USD','REF-B025 Raw material','CLEARED'),
('BNK-B026','2025-02-26','ACC-5001', 0.00, 1400.00,'USD','REF-B026 Equip Feb','CLEARED'),
('BNK-B027','2025-02-27','ACC-5001', 0.00, 4200.00,'USD','REF-B027 Outsourcing 103','CLEARED'),
('BNK-B028','2025-02-28','ACC-5001', 0.00, 2550.00,'USD','REF-B028 Advert digital','CLEARED'),
('BNK-B029','2025-02-28','ACC-5001', 0.00, 3900.00,'USD','REF-B029 Software ext','CLEARED'),
('BNK-B030','2025-02-28','ACC-5001', 0.00,  870.00,'USD','REF-B030 Misc Feb','CLEARED'),
-- Mar (matches TXN-00061..TXN-00090)
('BNK-C001','2025-03-01','ACC-5001', 0.00, 2300.00,'USD','REF-C001 Infra Mar','CLEARED'),
('BNK-C002','2025-03-02','ACC-5001', 0.00,  460.00,'USD','REF-C002 Canteen','CLEARED'),
('BNK-C003','2025-03-03','ACC-5001', 0.00, 7000.00,'USD','REF-C003 Payroll','CLEARED'),
('BNK-C004','2025-03-04','ACC-5001', 0.00, 2000.00,'USD','REF-C004 Marketing','CLEARED'),
('BNK-C005','2025-03-05','ACC-5001', 0.00, 3600.00,'USD','REF-C005 Analytics','CLEARED'),
('BNK-C006','2025-03-06','ACC-5001', 0.00,  740.00,'USD','REF-C006 Courier','CLEARED'),
('BNK-C007','2025-03-07','ACC-5001', 0.00, 5300.00,'USD','REF-C007 Consulting','CLEARED'),
('BNK-C008','2025-03-08','ACC-5001', 0.00, 2500.00,'USD','REF-C008 Cloud backup','CLEARED'),
('BNK-C009','2025-03-09','ACC-5001', 0.00, 1150.00,'USD','REF-C009 SaaS','CLEARED'),
('BNK-C010','2025-03-10','ACC-5001', 0.00, 8500.00,'USD','REF-C010 Equipment','CLEARED'),
('BNK-C011','2025-03-11','ACC-5001', 0.00, 1700.00,'USD','REF-C011 Utility','CLEARED'),
('BNK-C012','2025-03-12','ACC-5001', 0.00, 3100.00,'USD','REF-C012 HR platform','CLEARED'),
('BNK-C013','2025-03-13','ACC-5001', 0.00, 3550.00,'USD','REF-C013 Outsourcing 104','CLEARED'),
('BNK-C014','2025-03-14','ACC-5001', 0.00,  510.00,'USD','REF-C014 Pantry','CLEARED'),
('BNK-C015','2025-03-15','ACC-5001', 0.00,12500.00,'USD','REF-C015 Infra ph3','CLEARED'),
('BNK-C016','2025-03-16','ACC-5001', 0.00, 1800.00,'USD','REF-C016 CDN','CLEARED'),
('BNK-C017','2025-03-17','ACC-5001', 0.00, 4100.00,'USD','REF-C017 Legal','CLEARED'),
('BNK-C018','2025-03-18','ACC-5001', 0.00, 2700.00,'USD','REF-C018 Advert','CLEARED'),
('BNK-C019','2025-03-19','ACC-5001', 0.00,  630.00,'USD','REF-C019 Misc','CLEARED'),
('BNK-C020','2025-03-20','ACC-5001', 0.00,15000.00,'USD','REF-C020 Acquisition M2','CLEARED'),
('BNK-C021','2025-03-21','ACC-5001', 0.00, 1300.00,'USD','REF-C021 Design','CLEARED'),
('BNK-C022','2025-03-22','ACC-5001', 0.00, 3200.00,'USD','REF-C022 Freight','CLEARED'),
('BNK-C023','2025-03-23','ACC-5001', 0.00,  600.00,'USD','REF-C023 Printing','CLEARED'),
('BNK-C024','2025-03-24','ACC-5001', 0.00, 2900.00,'USD','REF-C024 Hosting','CLEARED'),
('BNK-C025','2025-03-25','ACC-5001', 0.00, 7800.00,'USD','REF-C025 Raw material','CLEARED'),
('BNK-C026','2025-03-26','ACC-5001', 0.00, 1450.00,'USD','REF-C026 Office','CLEARED'),
('BNK-C027','2025-03-27','ACC-5001', 0.00, 4300.00,'USD','REF-C027 Outsourcing 105','CLEARED'),
('BNK-C028','2025-03-28','ACC-5001', 0.00, 2650.00,'USD','REF-C028 Advert2','CLEARED'),
('BNK-C029','2025-03-29','ACC-5001', 0.00, 4000.00,'USD','REF-C029 Software ext','CLEARED'),
('BNK-C030','2025-03-31','ACC-5001', 0.00,  900.00,'USD','REF-C030 Misc','CLEARED'),
-- Apr-Nov rows (matches TXN-00091..TXN-00180)
('BNK-D001','2025-04-01','ACC-5001', 0.00, 2400.00,'USD','REF-D001 Infra Apr','CLEARED'),
('BNK-D002','2025-04-03','ACC-5001', 0.00,  480.00,'USD','REF-D002 Canteen Apr','CLEARED'),
('BNK-D003','2025-04-05','ACC-5001', 0.00, 7200.00,'USD','REF-D003 Payroll supp','CLEARED'),
('BNK-D004','2025-04-07','ACC-5001', 0.00, 2100.00,'USD','REF-D004 Marketing Apr','CLEARED'),
('BNK-D005','2025-04-09','ACC-5001', 0.00, 3800.00,'USD','REF-D005 Analytics Apr','CLEARED'),
('BNK-D006','2025-04-11','ACC-5001', 0.00,  760.00,'USD','REF-D006 Courier Apr','CLEARED'),
('BNK-D007','2025-04-13','ACC-5001', 0.00, 5500.00,'USD','REF-D007 Consulting Apr','CLEARED'),
('BNK-D008','2025-04-15','ACC-5001', 0.00, 2600.00,'USD','REF-D008 Cloud Apr','CLEARED'),
('BNK-D009','2025-04-17','ACC-5001', 0.00, 1200.00,'USD','REF-D009 SaaS Apr','CLEARED'),
('BNK-D010','2025-04-19','ACC-5001', 0.00, 8800.00,'USD','REF-D010 Equipment Apr','CLEARED'),
('BNK-D011','2025-04-21','ACC-5001', 0.00, 1750.00,'USD','REF-D011 Utility Apr','CLEARED'),
('BNK-D012','2025-04-23','ACC-5001', 0.00, 3200.00,'USD','REF-D012 HR Apr','CLEARED'),
('BNK-D013','2025-04-25','ACC-5001', 0.00, 3650.00,'USD','REF-D013 Outsourcing 106','CLEARED'),
('BNK-D014','2025-04-27','ACC-5001', 0.00,  530.00,'USD','REF-D014 Pantry Apr','CLEARED'),
('BNK-D015','2025-04-29','ACC-5001', 0.00,13000.00,'USD','REF-D015 Infra ph4','CLEARED'),
('BNK-E001','2025-05-01','ACC-5001', 0.00, 1850.00,'USD','REF-E001 CDN May','CLEARED'),
('BNK-E002','2025-05-03','ACC-5001', 0.00, 4200.00,'USD','REF-E002 Legal May','CLEARED'),
('BNK-E003','2025-05-05','ACC-5001', 0.00, 2800.00,'USD','REF-E003 Advert May','CLEARED'),
('BNK-E004','2025-05-07','ACC-5001', 0.00,  650.00,'USD','REF-E004 Misc May','CLEARED'),
('BNK-E005','2025-05-09','ACC-5001', 0.00,16000.00,'USD','REF-E005 Acquisition M3','CLEARED'),
('BNK-E006','2025-05-11','ACC-5001', 0.00, 1350.00,'USD','REF-E006 Design May','CLEARED'),
('BNK-E007','2025-05-13','ACC-5001', 0.00, 3300.00,'USD','REF-E007 Freight May','CLEARED'),
('BNK-E008','2025-05-15','ACC-5001', 0.00,  620.00,'USD','REF-E008 Printing May','CLEARED'),
('BNK-E009','2025-05-17','ACC-5001', 0.00, 3000.00,'USD','REF-E009 Hosting May','CLEARED'),
('BNK-E010','2025-05-19','ACC-5001', 0.00, 8100.00,'USD','REF-E010 Raw material','CLEARED'),
('BNK-E011','2025-05-21','ACC-5001', 0.00, 1500.00,'USD','REF-E011 Office May','CLEARED'),
('BNK-E012','2025-05-23','ACC-5001', 0.00, 4400.00,'USD','REF-E012 Outsourcing 107','CLEARED'),
('BNK-E013','2025-05-25','ACC-5001', 0.00, 2750.00,'USD','REF-E013 Advert May2','CLEARED'),
('BNK-E014','2025-05-27','ACC-5001', 0.00, 4100.00,'USD','REF-E014 Software May','CLEARED'),
('BNK-E015','2025-05-29','ACC-5001', 0.00,  940.00,'USD','REF-E015 Misc May2','CLEARED'),
('BNK-F001','2025-06-02','ACC-5001', 0.00, 2500.00,'USD','REF-F001 Infra Jun','CLEARED'),
('BNK-F002','2025-06-04','ACC-5001', 0.00,  500.00,'USD','REF-F002 Canteen Jun','CLEARED'),
('BNK-F003','2025-06-06','ACC-5001', 0.00, 7400.00,'USD','REF-F003 Payroll Jun','CLEARED'),
('BNK-F004','2025-06-08','ACC-5001', 0.00, 2200.00,'USD','REF-F004 Marketing Jun','CLEARED'),
('BNK-F005','2025-06-10','ACC-5001', 0.00, 4000.00,'USD','REF-F005 Analytics Jun','CLEARED'),
('BNK-F006','2025-06-12','ACC-5001', 0.00,  780.00,'USD','REF-F006 Courier Jun','CLEARED'),
('BNK-F007','2025-06-14','ACC-5001', 0.00, 5700.00,'USD','REF-F007 Consulting Jun','CLEARED'),
('BNK-F008','2025-06-16','ACC-5001', 0.00, 2700.00,'USD','REF-F008 Cloud Jun','CLEARED'),
('BNK-F009','2025-06-18','ACC-5001', 0.00, 1250.00,'USD','REF-F009 SaaS Jun','CLEARED'),
('BNK-F010','2025-06-20','ACC-5001', 0.00, 9100.00,'USD','REF-F010 Equipment Jun','CLEARED'),
('BNK-G001','2025-07-01','ACC-5001', 0.00, 1800.00,'USD','REF-G001 Utility Jul','CLEARED'),
('BNK-G002','2025-07-03','ACC-5001', 0.00, 3300.00,'USD','REF-G002 HR Jul','CLEARED'),
('BNK-G003','2025-07-05','ACC-5001', 0.00, 3750.00,'USD','REF-G003 Outsourcing 108','CLEARED'),
('BNK-G004','2025-07-07','ACC-5001', 0.00,  550.00,'USD','REF-G004 Pantry Jul','CLEARED'),
('BNK-G005','2025-07-09','ACC-5001', 0.00,13500.00,'USD','REF-G005 Infra ph5','CLEARED'),
('BNK-G006','2025-07-11','ACC-5001', 0.00, 1900.00,'USD','REF-G006 CDN Jul','CLEARED'),
('BNK-G007','2025-07-13','ACC-5001', 0.00, 4300.00,'USD','REF-G007 Legal Jul','CLEARED'),
('BNK-G008','2025-07-15','ACC-5001', 0.00, 2900.00,'USD','REF-G008 Advert Jul','CLEARED'),
('BNK-G009','2025-07-17','ACC-5001', 0.00,  670.00,'USD','REF-G009 Misc Jul','CLEARED'),
('BNK-G010','2025-07-19','ACC-5001', 0.00,17000.00,'USD','REF-G010 Acquisition M4','CLEARED'),
('BNK-G011','2025-07-21','ACC-5001', 0.00, 1400.00,'USD','REF-G011 Design Jul','CLEARED'),
('BNK-G012','2025-07-23','ACC-5001', 0.00, 3400.00,'USD','REF-G012 Freight Jul','CLEARED'),
('BNK-G013','2025-07-25','ACC-5001', 0.00,  640.00,'USD','REF-G013 Printing Jul','CLEARED'),
('BNK-G014','2025-07-27','ACC-5001', 0.00, 3100.00,'USD','REF-G014 Hosting Jul','CLEARED'),
('BNK-G015','2025-07-29','ACC-5001', 0.00, 8400.00,'USD','REF-G015 Raw material Jul','CLEARED'),
('BNK-H001','2025-08-01','ACC-5001', 0.00, 1550.00,'USD','REF-H001 Office Aug','CLEARED'),
('BNK-H002','2025-08-03','ACC-5001', 0.00, 4500.00,'USD','REF-H002 Outsourcing 109','CLEARED'),
('BNK-H003','2025-08-05','ACC-5001', 0.00, 2850.00,'USD','REF-H003 Advert Aug','CLEARED'),
('BNK-H004','2025-08-07','ACC-5001', 0.00, 4200.00,'USD','REF-H004 Software Aug','CLEARED'),
('BNK-H005','2025-08-09','ACC-5001', 0.00,  970.00,'USD','REF-H005 Misc Aug','CLEARED'),
('BNK-I001','2025-09-01','ACC-5001', 0.00, 2600.00,'USD','REF-I001 Infra Sep','CLEARED'),
('BNK-I002','2025-09-03','ACC-5001', 0.00,  520.00,'USD','REF-I002 Canteen Sep','CLEARED'),
('BNK-I003','2025-09-05','ACC-5001', 0.00, 7600.00,'USD','REF-I003 Payroll Sep','CLEARED'),
('BNK-I004','2025-09-07','ACC-5001', 0.00, 2300.00,'USD','REF-I004 Marketing Sep','CLEARED'),
('BNK-I005','2025-09-09','ACC-5001', 0.00, 4200.00,'USD','REF-I005 Analytics Sep','CLEARED'),
('BNK-I006','2025-09-11','ACC-5001', 0.00,  800.00,'USD','REF-I006 Courier Sep','CLEARED'),
('BNK-I007','2025-09-13','ACC-5001', 0.00, 5900.00,'USD','REF-I007 Consulting Sep','CLEARED'),
('BNK-I008','2025-09-15','ACC-5001', 0.00, 2800.00,'USD','REF-I008 Cloud Sep','CLEARED'),
('BNK-I009','2025-09-17','ACC-5001', 0.00, 1300.00,'USD','REF-I009 SaaS Sep','CLEARED'),
('BNK-I010','2025-09-19','ACC-5001', 0.00, 9400.00,'USD','REF-I010 Equipment Sep','CLEARED'),
('BNK-J001','2025-10-01','ACC-5001', 0.00, 1850.00,'USD','REF-J001 Utility Oct','CLEARED'),
('BNK-J002','2025-10-03','ACC-5001', 0.00, 3400.00,'USD','REF-J002 HR Oct','CLEARED'),
('BNK-J003','2025-10-05','ACC-5001', 0.00, 3850.00,'USD','REF-J003 Outsourcing 110','CLEARED'),
('BNK-J004','2025-10-07','ACC-5001', 0.00,  570.00,'USD','REF-J004 Pantry Oct','CLEARED'),
('BNK-J005','2025-10-09','ACC-5001', 0.00,14000.00,'USD','REF-J005 Infra ph6','CLEARED'),
('BNK-J006','2025-10-11','ACC-5001', 0.00, 1950.00,'USD','REF-J006 CDN Oct','CLEARED'),
('BNK-J007','2025-10-13','ACC-5001', 0.00, 4400.00,'USD','REF-J007 Legal Oct','CLEARED'),
('BNK-J008','2025-10-15','ACC-5001', 0.00, 3000.00,'USD','REF-J008 Advert Oct','CLEARED'),
('BNK-J009','2025-10-17','ACC-5001', 0.00,  690.00,'USD','REF-J009 Misc Oct','CLEARED'),
('BNK-J010','2025-10-19','ACC-5001', 0.00,18000.00,'USD','REF-J010 Acquisition M5','CLEARED'),
('BNK-K001','2025-11-01','ACC-5001', 0.00, 1450.00,'USD','REF-K001 Design Nov','CLEARED'),
('BNK-K002','2025-11-03','ACC-5001', 0.00, 3500.00,'USD','REF-K002 Freight Nov','CLEARED'),
('BNK-K003','2025-11-05','ACC-5001', 0.00,  660.00,'USD','REF-K003 Printing Nov','CLEARED'),
('BNK-K004','2025-11-07','ACC-5001', 0.00, 3200.00,'USD','REF-K004 Hosting Nov','CLEARED'),
('BNK-K005','2025-11-09','ACC-5001', 0.00, 8700.00,'USD','REF-K005 Raw material Nov','CLEARED'),
('BNK-K006','2025-11-11','ACC-5001', 0.00, 1600.00,'USD','REF-K006 Office Nov','CLEARED'),
('BNK-K007','2025-11-13','ACC-5001', 0.00, 4600.00,'USD','REF-K007 Outsourcing 111','CLEARED'),
('BNK-K008','2025-11-15','ACC-5001', 0.00, 2950.00,'USD','REF-K008 Advert Nov','CLEARED'),
('BNK-K009','2025-11-17','ACC-5001', 0.00, 4300.00,'USD','REF-K009 Software Nov','CLEARED'),
('BNK-K010','2025-11-19','ACC-5001', 0.00, 1000.00,'USD','REF-K010 Misc Nov','CLEARED'),
-- Dec 2025 rows
('BNK-L001','2025-12-01','ACC-5001', 0.00, 2700.00,'USD','REF-L001 Infra Dec','CLEARED'),
('BNK-L002','2025-12-03','ACC-5001', 0.00,  540.00,'USD','REF-L002 Canteen Dec','CLEARED'),
('BNK-L003','2025-12-05','ACC-5001', 0.00, 7800.00,'USD','REF-L003 Payroll Dec','CLEARED'),
('BNK-L004','2025-12-07','ACC-5001', 0.00, 2400.00,'USD','REF-L004 Marketing Dec','CLEARED'),
('BNK-L005','2025-12-09','ACC-5001', 0.00, 4400.00,'USD','REF-L005 Analytics Dec','CLEARED'),
('BNK-L006','2025-12-11','ACC-5001', 0.00,  820.00,'USD','REF-L006 Courier Dec','CLEARED'),
('BNK-L007','2025-12-13','ACC-5001', 0.00, 6100.00,'USD','REF-L007 Consulting Dec','CLEARED'),
('BNK-L008','2025-12-15','ACC-5001', 0.00, 2900.00,'USD','REF-L008 Cloud Dec','CLEARED'),
('BNK-L009','2025-12-17','ACC-5001', 0.00, 1350.00,'USD','REF-L009 SaaS Dec','CLEARED'),
('BNK-L010','2025-12-19','ACC-5001', 0.00, 9700.00,'USD','REF-L010 Equipment Dec','CLEARED'),
-- *** AMOUNT MISMATCHES: bank shows slightly different amount (bank fees applied) ***
('BNK-MIS-01','2025-01-03','ACC-5001', 0.00, 1247.50,'USD','REF-A001 Sub Q1 - net of fee','CLEARED'),
('BNK-MIS-02','2025-01-07','ACC-5001', 0.00, 5497.00,'USD','REF-A005 Lic batch - net of fee','CLEARED'),
('BNK-MIS-03','2025-01-15','ACC-5001', 0.00, 8895.00,'USD','REF-A015 DC co-loc - net fee','CLEARED'),
('BNK-MIS-04','2025-01-22','ACC-5001', 0.00,11998.00,'USD','REF-A020 Infra deposit net','CLEARED'),
('BNK-MIS-05','2025-02-15','ACC-5001', 0.00,11497.50,'USD','REF-B015 Infra ph2 net','CLEARED'),
('BNK-MIS-06','2025-02-20','ACC-5001', 0.00,13997.00,'USD','REF-B020 Acquisition net','CLEARED'),
('BNK-MIS-07','2025-03-20','ACC-5001', 0.00,14997.50,'USD','REF-C020 Acquisition net','CLEARED'),
('BNK-MIS-08','2025-05-09','ACC-5001', 0.00,15997.00,'USD','REF-E005 Acquisition net','CLEARED'),
('BNK-MIS-09','2025-07-19','ACC-5001', 0.00,16997.00,'USD','REF-G010 Acquisition net','CLEARED'),
('BNK-MIS-10','2025-10-19','ACC-5001', 0.00,17997.00,'USD','REF-J010 Acquisition net','CLEARED'),
-- *** BANK DUPLICATES ***
('BNK-DUP-01','2025-01-03','ACC-5001', 0.00, 1250.00,'USD','REF-A001 DUPLICATE entry','CLEARED'),
('BNK-DUP-02','2025-02-02','ACC-5001', 0.00,  430.00,'USD','REF-B002 DUPLICATE entry','CLEARED'),
('BNK-DUP-03','2025-03-21','ACC-5001', 0.00, 1300.00,'USD','REF-C021 DUPLICATE entry','CLEARED'),
-- *** BANK-ONLY (no company record) ***
('BNK-UNM-01','2025-11-28','ACC-5001', 0.00, 2500.00,'USD','Unknown credit Nov28','CLEARED'),
('BNK-UNM-02','2025-11-29','ACC-5001', 0.00, 1200.00,'USD','Unknown credit Nov29','CLEARED'),
('BNK-UNM-03','2025-11-30','ACC-5001', 0.00, 3800.00,'USD','Unknown credit Nov30','CLEARED'),
('BNK-UNM-04','2025-12-20','ACC-5001', 0.00,  700.00,'USD','Unknown credit Dec20','CLEARED'),
('BNK-UNM-05','2025-12-21','ACC-5001', 0.00, 4100.00,'USD','Unknown credit Dec21','CLEARED');

-- -----------------------------------------------------------------------
-- 4. Gateway Transactions  (160 records)
--    Rows match company transactions by reference_no via order_id field
--    Some rows are missing (MISSING_GATEWAY scenario)
--    Some rows have amount mismatches
-- -----------------------------------------------------------------------

INSERT INTO gateway_transactions
    (gateway_txn_ref, txn_datetime, merchant_id, order_id, amount, currency_code, gateway_status, payment_method)
VALUES
-- Jan (matches TXN-00001..TXN-00028; TXN-00029 and TXN-00030 missing gateway)
('GW-A001','2025-01-03 10:15:00','MERCH-001','REF-A001', 1250.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-A002','2025-01-04 11:20:00','MERCH-001','REF-A002', 3400.50,'USD','CAPTURED','WIRE'),
('GW-A003','2025-01-05 09:45:00','MERCH-001','REF-A003',  875.25,'USD','CAPTURED','ACH'),
('GW-A004','2025-01-06 14:30:00','MERCH-001','REF-A004', 2100.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-A005','2025-01-07 16:00:00','MERCH-001','REF-A005', 5500.00,'USD','CAPTURED','WIRE'),
('GW-A006','2025-01-08 08:45:00','MERCH-001','REF-A006',  450.00,'USD','CAPTURED','UPI'),
('GW-A007','2025-01-09 12:15:00','MERCH-001','REF-A007', 1900.75,'USD','CAPTURED','CARD_CREDIT'),
('GW-A008','2025-01-10 10:00:00','MERCH-001','REF-A008', 3200.00,'USD','CAPTURED','ACH'),
('GW-A009','2025-01-11 13:30:00','MERCH-001','REF-A009', 6750.00,'USD','CAPTURED','WIRE'),
('GW-A010','2025-01-12 09:00:00','MERCH-001','REF-A010',  980.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-A011','2025-01-13 11:45:00','MERCH-001','REF-A011', 2300.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-A012','2025-01-14 14:00:00','MERCH-001','REF-A012', 1150.50,'USD','CAPTURED','ACH'),
('GW-A013','2025-01-15 10:30:00','MERCH-001','REF-A013', 4400.00,'USD','CAPTURED','WIRE'),
('GW-A014','2025-01-16 08:15:00','MERCH-001','REF-A014',  760.00,'USD','CAPTURED','UPI'),
('GW-A015','2025-01-17 15:45:00','MERCH-001','REF-A015', 8900.00,'USD','CAPTURED','WIRE'),
('GW-A016','2025-01-18 12:00:00','MERCH-001','REF-A016', 1050.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-A017','2025-01-19 09:30:00','MERCH-001','REF-A017', 3600.00,'USD','CAPTURED','ACH'),
('GW-A018','2025-01-20 11:15:00','MERCH-001','REF-A018', 2250.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-A019','2025-01-21 08:30:00','MERCH-001','REF-A019',  520.00,'USD','CAPTURED','UPI'),
('GW-A020','2025-01-22 16:00:00','MERCH-001','REF-A020',12000.00,'USD','CAPTURED','WIRE'),
('GW-A021','2025-01-23 10:45:00','MERCH-001','REF-A021', 1800.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-A022','2025-01-24 13:15:00','MERCH-001','REF-A022', 3100.00,'USD','CAPTURED','WIRE'),
('GW-A023','2025-01-25 09:00:00','MERCH-001','REF-A023',  640.75,'USD','CAPTURED','ACH'),
('GW-A024','2025-01-26 11:30:00','MERCH-001','REF-A024', 2900.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-A025','2025-01-27 14:45:00','MERCH-001','REF-A025', 7200.00,'USD','CAPTURED','WIRE'),
('GW-A026','2025-01-28 08:00:00','MERCH-001','REF-A026', 1350.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-A027','2025-01-29 12:30:00','MERCH-001','REF-A027', 4100.00,'USD','CAPTURED','ACH'),
('GW-A028','2025-01-30 10:15:00','MERCH-001','REF-A028', 2700.00,'USD','CAPTURED','WIRE'),
-- Feb (matches TXN-00031..TXN-00058; last 2 of Feb missing gateway)
('GW-B001','2025-02-01 10:00:00','MERCH-001','REF-B001', 2200.00,'USD','CAPTURED','WIRE'),
('GW-B002','2025-02-02 09:15:00','MERCH-001','REF-B002',  430.00,'USD','CAPTURED','UPI'),
('GW-B003','2025-02-03 11:30:00','MERCH-001','REF-B003', 6800.00,'USD','CAPTURED','ACH'),
('GW-B004','2025-02-04 14:45:00','MERCH-001','REF-B004', 1900.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-B005','2025-02-05 08:00:00','MERCH-001','REF-B005', 3400.00,'USD','CAPTURED','WIRE'),
('GW-B006','2025-02-06 12:15:00','MERCH-001','REF-B006',  720.50,'USD','CAPTURED','CARD_DEBIT'),
('GW-B007','2025-02-07 10:30:00','MERCH-001','REF-B007', 5100.00,'USD','CAPTURED','WIRE'),
('GW-B008','2025-02-08 09:45:00','MERCH-001','REF-B008', 2450.00,'USD','CAPTURED','ACH'),
('GW-B009','2025-02-09 13:00:00','MERCH-001','REF-B009', 1100.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-B010','2025-02-10 11:15:00','MERCH-001','REF-B010', 8200.00,'USD','CAPTURED','WIRE'),
('GW-B011','2025-02-11 08:30:00','MERCH-001','REF-B011', 1650.00,'USD','CAPTURED','UPI'),
('GW-B012','2025-02-12 15:00:00','MERCH-001','REF-B012', 2900.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-B013','2025-02-13 10:15:00','MERCH-001','REF-B013', 3350.00,'USD','CAPTURED','ACH'),
('GW-B014','2025-02-14 09:30:00','MERCH-001','REF-B014',  490.00,'USD','CAPTURED','UPI'),
('GW-B015','2025-02-15 14:00:00','MERCH-001','REF-B015',11500.00,'USD','CAPTURED','WIRE'),
('GW-B016','2025-02-16 11:45:00','MERCH-001','REF-B016', 1750.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-B017','2025-02-17 08:15:00','MERCH-001','REF-B017', 3900.00,'USD','CAPTURED','WIRE'),
('GW-B018','2025-02-18 12:30:00','MERCH-001','REF-B018', 2600.00,'USD','CAPTURED','ACH'),
('GW-B019','2025-02-19 10:00:00','MERCH-001','REF-B019',  610.00,'USD','CAPTURED','UPI'),
('GW-B020','2025-02-20 16:15:00','MERCH-001','REF-B020',14000.00,'USD','CAPTURED','WIRE'),
('GW-B021','2025-02-21 09:00:00','MERCH-001','REF-B021', 1250.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-B022','2025-02-22 13:45:00','MERCH-001','REF-B022', 3100.00,'USD','CAPTURED','WIRE'),
('GW-B023','2025-02-23 11:00:00','MERCH-001','REF-B023',  580.00,'USD','CAPTURED','ACH'),
('GW-B024','2025-02-24 08:30:00','MERCH-001','REF-B024', 2800.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-B025','2025-02-25 15:15:00','MERCH-001','REF-B025', 7500.00,'USD','CAPTURED','WIRE'),
('GW-B026','2025-02-26 10:45:00','MERCH-001','REF-B026', 1400.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-B027','2025-02-27 09:15:00','MERCH-001','REF-B027', 4200.00,'USD','CAPTURED','ACH'),
('GW-B028','2025-02-28 14:30:00','MERCH-001','REF-B028', 2550.00,'USD','CAPTURED','WIRE'),
-- Mar (matches TXN-00061..TXN-00088; last 2 of Mar missing)
('GW-C001','2025-03-01 10:00:00','MERCH-001','REF-C001', 2300.00,'USD','CAPTURED','WIRE'),
('GW-C002','2025-03-02 09:00:00','MERCH-001','REF-C002',  460.00,'USD','CAPTURED','UPI'),
('GW-C003','2025-03-03 11:15:00','MERCH-001','REF-C003', 7000.00,'USD','CAPTURED','ACH'),
('GW-C004','2025-03-04 14:30:00','MERCH-001','REF-C004', 2000.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-C005','2025-03-05 08:00:00','MERCH-001','REF-C005', 3600.00,'USD','CAPTURED','WIRE'),
('GW-C006','2025-03-06 12:00:00','MERCH-001','REF-C006',  740.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-C007','2025-03-07 10:30:00','MERCH-001','REF-C007', 5300.00,'USD','CAPTURED','WIRE'),
('GW-C008','2025-03-08 09:45:00','MERCH-001','REF-C008', 2500.00,'USD','CAPTURED','ACH'),
('GW-C009','2025-03-09 13:00:00','MERCH-001','REF-C009', 1150.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-C010','2025-03-10 11:15:00','MERCH-001','REF-C010', 8500.00,'USD','CAPTURED','WIRE'),
('GW-C011','2025-03-11 08:30:00','MERCH-001','REF-C011', 1700.00,'USD','CAPTURED','UPI'),
('GW-C012','2025-03-12 15:00:00','MERCH-001','REF-C012', 3100.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-C013','2025-03-13 10:15:00','MERCH-001','REF-C013', 3550.00,'USD','CAPTURED','ACH'),
('GW-C014','2025-03-14 09:30:00','MERCH-001','REF-C014',  510.00,'USD','CAPTURED','UPI'),
('GW-C015','2025-03-15 14:00:00','MERCH-001','REF-C015',12500.00,'USD','CAPTURED','WIRE'),
('GW-C016','2025-03-16 11:45:00','MERCH-001','REF-C016', 1800.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-C017','2025-03-17 08:15:00','MERCH-001','REF-C017', 4100.00,'USD','CAPTURED','WIRE'),
('GW-C018','2025-03-18 12:30:00','MERCH-001','REF-C018', 2700.00,'USD','CAPTURED','ACH'),
('GW-C019','2025-03-19 10:00:00','MERCH-001','REF-C019',  630.00,'USD','CAPTURED','UPI'),
('GW-C020','2025-03-20 16:15:00','MERCH-001','REF-C020',15000.00,'USD','CAPTURED','WIRE'),
('GW-C021','2025-03-21 09:00:00','MERCH-001','REF-C021', 1300.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-C022','2025-03-22 13:45:00','MERCH-001','REF-C022', 3200.00,'USD','CAPTURED','WIRE'),
('GW-C023','2025-03-23 11:00:00','MERCH-001','REF-C023',  600.00,'USD','CAPTURED','ACH'),
('GW-C024','2025-03-24 08:30:00','MERCH-001','REF-C024', 2900.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-C025','2025-03-25 15:15:00','MERCH-001','REF-C025', 7800.00,'USD','CAPTURED','WIRE'),
('GW-C026','2025-03-26 10:45:00','MERCH-001','REF-C026', 1450.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-C027','2025-03-27 09:15:00','MERCH-001','REF-C027', 4300.00,'USD','CAPTURED','ACH'),
('GW-C028','2025-03-28 14:30:00','MERCH-001','REF-C028', 2650.00,'USD','CAPTURED','WIRE'),
-- Apr-Dec (sample coverage — 44 rows)
('GW-D001','2025-04-01 10:00:00','MERCH-001','REF-D001', 2400.00,'USD','CAPTURED','WIRE'),
('GW-D003','2025-04-05 11:30:00','MERCH-001','REF-D003', 7200.00,'USD','CAPTURED','ACH'),
('GW-D005','2025-04-09 08:00:00','MERCH-001','REF-D005', 3800.00,'USD','CAPTURED','WIRE'),
('GW-D007','2025-04-13 10:30:00','MERCH-001','REF-D007', 5500.00,'USD','CAPTURED','WIRE'),
('GW-D010','2025-04-19 11:15:00','MERCH-001','REF-D010', 8800.00,'USD','CAPTURED','WIRE'),
('GW-D015','2025-04-29 14:00:00','MERCH-001','REF-D015',13000.00,'USD','CAPTURED','WIRE'),
('GW-E001','2025-05-01 10:00:00','MERCH-001','REF-E001', 1850.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-E002','2025-05-03 09:15:00','MERCH-001','REF-E002', 4200.00,'USD','CAPTURED','WIRE'),
('GW-E005','2025-05-09 08:00:00','MERCH-001','REF-E005',16000.00,'USD','CAPTURED','WIRE'),
('GW-E007','2025-05-13 10:30:00','MERCH-001','REF-E007', 3300.00,'USD','CAPTURED','WIRE'),
('GW-E010','2025-05-19 11:15:00','MERCH-001','REF-E010', 8100.00,'USD','CAPTURED','WIRE'),
('GW-F001','2025-06-02 10:00:00','MERCH-001','REF-F001', 2500.00,'USD','CAPTURED','WIRE'),
('GW-F003','2025-06-06 11:30:00','MERCH-001','REF-F003', 7400.00,'USD','CAPTURED','ACH'),
('GW-F005','2025-06-10 08:00:00','MERCH-001','REF-F005', 4000.00,'USD','CAPTURED','WIRE'),
('GW-F007','2025-06-14 10:30:00','MERCH-001','REF-F007', 5700.00,'USD','CAPTURED','WIRE'),
('GW-F010','2025-06-20 11:15:00','MERCH-001','REF-F010', 9100.00,'USD','CAPTURED','WIRE'),
('GW-G001','2025-07-01 10:00:00','MERCH-001','REF-G001', 1800.00,'USD','CAPTURED','UPI'),
('GW-G005','2025-07-09 14:00:00','MERCH-001','REF-G005',13500.00,'USD','CAPTURED','WIRE'),
('GW-G007','2025-07-13 09:15:00','MERCH-001','REF-G007', 4300.00,'USD','CAPTURED','WIRE'),
('GW-G010','2025-07-19 16:15:00','MERCH-001','REF-G010',17000.00,'USD','CAPTURED','WIRE'),
('GW-G012','2025-07-23 13:45:00','MERCH-001','REF-G012', 3400.00,'USD','CAPTURED','WIRE'),
('GW-G015','2025-07-29 15:15:00','MERCH-001','REF-G015', 8400.00,'USD','CAPTURED','WIRE'),
('GW-H002','2025-08-03 09:15:00','MERCH-001','REF-H002', 4500.00,'USD','CAPTURED','ACH'),
('GW-H004','2025-08-07 11:45:00','MERCH-001','REF-H004', 4200.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-I001','2025-09-01 10:00:00','MERCH-001','REF-I001', 2600.00,'USD','CAPTURED','WIRE'),
('GW-I003','2025-09-05 11:30:00','MERCH-001','REF-I003', 7600.00,'USD','CAPTURED','ACH'),
('GW-I005','2025-09-09 08:00:00','MERCH-001','REF-I005', 4200.00,'USD','CAPTURED','WIRE'),
('GW-I007','2025-09-13 10:30:00','MERCH-001','REF-I007', 5900.00,'USD','CAPTURED','WIRE'),
('GW-I010','2025-09-19 11:15:00','MERCH-001','REF-I010', 9400.00,'USD','CAPTURED','WIRE'),
('GW-J005','2025-10-09 14:00:00','MERCH-001','REF-J005',14000.00,'USD','CAPTURED','WIRE'),
('GW-J007','2025-10-13 09:15:00','MERCH-001','REF-J007', 4400.00,'USD','CAPTURED','WIRE'),
('GW-J010','2025-10-19 16:15:00','MERCH-001','REF-J010',18000.00,'USD','CAPTURED','WIRE'),
('GW-K001','2025-11-01 10:00:00','MERCH-001','REF-K001', 1450.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-K005','2025-11-09 15:15:00','MERCH-001','REF-K005', 8700.00,'USD','CAPTURED','WIRE'),
('GW-K007','2025-11-13 09:15:00','MERCH-001','REF-K007', 4600.00,'USD','CAPTURED','ACH'),
('GW-L001','2025-12-01 10:00:00','MERCH-001','REF-L001', 2700.00,'USD','CAPTURED','WIRE'),
('GW-L003','2025-12-05 11:30:00','MERCH-001','REF-L003', 7800.00,'USD','CAPTURED','ACH'),
('GW-L005','2025-12-09 08:00:00','MERCH-001','REF-L005', 4400.00,'USD','CAPTURED','WIRE'),
('GW-L007','2025-12-13 10:30:00','MERCH-001','REF-L007', 6100.00,'USD','CAPTURED','WIRE'),
('GW-L010','2025-12-19 11:15:00','MERCH-001','REF-L010', 9700.00,'USD','CAPTURED','WIRE'),
-- *** GATEWAY AMOUNT MISMATCHES ***
('GW-MIS-01','2025-01-07 16:01:00','MERCH-001','REF-A005', 5495.00,'USD','CAPTURED','WIRE'),
('GW-MIS-02','2025-02-15 14:01:00','MERCH-001','REF-B015',11495.00,'USD','CAPTURED','WIRE'),
('GW-MIS-03','2025-03-20 16:16:00','MERCH-001','REF-C020',14995.00,'USD','CAPTURED','WIRE'),
-- *** GATEWAY DUPLICATES ***
('GW-DUP-01','2025-01-03 10:16:00','MERCH-001','REF-A001', 1250.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-DUP-02','2025-02-02 09:16:00','MERCH-001','REF-B002',  430.00,'USD','CAPTURED','UPI'),
-- *** GATEWAY-ONLY (no company record) ***
('GW-UNM-01','2025-11-28 10:00:00','MERCH-002','ORD-X001', 950.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-UNM-02','2025-11-29 11:00:00','MERCH-002','ORD-X002',2250.00,'USD','CAPTURED','CARD_DEBIT'),
('GW-UNM-03','2025-12-20 09:30:00','MERCH-002','ORD-X003',1100.00,'USD','CAPTURED','CARD_CREDIT'),
('GW-UNM-04','2025-12-21 14:00:00','MERCH-002','ORD-X004',3400.00,'USD','CAPTURED','WIRE');

-- -----------------------------------------------------------------------
-- 5. Mark known duplicate records
-- -----------------------------------------------------------------------

UPDATE company_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT company_txn_id FROM
                        (SELECT company_txn_id FROM company_transactions
                         WHERE reference_no = 'REF-A001'
                         ORDER BY company_txn_id LIMIT 1) t)
WHERE transaction_id = 'TXN-00191';

UPDATE company_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT company_txn_id FROM
                        (SELECT company_txn_id FROM company_transactions
                         WHERE reference_no = 'REF-B002'
                         ORDER BY company_txn_id LIMIT 1) t)
WHERE transaction_id = 'TXN-00192';

UPDATE company_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT company_txn_id FROM
                        (SELECT company_txn_id FROM company_transactions
                         WHERE reference_no = 'REF-C021'
                         ORDER BY company_txn_id LIMIT 1) t)
WHERE transaction_id = 'TXN-00193';

UPDATE bank_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT bank_txn_id FROM
                        (SELECT bank_txn_id FROM bank_transactions
                         WHERE description LIKE '%REF-A001%' AND bank_ref NOT LIKE 'BNK-DUP%'
                         ORDER BY bank_txn_id LIMIT 1) t)
WHERE bank_ref = 'BNK-DUP-01';

UPDATE bank_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT bank_txn_id FROM
                        (SELECT bank_txn_id FROM bank_transactions
                         WHERE description LIKE '%REF-B002%' AND bank_ref NOT LIKE 'BNK-DUP%'
                         ORDER BY bank_txn_id LIMIT 1) t)
WHERE bank_ref = 'BNK-DUP-02';

UPDATE bank_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT bank_txn_id FROM
                        (SELECT bank_txn_id FROM bank_transactions
                         WHERE description LIKE '%REF-C021%' AND bank_ref NOT LIKE 'BNK-DUP%'
                         ORDER BY bank_txn_id LIMIT 1) t)
WHERE bank_ref = 'BNK-DUP-03';

UPDATE gateway_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT gateway_txn_id FROM
                        (SELECT gateway_txn_id FROM gateway_transactions
                         WHERE order_id = 'REF-A001' AND gateway_txn_ref NOT LIKE 'GW-DUP%'
                         ORDER BY gateway_txn_id LIMIT 1) t)
WHERE gateway_txn_ref = 'GW-DUP-01';

UPDATE gateway_transactions
SET is_duplicate = 1,
    duplicate_of_id = (SELECT gateway_txn_id FROM
                        (SELECT gateway_txn_id FROM gateway_transactions
                         WHERE order_id = 'REF-B002' AND gateway_txn_ref NOT LIKE 'GW-DUP%'
                         ORDER BY gateway_txn_id LIMIT 1) t)
WHERE gateway_txn_ref = 'GW-DUP-02';

-- -----------------------------------------------------------------------
-- End of sample_data.sql
-- -----------------------------------------------------------------------
