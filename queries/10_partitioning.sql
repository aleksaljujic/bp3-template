-- =====================================================================
-- 10_partitioning.sql
-- Physical optimization: horizontal partitioning of Invoice (by month)
-- and vertical split of Customer (rarely used columns -> CustomerDetails).
-- =====================================================================
-- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Run after 09_indexes.sql: the existing indexes on Invoice are converted
-- together with the table.
-- Labels T8, T9 and T10 continue the series T1-T7 from 04 and 06.
-- Re-running: the horizontal part skips the conversion if Invoice is already
-- partitioned; the vertical part is skipped if the split is already done
-- (Customer no longer has the column Address). After 00_reset.sql start from 01.
-- =====================================================================

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 200

COLUMN index_name     FORMAT A28
COLUMN index_type     FORMAT A12
COLUMN partition_name FORMAT A16
COLUMN high_value     FORMAT A85
COLUMN locality       FORMAT A8
COLUMN object_name    FORMAT A28
COLUMN trigger_name   FORMAT A28
COLUMN table_name     FORMAT A22
SET LONG 100

-- ---------------------------------------------------------------------
-- Cleaning leftovers of a previous run
-- 00_reset.sql may not drop CustomerDetails. If the schema is "before the
-- split" again (Customer has the column Address) and CustomerDetails still
-- exists, it is a leftover and is dropped. If the split is already done, the
-- table is NOT touched (it holds the data).
-- ---------------------------------------------------------------------
DECLARE
  l_before  NUMBER;
  l_details NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_before
    FROM user_tab_columns
   WHERE table_name = 'CUSTOMER' AND column_name = 'ADDRESS';
  SELECT COUNT(*) INTO l_details
    FROM user_tables
   WHERE table_name = 'CUSTOMERDETAILS';
  IF l_before = 1 AND l_details = 1 THEN
    EXECUTE IMMEDIATE 'DROP TABLE CustomerDetails PURGE';
    DBMS_OUTPUT.PUT_LINE('Dropped leftover CustomerDetails');
  END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP INDEX ix_invoice_date_loc';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE <> -1418 THEN RAISE; END IF;
END;
/

-- =====================================================================
-- HORIZONTAL PARTITIONING: Invoice by months (interval range)
-- Invoices are almost always queried for a period (month, quarter, year),
-- and old invoices are archived by month. One partition = one month.
-- =====================================================================

-- indexes before the conversion (all non-partitioned)
SELECT index_name, index_type, partitioned
  FROM user_indexes
 WHERE table_name = 'INVOICE'
 ORDER BY index_name;

-- Conversion of the existing table, ONLINE (DML works during the conversion).
-- The initial partition p_before_2024 is empty; for every month from 2024-01
-- Oracle creates a partition by itself (INTERVAL 1 MONTH) as soon as the first
-- row of that month arrives.
--
-- What happens to the indexes (UPDATE INDEXES):
--   pk_invoice (InvoiceNo)         unique, does not contain the partition key
--                                  -> stays GLOBAL non-partitioned
--   ix_invoice_customer_date       not prefixed (leading column is not IssueDate)
--                                  -> stays GLOBAL
--   ix_invoice_currency            a bitmap index on a partitioned table must be
--                                  LOCAL -> becomes LOCAL
-- The FK from InvoiceItem still points to pk_invoice. The triggers stay attached.
DECLARE
  l_partitioned VARCHAR2(3);
BEGIN
  SELECT partitioned INTO l_partitioned FROM user_tables WHERE table_name = 'INVOICE';
  IF l_partitioned = 'NO' THEN
    EXECUTE IMMEDIATE 'ALTER TABLE Invoice MODIFY
      PARTITION BY RANGE (IssueDate) INTERVAL (NUMTOYMINTERVAL(1, ''MONTH''))
      (PARTITION p_before_2024 VALUES LESS THAN (DATE ''2024-01-01''))
      ONLINE UPDATE INDEXES';
  ELSE
    DBMS_OUTPUT.PUT_LINE('Invoice is already partitioned, conversion skipped');
  END IF;
