-- =====================================================================
-- 09_indexes.sql
-- Physical optimization: three index types (B-tree, bitmap, function-based)
-- with the execution plan BEFORE and AFTER creating each index.
-- =====================================================================
-- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Run after 08_generate_data.sql.
-- The literals in the queries (customer 1137, October 2026) are valid because
-- 08 is deterministic. In the plans AFTER there are no hints: the optimizer
-- chooses the index by itself.
-- =====================================================================

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 200
SET TIMING ON

-- ---------------------------------------------------------------------
-- Dropping the indexes (the script is re-runnable: plan BEFORE is always without them)
-- ORA-01418: index does not exist
-- ---------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'ix_invoice_customer_date' AS name FROM dual UNION ALL
            SELECT 'ix_invoice_currency'             FROM dual UNION ALL
            SELECT 'ix_product_upper_name'           FROM dual) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP INDEX ' || i.name;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE <> -1418 THEN RAISE; END IF;
    END;
  END LOOP;
END;
/

-- fresh statistics, so the plan BEFORE does not use stale data
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'INVOICE', cascade => TRUE);
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRODUCT', cascade => TRUE);
END;
/

-- =====================================================================
-- I1: B-tree, composite index Invoice(CustomerId, IssueDate)
-- Why: a frequent search is the customer statement for a period (invoices of
-- one customer in one month). The equality column (CustomerId) goes first, the
-- range column (IssueDate) second, so the whole condition is one narrow range
-- in the index. CustomerId is also a column without an index of its own, so
-- the index helps joins and lookups by customer too.
-- EXPECTED: BEFORE TABLE ACCESS FULL, AFTER INDEX RANGE SCAN
-- =====================================================================

-- BEFORE
EXPLAIN PLAN FOR
SELECT InvoiceNo, IssueDate, TotalAmount
  FROM Invoice
 WHERE CustomerId = 1137
   AND IssueDate BETWEEN DATE '2026-10-01' AND DATE '2026-10-31';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

CREATE INDEX ix_invoice_customer_date ON Invoice(CustomerId, IssueDate);

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'INVOICE', cascade => TRUE);
END;
/

-- AFTER
EXPLAIN PLAN FOR
SELECT InvoiceNo, IssueDate, TotalAmount
  FROM Invoice
 WHERE CustomerId = 1137
   AND IssueDate BETWEEN DATE '2026-10-01' AND DATE '2026-10-31';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

-- actual result of the query
SELECT InvoiceNo, IssueDate, TotalAmount
  FROM Invoice
 WHERE CustomerId = 1137
   AND IssueDate BETWEEN DATE '2026-10-01' AND DATE '2026-10-31';

-- ---------------------------------------------------------------------
-- I1 bonus: column order matters
-- A query only by date range (without CustomerId) cannot use an INDEX RANGE
-- SCAN over (CustomerId, IssueDate): the dates of one month are scattered over
-- the subtrees of all 200 customers. The optimizer picks another access path.
-- ---------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT InvoiceNo, TotalAmount
  FROM Invoice
 WHERE IssueDate BETWEEN DATE '2026-10-01' AND DATE '2026-10-31';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

-- =====================================================================
-- I2: Bitmap index Invoice(CurrencyCode)
-- Why: low cardinality (2 currencies). A bitmap per value is compact, and
-- COUNT(*) is answered from the bitmap without reading the table.
-- Drawback: DML locks a whole bitmap segment, so a bitmap index is not for
-- tables with many concurrent writes. An invoice rarely changes after it is
-- issued (T6 changes only TotalAmount, which is not indexed).
-- EXPECTED: BEFORE TABLE ACCESS FULL, AFTER BITMAP CONVERSION COUNT /
--           BITMAP INDEX SINGLE VALUE
-- =====================================================================

-- BEFORE
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM Invoice WHERE CurrencyCode = 'USD';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

CREATE BITMAP INDEX ix_invoice_currency ON Invoice(CurrencyCode);

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'INVOICE', cascade => TRUE);
END;
/

-- AFTER
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM Invoice WHERE CurrencyCode = 'USD';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

-- actual result
SELECT COUNT(*) AS usd_invoices FROM Invoice WHERE CurrencyCode = 'USD';

-- =====================================================================
-- I3: Function-based index Product(UPPER(Name))
-- Why: names are entered in mixed case ('PAPER BAG ...' and 'Paper bag ...').
-- A case-insensitive search needs UPPER(Name), and an ordinary index on Name
-- is not used then. LIKE with a fixed prefix gives a range scan.
-- EXPECTED: BEFORE TABLE ACCESS FULL, AFTER INDEX RANGE SCAN
-- =====================================================================

-- BEFORE
EXPLAIN PLAN FOR
SELECT ProductCode, Name
  FROM Product
 WHERE UPPER(Name) LIKE 'PAPER BAG 32X%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

CREATE INDEX ix_product_upper_name ON Product(UPPER(Name));

-- statistics also collect the hidden virtual column UPPER(Name)
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRODUCT', cascade => TRUE);
END;
/

-- AFTER
EXPLAIN PLAN FOR
SELECT ProductCode, Name
  FROM Product
 WHERE UPPER(Name) LIKE 'PAPER BAG 32X%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

-- actual result (first 10)
SELECT ProductCode, Name
  FROM Product
 WHERE UPPER(Name) LIKE 'PAPER BAG 32X%'
 FETCH FIRST 10 ROWS ONLY;

SET TIMING OFF

-- ---------------------------------------------------------------------
-- Overview of the created indexes (I3: FUNCTION-BASED NORMAL)
-- ---------------------------------------------------------------------
COLUMN index_name FORMAT A28
COLUMN table_name FORMAT A12
COLUMN index_type FORMAT A24
SELECT table_name, index_name, index_type, uniqueness, status
  FROM user_indexes
 WHERE table_name IN ('INVOICE', 'PRODUCT')
 ORDER BY table_name, index_name;
