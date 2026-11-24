-- =====================================================================
-- 07_test_logical.sql
-- Tests of part 3 (logical optimization): Invoice.TotalAmount and ck_so_incoterm.
-- Run after 06_logical_optimization.sql, in order, block by block.
-- After step 6 there is a ROLLBACK (P1 does DDL, and DDL implicitly COMMITs),
-- and at the end there is a ROLLBACK + restoring the constraint to EXW, FCA.
-- =====================================================================
-- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- The test rows use item numbers 90+ and order numbers 'T-%', so they do not
-- collide with the rows from 02_data.sql.
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 200

-- =====================================================================
-- Step 1: initial state -> TotalAmount equals the sum of the items
-- EXPECTED: the two last columns are equal for every invoice (diff = 0)
-- =====================================================================
SELECT i.InvoiceNo, i.TotalAmount,
       (SELECT NVL(SUM(x.Amount), 0) FROM InvoiceItem x WHERE x.InvoiceNo = i.InvoiceNo) AS items_sum,
       i.TotalAmount - (SELECT NVL(SUM(x.Amount), 0) FROM InvoiceItem x WHERE x.InvoiceNo = i.InvoiceNo) AS diff
  FROM Invoice i
 ORDER BY i.InvoiceNo;

-- =====================================================================
-- Step 2: T6 (trg_invoiceitem_total), INSERT of an item
-- Item 90: 1000 * 0.06 * (1 - 5/100) = 57.00
-- EXPECTED: TotalAmount of I-0001 grows by 57.00 and equals items_sum
-- =====================================================================
INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct)
VALUES ('I-0001', 90, (SELECT MIN(ProductCode) FROM Product), 1000, 0.06, 5);

SELECT i.InvoiceNo, i.TotalAmount,
       (SELECT NVL(SUM(x.Amount), 0) FROM InvoiceItem x WHERE x.InvoiceNo = i.InvoiceNo) AS items_sum
  FROM Invoice i
 WHERE i.InvoiceNo = 'I-0001';

-- =====================================================================
-- Step 3: T6, UPDATE of quantity -> Amount of item 90 becomes 114.00
-- EXPECTED: TotalAmount of I-0001 = initial value + 114.00
-- =====================================================================
UPDATE InvoiceItem SET Quantity = 2000 WHERE InvoiceNo = 'I-0001' AND ItemNo = 90;

SELECT i.InvoiceNo, i.TotalAmount,
       (SELECT NVL(SUM(x.Amount), 0) FROM InvoiceItem x WHERE x.InvoiceNo = i.InvoiceNo) AS items_sum
  FROM Invoice i
 WHERE i.InvoiceNo = 'I-0001';

-- =====================================================================
-- Step 4: T6, DELETE of the item
-- EXPECTED: TotalAmount of I-0001 = initial value
-- =====================================================================
DELETE FROM InvoiceItem WHERE InvoiceNo = 'I-0001' AND ItemNo = 90;

SELECT i.InvoiceNo, i.TotalAmount,
       (SELECT NVL(SUM(x.Amount), 0) FROM InvoiceItem x WHERE x.InvoiceNo = i.InvoiceNo) AS items_sum
  FROM Invoice i
 WHERE i.InvoiceNo = 'I-0001';

-- =====================================================================
-- Step 5: T6, one UPDATE that changes several items of the same invoice
-- Preparation: item 90 (1000 * 0.06, discount 5%) and item 91 (500 * 0.10, discount 0%)
-- =====================================================================
INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct)
VALUES ('I-0001', 90, (SELECT MIN(ProductCode) FROM Product), 1000, 0.06, 5);

INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct)
VALUES ('I-0001', 91, (SELECT MIN(ProductCode) FROM Product), 500, 0.10, 0);

-- One UPDATE over all items of I-0001 -> one recomputation in AFTER STATEMENT
-- EXPECTED: TotalAmount equals items_sum (all items now have a 10% discount)
UPDATE InvoiceItem SET DiscountPct = 10 WHERE InvoiceNo = 'I-0001';

SELECT i.InvoiceNo, i.TotalAmount,
       (SELECT NVL(SUM(x.Amount), 0) FROM InvoiceItem x WHERE x.InvoiceNo = i.InvoiceNo) AS items_sum
  FROM Invoice i
 WHERE i.InvoiceNo = 'I-0001';

