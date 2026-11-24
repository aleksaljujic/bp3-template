-- =====================================================================
-- 06_logical_optimization.sql
-- Logical optimization: storing the derived value Invoice.TotalAmount
-- and removing the lookup table Incoterm (hard-coded values).
-- =====================================================================
-- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- The order in this script matters:
--   package -> column -> initial fill -> T6 -> T7 -> Incoterm -> P1
-- Labels T6 and T7 continue the series T1-T5 from 04_triggers.sql.
-- =====================================================================

SET SERVEROUTPUT ON

-- ---------------------------------------------------------------------
-- Package pkg_denorm: shared flag for triggers that maintain redundant
-- and derived values (spec only, no body; the variable is per session).
-- Defined in 04_triggers.sql; repeated here so the script also works alone.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_denorm AS
  g_cascade BOOLEAN := FALSE;
END pkg_denorm;
/

-- ---------------------------------------------------------------------
-- Technique 1: storing a derived value
-- TotalAmount(InvoiceNo) = SUM(InvoiceItem.Amount); Amount is maintained by T5
-- ---------------------------------------------------------------------
ALTER TABLE Invoice ADD TotalAmount NUMBER(16,2) DEFAULT 0 NOT NULL;

-- initial fill BEFORE T7 exists, so the flag pkg_denorm.g_cascade is not needed
UPDATE Invoice i
   SET TotalAmount = (SELECT NVL(SUM(x.Amount), 0)
                        FROM InvoiceItem x
                       WHERE x.InvoiceNo = i.InvoiceNo);

COMMIT;

-- T6: every change of invoice items recomputes TotalAmount of the affected invoices
--
-- Why a COMPOUND trigger: an ordinary row trigger on InvoiceItem that reads
-- InvoiceItem (SUM) would fail with ORA-04091 (mutating table). So AFTER EACH ROW
-- only collects invoice numbers, and the summing is done in AFTER STATEMENT,
-- where reading the table is allowed. Also, one statement that changes N items
-- of the same invoice does one UPDATE of the invoice instead of N.
CREATE OR REPLACE TRIGGER trg_invoiceitem_total
FOR INSERT OR UPDATE OF Quantity, Price, DiscountPct, InvoiceNo OR DELETE ON InvoiceItem
COMPOUND TRIGGER

  -- key = InvoiceNo; the associative array removes duplicates by itself
  TYPE t_invoices IS TABLE OF BOOLEAN INDEX BY VARCHAR2(20);
  g_invoices t_invoices;

  AFTER EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      g_invoices(:NEW.InvoiceNo) := TRUE;
    END IF;
    IF DELETING THEN
      g_invoices(:OLD.InvoiceNo) := TRUE;
    END IF;
    -- item moved to another invoice: both invoices are recomputed
    IF UPDATING('InvoiceNo') AND :OLD.InvoiceNo <> :NEW.InvoiceNo THEN
      g_invoices(:OLD.InvoiceNo) := TRUE;
    END IF;
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    l_saved BOOLEAN;
    l_key   VARCHAR2(20);
  BEGIN
    l_saved := pkg_denorm.g_cascade;
    pkg_denorm.g_cascade := TRUE;   -- T7 allows the change only while the flag is up

    l_key := g_invoices.FIRST;
    WHILE l_key IS NOT NULL LOOP
      UPDATE Invoice
         SET TotalAmount = (SELECT NVL(SUM(x.Amount), 0)
                              FROM InvoiceItem x
                             WHERE x.InvoiceNo = l_key)
       WHERE InvoiceNo = l_key;
      l_key := g_invoices.NEXT(l_key);
    END LOOP;

    g_invoices.DELETE;
    pkg_denorm.g_cascade := l_saved;
  EXCEPTION
    WHEN OTHERS THEN
      pkg_denorm.g_cascade := l_saved;
      RAISE;
  END AFTER STATEMENT;

END trg_invoiceitem_total;
/

-- T7: TotalAmount is not changed manually, except when T6 maintains it (flag g_cascade)
--      INSERT: a new invoice has no items, so the correct value is 0; whatever
--      the user supplied is silently replaced by zero (no error, so bulk loads work)
CREATE OR REPLACE TRIGGER trg_invoice_total_guard
BEFORE INSERT OR UPDATE OF TotalAmount ON Invoice
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    :NEW.TotalAmount := 0;
  ELSIF NOT pkg_denorm.g_cascade THEN
    RAISE_APPLICATION_ERROR(-20010,
      'Invoice total cannot be changed manually, it is computed from the items');
  END IF;
END;
/

-- ---------------------------------------------------------------------
-- Interaction with the existing triggers
-- ---------------------------------------------------------------------
-- * T6 -> UPDATE Invoice.TotalAmount fires only T7. The part 2 triggers on
--   Invoice are declared OF specific columns (IssueDate; OrderNo, CustomerId,
--   CustomerName), so they do not fire on UPDATE OF TotalAmount. No trigger on
--   Invoice reads InvoiceItem in this chain, so no ORA-04091 and no recursion.
-- * Order on InvoiceItem: BEFORE ROW (T1, T5) sets IssueDate and Amount, then
--   AFTER ROW (T6 collects keys), then AFTER STATEMENT (T6 sums the Amount
--   values that T5 has already set).

