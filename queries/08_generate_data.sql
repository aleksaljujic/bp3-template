-- =====================================================================
-- 08_generate_data.sql
-- Bulk data load for the index and partitioning demonstrations.
-- =====================================================================
-- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Generation is deterministic: ORA_HASH(n, max, seed) instead of DBMS_RANDOM,
-- so the data is the same on every run and the literals used in 09 always
-- give the same plan. New text keys have the prefix 'G-'; numeric keys use a
-- separate range (City 101+, Customer 1001+), so nothing collides with 02_data.sql.
-- Triggers T1-T7 are NOT disabled: they fill the redundant and derived
-- columns (IssueDate, customer, Amount, TotalAmount).
-- Volumes: 200 customers, 1000 products, 5000 sales orders, 50000 invoices,
-- ~100000 invoice items. Run after 07_test_logical.sql.
-- =====================================================================

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 200
SET TIMING ON

-- ---------------------------------------------------------------------
-- Protection against running twice; any error in the load stops the script
-- (WHENEVER SQLERROR), so it does not continue with partial data
-- ---------------------------------------------------------------------
WHENEVER SQLERROR EXIT SQL.SQLCODE

DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_count FROM Invoice WHERE InvoiceNo LIKE 'G-%';
  IF l_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20020,
      'Data is already generated, run 00_reset ... 07 and then 08 again');
  END IF;
END;
/

-- ---------------------------------------------------------------------
-- Lookups: 1 country, 20 cities (101..120) and 200 customers (1001..1200)
-- ---------------------------------------------------------------------
INSERT INTO Country (CountryCode, Name) VALUES ('GEN', 'Generated Country');

INSERT INTO City (CityId, Name, CountryCode)
SELECT 100 + LEVEL, 'City G-' || LPAD(LEVEL, 2, '0'), 'GEN'
  FROM dual CONNECT BY LEVEL <= 20;

INSERT INTO Customer (CustomerId, Name, TaxId, Address, Phone, Email, Note, CityId)
SELECT 1000 + LEVEL,
       'Customer G-' || LPAD(LEVEL, 3, '0') || ' Ltd',
       'G' || LPAD(LEVEL, 9, '0'),
       'Street ' || LEVEL,
       '+000 555 ' || LPAD(LEVEL, 4, '0'),
       'customer' || LEVEL || '@example.com',
       CASE MOD(LEVEL, 4) WHEN 0 THEN 'Generated customer ' || LEVEL || ', delivery by appointment only' END,
       101 + ORA_HASH(LEVEL, 19, 1)
  FROM dual CONNECT BY LEVEL <= 200;

-- ---------------------------------------------------------------------
-- Product: 1000 products, 4 families of 250, in consecutive blocks.
-- Inside a family the size w grows in blocks of ~9 products, so products with
-- the same prefix lie physically next to each other (small clustering factor for I3).
-- Families 1 and 3 are entered in mixed/lower case -> a search needs UPPER(Name).
-- ---------------------------------------------------------------------
INSERT INTO Product (ProductCode, Name, UnitCode)
SELECT 'G-P-' || LPAD(n, 5, '0'),
       CASE f
         WHEN 0 THEN 'PAPER BAG ' || w || 'X' || d || '/' || h || ' ' || color
         WHEN 1 THEN 'Paper bag ' || w || 'x' || d || '/' || h || ' ' || LOWER(color)
         WHEN 2 THEN 'BOX CARDBOARD ' || w || 'X' || d || ' ' || color
         ELSE        'Box plastic ' || w || 'x' || d || ' ' || LOWER(color)
       END,
       (SELECT MIN(UnitCode) FROM Unit)
  FROM (SELECT LEVEL                                AS n,
               TRUNC((LEVEL - 1) / 250)             AS f,
               18 + TRUNC(MOD(LEVEL - 1, 250) / 9)  AS w,
               20 + MOD(LEVEL, 20)                  AS d,
               30 + MOD(LEVEL, 15)                  AS h,
               CASE MOD(LEVEL, 4) WHEN 0 THEN 'BROWN' WHEN 1 THEN 'WHITE'
                                  WHEN 2 THEN 'GREEN' ELSE 'BLACK' END AS color
          FROM dual CONNECT BY LEVEL <= 1000)
 ORDER BY n;

COMMIT;

-- ---------------------------------------------------------------------
-- SalesOrder: 5000 orders; IncotermCode respects ck_so_incoterm from 06:
-- EXW, FCA or NULL
-- ---------------------------------------------------------------------
INSERT INTO SalesOrder (OrderNo, OrderDate, CustomerId, IncotermCode)
SELECT 'G-SO-' || LPAD(i, 5, '0'),
       DATE '2023-12-01' + ORA_HASH(i, 1064, 10),
       1001 + ORA_HASH(i, 199, 2),
       CASE MOD(i, 3) WHEN 0 THEN 'EXW' WHEN 1 THEN 'FCA' END
  FROM (SELECT LEVEL AS i FROM dual CONNECT BY LEVEL <= 5000);

