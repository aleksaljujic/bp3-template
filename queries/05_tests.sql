-- =====================================================================
-- 05_tests.sql
-- Statements that fire the part 2 triggers. Run block by block (or whole).
-- Expected errors are marked "ERROR ORA-200xx (expected)"; SQL*Plus carries on.
-- Ends with ROLLBACK, so the script can be run many times.
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- =====================================================================

-- =====================================================================
-- Test 1, T1, T5: insert an invoice item -> IssueDate is copied from the
-- invoice (2026-01-15) and Amount = 100 * 0.85 * (1 - 10/100) = 76.50
-- =====================================================================
INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct)
VALUES ('I-0001', 3, 'GLUE', 100, 0.85, 10);

SELECT InvoiceNo, ItemNo, IssueDate, Quantity, Price, DiscountPct, Amount
  FROM InvoiceItem
 WHERE InvoiceNo = 'I-0001';

-- =====================================================================
-- Test 2, T2: change Invoice.IssueDate -> all 3 items of I-0001 follow
-- =====================================================================
UPDATE Invoice SET IssueDate = DATE '2026-02-01' WHERE InvoiceNo = 'I-0001';

SELECT InvoiceNo, ItemNo, IssueDate FROM InvoiceItem WHERE InvoiceNo = 'I-0001';

-- =====================================================================
-- Test 3, T1: manual change of IssueDate on an item
-- ERROR ORA-20001 (expected)
-- =====================================================================
UPDATE InvoiceItem SET IssueDate = DATE '2020-01-01' WHERE InvoiceNo = 'I-0001' AND ItemNo = 1;

-- =====================================================================
-- Test 4, T3: insert a new invoice without customer data -> filled through
-- 2 levels (SO-0002 -> Example Customer B)
-- =====================================================================
INSERT INTO Invoice (InvoiceNo, IssueDate, DueDate, OrderNo, CityId, CurrencyCode)
VALUES ('I-0003', DATE '2026-02-10', DATE '2026-03-12', 'SO-0002', 2, 'EUR');

SELECT InvoiceNo, OrderNo, CustomerId, CustomerName FROM Invoice ORDER BY InvoiceNo;

-- =====================================================================
-- Test 5, T3: manual change of the customer name on an invoice
-- ERROR ORA-20002 (expected)
-- =====================================================================
UPDATE Invoice SET CustomerName = 'Some other customer' WHERE InvoiceNo = 'I-0003';

-- =====================================================================
-- Test 6, T3: invoice for a non-existing order
-- ERROR ORA-20003 (expected)
-- =====================================================================
INSERT INTO Invoice (InvoiceNo, IssueDate, DueDate, OrderNo, CityId, CurrencyCode)
VALUES ('I-0004', DATE '2026-02-10', DATE '2026-03-12', 'SO-9999', 2, 'EUR');

-- =====================================================================
-- Test 7, T4: rename a customer -> all its invoices get the new name
-- (the cascade passes the T3 guard thanks to the flag)
-- =====================================================================
UPDATE Customer SET Name = 'Example Customer A (renamed)' WHERE CustomerId = 1;

SELECT c.Name AS name_in_master, i.InvoiceNo, i.CustomerName AS name_on_invoice
  FROM Invoice i JOIN Customer c ON c.CustomerId = i.CustomerId
 ORDER BY i.InvoiceNo;

-- =====================================================================
-- Test 8, T3: move invoice I-0001 to another order (SO-0002)
-- -> customer data switches to Example Customer B
-- =====================================================================
UPDATE Invoice SET OrderNo = 'SO-0002' WHERE InvoiceNo = 'I-0001';

SELECT InvoiceNo, OrderNo, CustomerId, CustomerName FROM Invoice ORDER BY InvoiceNo;

-- =====================================================================
-- Test 9, T5: change quantity -> Amount is recomputed (200 * 3.20 * 0.90 = 576.00)
-- Test 10, T5: manual change of Amount -> trigger restores the right value
-- =====================================================================
UPDATE InvoiceItem SET Quantity = 200, Price = 3.20, DiscountPct = 10
 WHERE InvoiceNo = 'I-0002' AND ItemNo = 1;
UPDATE InvoiceItem SET Amount = 999999 WHERE InvoiceNo = 'I-0002' AND ItemNo = 1;

SELECT InvoiceNo, ItemNo, Quantity, Price, DiscountPct, Amount
  FROM InvoiceItem
 WHERE InvoiceNo = 'I-0002';

-- =====================================================================
-- Test 11, T1, T3: after the cascades the flag is FALSE again, so manual
-- changes are still forbidden.
-- ERROR ORA-20001 (expected), ERROR ORA-20002 (expected)
-- =====================================================================
UPDATE InvoiceItem SET IssueDate = DATE '2020-01-01' WHERE InvoiceNo = 'I-0002' AND ItemNo = 1;
UPDATE Invoice SET CustomerId = 2 WHERE InvoiceNo = 'I-0002';

-- =====================================================================
-- restore the initial state so the tests can be repeated
-- =====================================================================
ROLLBACK;