END;
/
-- Without ROW MOVEMENT an UPDATE of IssueDate that moves a row to another
-- partition fails with ORA-14402. The conversion does not enable it, so it is
-- enabled explicitly (re-runnable: enabling it twice is not an error).
ALTER TABLE Invoice ENABLE ROW MOVEMENT;

-- The conversion may mark triggers that modify Invoice as INVALID. Oracle would
-- recompile them on first use; here it is done explicitly, so the final check
-- does not show INVALID.
BEGIN
  FOR t IN (SELECT trigger_name FROM user_triggers WHERE status = 'ENABLED'
               AND table_name IN ('INVOICE', 'INVOICEITEM', 'CUSTOMER')) LOOP
    EXECUTE IMMEDIATE 'ALTER TRIGGER ' || t.trigger_name || ' COMPILE';
  END LOOP;
END;
/

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'INVOICE', granularity => 'ALL', cascade => TRUE);
END;
/

-- partitions (expected 37: P_BEFORE_2024 with 0 rows + 36 months 2024-01..2026-12)
SELECT partition_name, high_value, num_rows
  FROM user_tab_partitions
 WHERE table_name = 'INVOICE'
 ORDER BY partition_position
 FETCH FIRST 5 ROWS ONLY;

SELECT COUNT(*) AS partition_count
  FROM user_tab_partitions
 WHERE table_name = 'INVOICE';

-- indexes after the conversion: global versus local
SELECT i.index_name, i.index_type, i.partitioned, p.locality
  FROM user_indexes i
  LEFT JOIN user_part_indexes p ON p.index_name = i.index_name
 WHERE i.table_name = 'INVOICE'
 ORDER BY i.index_name;

-- ---------------------------------------------------------------------
-- Partition pruning
-- Done BEFORE the local index, to see a clean full scan of one partition.
-- The columns Pstart/Pstop show which partitions are read.
-- ---------------------------------------------------------------------

-- one month -> PARTITION RANGE SINGLE (1 of 37 partitions is read)
EXPLAIN PLAN FOR
SELECT SUM(TotalAmount)
  FROM Invoice
 WHERE IssueDate >= DATE '2026-10-01'
   AND IssueDate <  DATE '2026-11-01';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE +PARTITION'));

-- whole table -> PARTITION RANGE ALL
EXPLAIN PLAN FOR
SELECT SUM(TotalAmount) FROM Invoice;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE +PARTITION'));

-- first quarter of 2026 -> PARTITION RANGE ITERATOR (3 consecutive partitions)
EXPLAIN PLAN FOR
SELECT SUM(TotalAmount)
  FROM Invoice
 WHERE IssueDate >= DATE '2026-01-01'
   AND IssueDate <  DATE '2026-04-01';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE +PARTITION'));

-- a function on the partition key prevents pruning -> PARTITION RANGE ALL
EXPLAIN PLAN FOR
SELECT SUM(TotalAmount)
  FROM Invoice
 WHERE TO_CHAR(IssueDate, 'YYYY-MM') = '2026-10';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE +PARTITION'));

-- ---------------------------------------------------------------------
-- Local index
-- LOCAL index: one index partition per table partition, with the same bounds.
--   Partition maintenance (DROP, TRUNCATE) does not touch the other parts and
--   the index stays USABLE without a rebuild. Suits queries that filter on the
--   partition key (here the date). A new interval partition immediately gets
--   its own index partition.
-- GLOBAL index (pk_invoice, ix_invoice_customer_date): one tree over all
--   partitions. Fast access by key regardless of the date, and the only way
--   to have a unique key that does not contain IssueDate. After DROP/TRUNCATE
--   of a partition it becomes UNUSABLE, unless UPDATE GLOBAL INDEXES is used.
-- ---------------------------------------------------------------------
CREATE INDEX ix_invoice_date_loc ON Invoice(IssueDate) LOCAL;