-- =====================================================================
-- Step 5b: T6, moving an item to another invoice -> both are recomputed
-- EXPECTED: item 91 (450.00 after 10% discount) moves from I-0001 to I-0002;
-- both invoices have TotalAmount = items_sum
-- =====================================================================
UPDATE InvoiceItem SET InvoiceNo = 'I-0002' WHERE InvoiceNo = 'I-0001' AND ItemNo = 91;

SELECT i.InvoiceNo, i.TotalAmount,
       (SELECT NVL(SUM(x.Amount), 0) FROM InvoiceItem x WHERE x.InvoiceNo = i.InvoiceNo) AS items_sum
  FROM Invoice i
 ORDER BY i.InvoiceNo;

-- =====================================================================
-- Step 6: T7 (trg_invoice_total_guard), manual change of TotalAmount
-- ERROR ORA-20010 (expected)
-- =====================================================================
UPDATE Invoice SET TotalAmount = 1 WHERE InvoiceNo = 'I-0001';

SELECT InvoiceNo, TotalAmount FROM Invoice WHERE InvoiceNo = 'I-0001';

-- =====================================================================
-- ROLLBACK of the technique 1 changes.
-- The next steps call p_change_incoterms, whose DDL does an implicit COMMIT,
-- so the changes from steps 2-6 are undone now (state as after 06).
-- =====================================================================
ROLLBACK;

-- =====================================================================
-- Step 7: ck_so_incoterm, an order with a value that is not allowed
-- ERROR ORA-02290 (expected)
-- =====================================================================
INSERT INTO SalesOrder (OrderNo, OrderDate, CustomerId, IncotermCode)
VALUES ('T-9001', DATE '2026-11-10', (SELECT MIN(CustomerId) FROM Customer), 'DAP');

-- =====================================================================
-- Step 8: P1 p_change_incoterms, TRIM and UPPER over the list ('EXW, fca ,DAP')
-- EXPECTED: output IncotermCode IN ('EXW','FCA','DAP'), then the INSERT succeeds
-- =====================================================================
EXEC p_change_incoterms('EXW, fca ,DAP');

INSERT INTO SalesOrder (OrderNo, OrderDate, CustomerId, IncotermCode)
VALUES ('T-9001', DATE '2026-11-10', (SELECT MIN(CustomerId) FROM Customer), 'DAP');

SELECT OrderNo, IncotermCode FROM SalesOrder ORDER BY OrderNo;

-- =====================================================================
-- Step 9: P1, removing a value that is in use
-- Preparation: an order with FCA
-- =====================================================================
INSERT INTO SalesOrder (OrderNo, OrderDate, CustomerId, IncotermCode)
VALUES ('T-9002', DATE '2026-11-10', (SELECT MIN(CustomerId) FROM Customer), 'FCA');

-- P1: removing DAP and FCA while they are in use
-- ERROR ORA-20011 (expected), the message lists DAP and FCA
EXEC p_change_incoterms('EXW');

-- =====================================================================
-- Step 9b: P1, invalid format (SQL injection attempt)
-- ERROR ORA-20012 (expected), no DDL is executed
-- =====================================================================
EXEC p_change_incoterms('EXW,FCA'') OR (1=1');

-- =====================================================================
-- Step 10: comparing queries before and after the optimization
-- =====================================================================
-- BEFORE: join with the lookup table and aggregation on every read
-- SELECT o.OrderNo, o.IncotermCode, t.Name
--   FROM SalesOrder o LEFT JOIN Incoterm t ON t.IncotermCode = o.IncotermCode;
-- SELECT i.InvoiceNo, i.IssueDate, NVL(SUM(x.Amount), 0) AS TotalAmount
--   FROM Invoice i LEFT JOIN InvoiceItem x ON x.InvoiceNo = i.InvoiceNo
--  GROUP BY i.InvoiceNo, i.IssueDate;
-- AFTER: reading a single table
SELECT OrderNo, IncotermCode FROM SalesOrder;
SELECT InvoiceNo, IssueDate, TotalAmount FROM Invoice;

-- =====================================================================
-- End: restoring the database to the initial state
-- The order is mandatory: ROLLBACK removes the orders from steps 8 and 9 first,
-- only then P1 restores the constraint, otherwise the validation would see
-- the uncommitted DAP and raise ORA-20011.
-- EXPECTED: IncotermCode IN ('EXW','FCA')
-- =====================================================================
ROLLBACK;

EXEC p_change_incoterms('EXW,FCA');

SELECT constraint_name, search_condition_vc
  FROM user_constraints
 WHERE constraint_name = 'CK_SO_INCOTERM';