-- OrderItem: 2 items per order = 10000
INSERT INTO OrderItem (OrderNo, ItemNo, ProductCode, Quantity, Price)
SELECT 'G-SO-' || LPAD(i, 5, '0'), rb,
       'G-P-' || LPAD(1 + ORA_HASH(i * 10 + rb, 999, 3), 5, '0'),
       10 + ORA_HASH(i * 10 + rb, 490, 14),
       0.5 + ORA_HASH(i * 10 + rb, 500, 15) / 100
  FROM (SELECT LEVEL AS i FROM dual CONNECT BY LEVEL <= 5000)
 CROSS JOIN (SELECT LEVEL AS rb FROM dual CONNECT BY LEVEL <= 2);

COMMIT;

-- ---------------------------------------------------------------------
-- Invoice (50000) and InvoiceItem (~100000) in 10 batches of 5000 invoices
-- Invoice:     fires T3 (customer through 2 levels), T7 (TotalAmount := 0)
-- InvoiceItem: fires T1 (IssueDate), T5 (Amount),
--              T6 (in AFTER STATEMENT recomputes TotalAmount of each invoice)
-- Batches keep the array size in T6 and the undo within bounds; COMMIT after each.
-- Date: 2024-01-01 + 0..1095 days (up to 2026-12-31); currency ~70% EUR, ~30% USD.
-- Items per invoice: 1 + MOD(m, 3), i.e. 1-3.
-- ---------------------------------------------------------------------
BEGIN
  FOR b IN 0 .. 9 LOOP
    INSERT INTO Invoice (InvoiceNo, IssueDate, DueDate, OrderNo, CityId, CurrencyCode)
    SELECT 'G-I-' || LPAD(m, 6, '0'),
           dat, dat + 30,
           'G-SO-' || LPAD(MOD(m - 1, 5000) + 1, 5, '0'),
           101 + ORA_HASH(m, 19, 6),
           val
      FROM (SELECT m,
                   DATE '2024-01-01' + ORA_HASH(m, 1095, 4) AS dat,
                   CASE WHEN ORA_HASH(m, 9, 5) < 7 THEN 'EUR' ELSE 'USD' END AS val
              FROM (SELECT b * 5000 + LEVEL AS m FROM dual CONNECT BY LEVEL <= 5000));

    INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct)
    SELECT 'G-I-' || LPAD(m, 6, '0'), rb,
           'G-P-' || LPAD(1 + ORA_HASH(m * 10 + rb, 999, 17), 5, '0'),
           10 + ORA_HASH(m * 10 + rb, 490, 18),
           0.5 + ORA_HASH(m * 10 + rb, 500, 19) / 100,
           CASE ORA_HASH(m * 10 + rb, 2, 20) WHEN 0 THEN 0 WHEN 1 THEN 5 ELSE 10 END
      FROM (SELECT b * 5000 + LEVEL AS m FROM dual CONNECT BY LEVEL <= 5000)
     CROSS JOIN (SELECT LEVEL AS rb FROM dual CONNECT BY LEVEL <= 3)
     WHERE rb <= 1 + MOD(m, 3);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Batch ' || (b + 1) || '/10 done');
  END LOOP;
END;
/

WHENEVER SQLERROR CONTINUE

-- ---------------------------------------------------------------------
-- Statistics for the whole schema (no GRANT needed for your own schema)
-- ---------------------------------------------------------------------
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(USER);
END;
/

SET TIMING OFF

-- ---------------------------------------------------------------------
-- Row counts of all tables
-- ---------------------------------------------------------------------
SELECT 'Country' AS table_name, COUNT(*) AS row_count FROM Country
UNION ALL SELECT 'City', COUNT(*) FROM City
UNION ALL SELECT 'Customer', COUNT(*) FROM Customer
UNION ALL SELECT 'Unit', COUNT(*) FROM Unit
UNION ALL SELECT 'Product', COUNT(*) FROM Product
UNION ALL SELECT 'Currency', COUNT(*) FROM Currency
UNION ALL SELECT 'SalesOrder', COUNT(*) FROM SalesOrder
UNION ALL SELECT 'OrderItem', COUNT(*) FROM OrderItem
UNION ALL SELECT 'Invoice', COUNT(*) FROM Invoice
UNION ALL SELECT 'InvoiceItem', COUNT(*) FROM InvoiceItem;

-- ---------------------------------------------------------------------
-- Trigger check
-- EXPECTED: all three values 0
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS wrong_total_amount
  FROM Invoice i
 WHERE i.TotalAmount <> (SELECT NVL(SUM(x.Amount), 0)
                           FROM InvoiceItem x
                          WHERE x.InvoiceNo = i.InvoiceNo);

SELECT COUNT(*) AS invoice_without_customer
  FROM Invoice
 WHERE CustomerId IS NULL;

SELECT COUNT(*) AS item_with_wrong_date
  FROM InvoiceItem x
  JOIN Invoice i ON i.InvoiceNo = x.InvoiceNo
 WHERE x.IssueDate <> i.IssueDate;

-- currency distribution (expected ~70% EUR, ~30% USD)
SELECT CurrencyCode, COUNT(*) AS row_count,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS percent
  FROM Invoice
 GROUP BY CurrencyCode
 ORDER BY CurrencyCode;