SELECT COUNT(*) AS index_partitions
  FROM user_ind_partitions
 WHERE index_name = 'IX_INVOICE_DATE_LOC';

SELECT index_name, partition_name, status
  FROM user_ind_partitions
 WHERE index_name = 'IX_INVOICE_DATE_LOC'
 ORDER BY partition_position
 FETCH FIRST 5 ROWS ONLY;

-- ---------------------------------------------------------------------
-- Maintenance: archiving old months (COMMENTED OUT, example only)
--
-- ALTER TABLE Invoice TRUNCATE PARTITION FOR (DATE '2024-01-15') UPDATE GLOBAL INDEXES;
-- ALTER TABLE Invoice DROP     PARTITION FOR (DATE '2024-01-15') UPDATE GLOBAL INDEXES;
--
-- Advantage over DELETE ... WHERE IssueDate < ...: DROP/TRUNCATE is DDL on a
-- whole segment, with no undo/redo per row, and finishes instantly.
-- UPDATE GLOBAL INDEXES keeps the global indexes usable; local indexes lose
-- only their own partition.
--
-- Limitations in this schema:
--  * Invoice is a PARENT (fk_ii_invoice). TRUNCATE/DROP of a parent partition
--    with an enabled FK gives ORA-02266. First delete/archive the items of that
--    month and temporarily disable the FK, or use ALTER TABLE ... EXCHANGE
--    PARTITION into an archive table.
--  * P_BEFORE_2024 is the last range partition below the interval and cannot
--    be dropped (ORA-14758).
-- ---------------------------------------------------------------------

-- =====================================================================
-- VERTICAL SPLIT: Customer -> Customer + CustomerDetails (1:1)
-- Customer keeps the frequently read columns (name, tax id, city) and all key
-- and FK columns used by the rest of the schema. The rarely used columns
-- (Address, Phone, Email, Note up to 4000 characters) move to CustomerDetails.
-- =====================================================================

-- table size before the split
SELECT table_name, num_rows, blocks, avg_row_len
  FROM user_tables
 WHERE table_name = 'CUSTOMER';

-- the split runs only if it has not been done yet
DECLARE
  l_before NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_before
    FROM user_tab_columns
   WHERE table_name = 'CUSTOMER' AND column_name = 'ADDRESS';
  IF l_before = 0 THEN
    DBMS_OUTPUT.PUT_LINE('Customer is already split, vertical part skipped');
    RETURN;
  END IF;

  -- 1. details table: the PK is at the same time an FK -> 1:1 relationship
  EXECUTE IMMEDIATE 'CREATE TABLE CustomerDetails (
    CustomerId NUMBER(10)     CONSTRAINT pk_customerdetails PRIMARY KEY
                              CONSTRAINT fk_cd_customer REFERENCES Customer ON DELETE CASCADE,
    Address    VARCHAR2(200),
    Phone      VARCHAR2(50),
    Email      VARCHAR2(100),
    Note       VARCHAR2(4000)
  )';

  -- 2. copy the data (a row for every customer, so the 1:1 link is complete)
  EXECUTE IMMEDIATE 'INSERT INTO CustomerDetails (CustomerId, Address, Phone, Email, Note)
    SELECT CustomerId, Address, Phone, Email, Note FROM Customer';
  COMMIT;

  -- 3. remove the moved columns from the base table
  EXECUTE IMMEDIATE 'ALTER TABLE Customer DROP (Address, Phone, Email, Note)';

  -- DROP COLUMN does not lower the high-water mark: a full scan would still read
  -- the same number of blocks. MOVE ONLINE compacts the table and keeps indexes usable.
  EXECUTE IMMEDIATE 'ALTER TABLE Customer MOVE ONLINE';
END;
/

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'CUSTOMER',        cascade => TRUE);
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'CUSTOMERDETAILS', cascade => TRUE);
END;
/