-- ---------------------------------------------------------------------
-- Technique 2: hard-coded values, removing the table Incoterm
-- ---------------------------------------------------------------------
-- Values before removal (for documentation):
--   INCOTERMCODE  NAME
--   EXW           Ex Works
--   FCA           Free Carrier
-- The Name column is lost: the description moves to documentation and to a column comment.
SELECT IncotermCode, Name FROM Incoterm ORDER BY IncotermCode;

ALTER TABLE SalesOrder DROP CONSTRAINT fk_so_incoterm;

-- no PURGE, so the table stays in the recycle bin
DROP TABLE Incoterm;

-- NULL still passes (the column is optional, same behaviour as with the FK)
ALTER TABLE SalesOrder ADD CONSTRAINT ck_so_incoterm
  CHECK (IncotermCode IN ('EXW','FCA'));

COMMENT ON COLUMN SalesOrder.IncotermCode IS 'EXW = Ex Works, FCA = Free Carrier';

-- P1: changes the list of allowed incoterms (ck_so_incoterm)
-- Example call: EXEC p_change_incoterms('EXW, fca, DAP');
-- NOTE: every DDL statement implicitly COMMITs the caller's transaction.
-- Errors -20011 and -20012 happen before any DDL, so then nothing is committed.
-- Dynamic SQL is safe because every value must match ^[A-Z0-9]{1,10}$
-- (a quote character cannot get into the statement).
CREATE OR REPLACE PROCEDURE p_change_incoterms(p_list IN VARCHAR2)
IS
  l_list   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
  l_v      VARCHAR2(4000);
  l_exists BOOLEAN;
  l_cond   VARCHAR2(4000);
  l_in_use VARCHAR2(4000);
  l_text   VARCHAR2(4000);
BEGIN
  -- parsing: split by comma, UPPER(TRIM()), skip empty values, drop duplicates
  FOR i IN 1 .. NVL(REGEXP_COUNT(p_list, '[^,]+'), 0) LOOP
    l_v := UPPER(TRIM(REGEXP_SUBSTR(p_list, '[^,]+', 1, i)));
    IF l_v IS NOT NULL THEN
      l_exists := FALSE;
      FOR j IN 1 .. l_list.COUNT LOOP
        IF l_list(j) = l_v THEN
          l_exists := TRUE;
        END IF;
      END LOOP;
      IF NOT l_exists THEN
        l_list.EXTEND;
        l_list(l_list.COUNT) := l_v;
      END IF;
    END IF;
  END LOOP;

  IF l_list.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20012, 'Invalid incoterm code: the list is empty');
  END IF;

  -- format validation (injection guard)
  FOR j IN 1 .. l_list.COUNT LOOP
    IF NOT REGEXP_LIKE(l_list(j), '^[A-Z0-9]{1,10}$') THEN
      RAISE_APPLICATION_ERROR(-20012, 'Invalid incoterm code: ' || l_list(j));
    END IF;
  END LOOP;

  -- usage validation: a value used by some order must not be removed
  SELECT LISTAGG(DISTINCT IncotermCode, ', ')
    INTO l_in_use
    FROM SalesOrder
   WHERE IncotermCode IS NOT NULL
     AND IncotermCode NOT IN (SELECT column_value FROM TABLE(l_list));
  IF l_in_use IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20011,
      'Incoterm is used by sales orders and cannot be removed: ' || l_in_use);
  END IF;

  -- build the condition: IncotermCode IN ('EXW','FCA',...)
  FOR j IN 1 .. l_list.COUNT LOOP
    l_cond := l_cond || CASE WHEN j > 1 THEN ',' END || '''' || l_list(j) || '''';
  END LOOP;
  l_cond := 'IncotermCode IN (' || l_cond || ')';

  -- DDL: the table is never left without a constraint;
  -- if the first step fails, the old constraint stays untouched
  EXECUTE IMMEDIATE 'ALTER TABLE SalesOrder ADD CONSTRAINT ck_so_incoterm_new CHECK (' || l_cond || ')';
  EXECUTE IMMEDIATE 'ALTER TABLE SalesOrder DROP CONSTRAINT ck_so_incoterm';
  EXECUTE IMMEDIATE 'ALTER TABLE SalesOrder RENAME CONSTRAINT ck_so_incoterm_new TO ck_so_incoterm';

  SELECT search_condition_vc
    INTO l_text
    FROM user_constraints
   WHERE constraint_name = 'CK_SO_INCOTERM';
  DBMS_OUTPUT.PUT_LINE('ck_so_incoterm: ' || l_text);
END p_change_incoterms;
/

-- ---------------------------------------------------------------------
-- Check that everything compiled (STATUS = VALID)
-- ---------------------------------------------------------------------
SELECT trigger_name, table_name, status
  FROM user_triggers
 ORDER BY table_name, trigger_name;

SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('PKG_DENORM', 'P_CHANGE_INCOTERMS')
 ORDER BY object_name, object_type;
