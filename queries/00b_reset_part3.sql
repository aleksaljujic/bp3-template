-- =====================================================================
-- 00b_reset_part3.sql
-- Undoes the logical optimization of part 3 (06_logical_optimization.sql)
-- and brings the schema back to the state after 05_tests.sql.
-- The script is re-runnable: "does not exist" errors are ignored.
-- =====================================================================
-- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Does NOT undo 08-11 (generated data, indexes, partitioning); for those
-- run 00_reset.sql and then 01..05 again.

-- 1. triggers T6 and T7
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_invoiceitem_total';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-4080, -4043) THEN RAISE; END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_invoice_total_guard';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-4080, -4043) THEN RAISE; END IF;
END;
/

-- 2. procedure P1
BEGIN
  EXECUTE IMMEDIATE 'DROP PROCEDURE p_change_incoterms';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-4043) THEN RAISE; END IF;
END;
/

-- 3. column Invoice.TotalAmount
BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE Invoice DROP COLUMN TotalAmount';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-904, -942) THEN RAISE; END IF;
END;
/

-- 4. incoterm constraints (ck_so_incoterm_new remains only if P1 failed in the middle of its DDL)
BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE SalesOrder DROP CONSTRAINT ck_so_incoterm';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-2443, -942) THEN RAISE; END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE SalesOrder DROP CONSTRAINT ck_so_incoterm_new';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-2443, -942) THEN RAISE; END IF;
END;
/

-- 5. table Incoterm (same definition as in 01_tables.sql) and its rows
BEGIN
  EXECUTE IMMEDIATE 'CREATE TABLE Incoterm (
    IncotermCode VARCHAR2(10) CONSTRAINT pk_incoterm PRIMARY KEY,
    Name         VARCHAR2(100)
  )';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-955) THEN RAISE; END IF;   -- table already exists
END;
/

MERGE INTO Incoterm i
USING (SELECT 'EXW' AS IncotermCode, 'Ex Works' AS Name FROM dual
       UNION ALL
       SELECT 'FCA', 'Free Carrier' FROM dual) s
   ON (i.IncotermCode = s.IncotermCode)
 WHEN NOT MATCHED THEN
   INSERT (IncotermCode, Name) VALUES (s.IncotermCode, s.Name);

COMMIT;

-- 6. foreign key back; fails if SalesOrder contains a value other than EXW/FCA
--    (for example a committed DAP)
BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE SalesOrder ADD CONSTRAINT fk_so_incoterm FOREIGN KEY (IncotermCode) REFERENCES Incoterm';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-2264, -2275) THEN RAISE; END IF;   -- constraint already exists
END;
/

-- Package pkg_denorm is NOT dropped: it is defined in 04_triggers.sql and the
-- triggers of part 2 (T2-T5) depend on it.