-- check: same number of rows
SELECT (SELECT COUNT(*) FROM Customer)        AS customer_rows,
       (SELECT COUNT(*) FROM CustomerDetails) AS details_rows
  FROM dual;

-- size after the split (fewer blocks and a shorter row)
SELECT table_name, num_rows, blocks, avg_row_len
  FROM user_tables
 WHERE table_name IN ('CUSTOMER', 'CUSTOMERDETAILS')
 ORDER BY table_name;

-- 4. view with the original column order from 01_tables.sql
--    LEFT JOIN: a customer without a details row is still visible
CREATE OR REPLACE VIEW CustomerFull AS
SELECT c.CustomerId, c.Name, c.TaxId, d.Address, d.Phone, d.Email, d.Note, c.CityId
  FROM Customer c
  LEFT JOIN CustomerDetails d ON d.CustomerId = c.CustomerId;

-- 5. T8: INSERT through the view writes to both tables
--    Details are always written (even if all columns are NULL), so the link stays 1:1.
CREATE OR REPLACE TRIGGER trg_customerfull_ins
INSTEAD OF INSERT ON CustomerFull
FOR EACH ROW
BEGIN
  INSERT INTO Customer (CustomerId, Name, TaxId, CityId)
  VALUES (:NEW.CustomerId, :NEW.Name, :NEW.TaxId, :NEW.CityId);

  INSERT INTO CustomerDetails (CustomerId, Address, Phone, Email, Note)
  VALUES (:NEW.CustomerId, :NEW.Address, :NEW.Phone, :NEW.Email, :NEW.Note);
END;
/

-- 6. T9: UPDATE through the view changes both tables
--    CustomerId is not changed (it is the key of both tables). If the customer
--    has no details row, MERGE creates it.
CREATE OR REPLACE TRIGGER trg_customerfull_upd
INSTEAD OF UPDATE ON CustomerFull
FOR EACH ROW
BEGIN
  IF :NEW.CustomerId <> :OLD.CustomerId THEN
    RAISE_APPLICATION_ERROR(-20021, 'CustomerId cannot be changed');
  END IF;

  UPDATE Customer
     SET Name   = :NEW.Name,
         TaxId  = :NEW.TaxId,
         CityId = :NEW.CityId
   WHERE CustomerId = :OLD.CustomerId;

  MERGE INTO CustomerDetails d
  USING (SELECT :OLD.CustomerId AS CustomerId FROM dual) s
     ON (d.CustomerId = s.CustomerId)
   WHEN MATCHED THEN UPDATE SET
         d.Address = :NEW.Address,
         d.Phone   = :NEW.Phone,
         d.Email   = :NEW.Email,
         d.Note    = :NEW.Note
   WHEN NOT MATCHED THEN INSERT
        (CustomerId, Address, Phone, Email, Note)
        VALUES
        (s.CustomerId, :NEW.Address, :NEW.Phone, :NEW.Email, :NEW.Note);
END;
/

-- 7. T10: DELETE through the view removes the customer
--    The details row is removed by ON DELETE CASCADE (fk_cd_customer).
CREATE OR REPLACE TRIGGER trg_customerfull_del
INSTEAD OF DELETE ON CustomerFull
FOR EACH ROW
BEGIN
  DELETE FROM Customer WHERE CustomerId = :OLD.CustomerId;
END;
/

-- ---------------------------------------------------------------------
-- Check that nothing from parts 1-3 broke
-- EXPECTED: no INVALID objects, all triggers ENABLED
-- ---------------------------------------------------------------------
DESC Customer
DESC CustomerDetails

SELECT object_name, object_type, status
  FROM user_objects
 WHERE status <> 'VALID'
    OR object_name IN ('CUSTOMERFULL', 'TRG_CUSTOMERFULL_INS', 'TRG_CUSTOMERFULL_UPD', 'TRG_CUSTOMERFULL_DEL')
 ORDER BY object_name;

SELECT trigger_name, table_name, trigger_type, status
  FROM user_triggers
 ORDER BY table_name, trigger_name;
