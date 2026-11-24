-- =====================================================================
-- 11_test_partitioning.sql
-- Tests of partitioning: automatic creation of an interval partition,
-- partition pruning and DML through the view CustomerFull.
-- =====================================================================
-- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Run after 10_partitioning.sql. Everything is undone with ROLLBACK at the end
-- (the auto-created partition stays, it is DDL-created metadata).
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 200
COLUMN partition_name FORMAT A16

-- =====================================================================
-- Test 1: insert into a month without a partition (2027-03)
-- EXPECTED: before = 0 partitions for this month, after = 1 (new partition
-- with a system generated name SYS_P...)
-- =====================================================================
SELECT COUNT(*) AS partitions_before
  FROM user_tab_partitions
 WHERE table_name = 'INVOICE';

INSERT INTO Invoice (InvoiceNo, IssueDate, DueDate, OrderNo, CityId, CurrencyCode)
VALUES ('T-I-0001', DATE '2027-03-15', DATE '2027-04-14', 'G-SO-00001', 101, 'EUR');

SELECT COUNT(*) AS partitions_after
  FROM user_tab_partitions
 WHERE table_name = 'INVOICE';

-- the row lies in the new partition
SELECT InvoiceNo, IssueDate, TotalAmount
  FROM Invoice PARTITION FOR (DATE '2027-03-15');

-- =====================================================================
-- Test 2: partition pruning on the new data
-- EXPECTED: PARTITION RANGE SINGLE, Pstart = Pstop (one partition)
-- =====================================================================
EXPLAIN PLAN FOR
SELECT InvoiceNo FROM Invoice
 WHERE IssueDate >= DATE '2027-03-01' AND IssueDate < DATE '2027-04-01';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +PREDICATE +PARTITION'));

-- =====================================================================
-- Test 3: moving a row between partitions (ROW MOVEMENT is enabled for
-- interval partitioned tables that were converted ONLINE; if not, ORA-14402)
-- EXPECTED: the update succeeds and the row is found by the new date
-- =====================================================================
UPDATE Invoice SET IssueDate = DATE '2027-05-10' WHERE InvoiceNo = 'T-I-0001';

SELECT InvoiceNo, IssueDate FROM Invoice WHERE InvoiceNo = 'T-I-0001';

-- =====================================================================
-- Test 4: INSERT through the view CustomerFull (trg_customerfull_ins)
-- EXPECTED: one row in Customer and one in CustomerDetails
-- =====================================================================
INSERT INTO CustomerFull (CustomerId, Name, TaxId, Address, Phone, Email, Note, CityId)
VALUES (9001, 'Test Customer', 'T000000001', 'Test Street 1', '+000 555 9001', 'test@example.com',
        'Inserted through the view', 101);

SELECT c.CustomerId, c.Name, d.Address, d.Email
  FROM Customer c JOIN CustomerDetails d ON d.CustomerId = c.CustomerId
 WHERE c.CustomerId = 9001;

-- =====================================================================
-- Test 5: UPDATE through the view (trg_customerfull_upd)
-- EXPECTED: Name changes in Customer, Phone and Note change in CustomerDetails
-- =====================================================================
UPDATE CustomerFull
   SET Name = 'Test Customer Renamed', Phone = '+000 555 0000', Note = 'Updated through the view'
 WHERE CustomerId = 9001;

SELECT CustomerId, Name, Phone, Note FROM CustomerFull WHERE CustomerId = 9001;

-- =====================================================================
-- Test 6: changing the key through the view
-- ERROR ORA-20021 (expected)
-- =====================================================================
UPDATE CustomerFull SET CustomerId = 9002 WHERE CustomerId = 9001;

-- =====================================================================
-- Test 7: DELETE through the view (trg_customerfull_del)
-- EXPECTED: 0 rows in Customer and 0 rows in CustomerDetails
-- =====================================================================
DELETE FROM CustomerFull WHERE CustomerId = 9001;

SELECT (SELECT COUNT(*) FROM Customer        WHERE CustomerId = 9001) AS customer_rows,
       (SELECT COUNT(*) FROM CustomerDetails WHERE CustomerId = 9001) AS details_rows
  FROM dual;

-- =====================================================================
-- End: undo all test changes
-- EXPECTED: no row with InvoiceNo 'T-I-0001'
-- =====================================================================
ROLLBACK;

SELECT COUNT(*) AS test_invoices FROM Invoice WHERE InvoiceNo = 'T-I-0001';
