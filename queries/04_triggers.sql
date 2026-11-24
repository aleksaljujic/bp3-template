-- =====================================================================
-- 04_triggers.sql
-- Part 2: triggers that keep the redundant columns consistent.
-- D1 (2NF): T1, T2   D2 (3NF, 2 levels): T3, T4   D3 (3NF): T5
-- Error codes of this part: -20001 .. -20009
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Re-runnable (CREATE OR REPLACE).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Package with a flag: TRUE while a cascading trigger changes the copies.
-- The "forbid manual change" triggers let the change through in that case
-- (the variable is per session).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_denorm AS
  g_cascade BOOLEAN := FALSE;
END pkg_denorm;
/

-- ---------------------------------------------------------------------
-- D1 (2NF) InvoiceItem.IssueDate
-- ---------------------------------------------------------------------

-- T1: on insert (or when the invoice changes) copies Invoice.IssueDate;
--     a manual change of IssueDate alone is forbidden.
--     While cascading (T2) the value is already set, so the trigger returns
--     early (also avoids reading the Invoice table that is being updated).
CREATE OR REPLACE TRIGGER trg_invoiceitem_date
BEFORE INSERT OR UPDATE OF InvoiceNo, IssueDate ON InvoiceItem
FOR EACH ROW
BEGIN
  IF pkg_denorm.g_cascade THEN
    RETURN;
  END IF;

  IF UPDATING AND NOT UPDATING('InvoiceNo') THEN
    RAISE_APPLICATION_ERROR(-20001,
      'IssueDate of an invoice item cannot be changed manually; change it on Invoice');
  END IF;

  SELECT i.IssueDate
    INTO :NEW.IssueDate
    FROM Invoice i
   WHERE i.InvoiceNo = :NEW.InvoiceNo;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;  -- missing invoice: the foreign key reports the error
END;
/

-- T2: a changed Invoice.IssueDate is cascaded to all items of that invoice
CREATE OR REPLACE TRIGGER trg_invoice_date_items
AFTER UPDATE OF IssueDate ON Invoice
FOR EACH ROW
DECLARE
  l_old BOOLEAN := pkg_denorm.g_cascade;
BEGIN
  pkg_denorm.g_cascade := TRUE;
  UPDATE InvoiceItem
     SET IssueDate = :NEW.IssueDate
   WHERE InvoiceNo = :NEW.InvoiceNo;
  pkg_denorm.g_cascade := l_old;
EXCEPTION
  WHEN OTHERS THEN
    pkg_denorm.g_cascade := l_old;
    RAISE;
END;
/

-- ---------------------------------------------------------------------
-- D2 (3NF, 2 levels) Invoice.CustomerId, Invoice.CustomerName
-- Invoice -> SalesOrder -> Customer
-- ---------------------------------------------------------------------

-- T3: on insert (or when the order changes) fills the customer data;
--     a manual change of the copied columns is forbidden.
--     Under cascade (T4) the value is supplied by the cascading trigger.
CREATE OR REPLACE TRIGGER trg_invoice_customer
BEFORE INSERT OR UPDATE OF OrderNo, CustomerId, CustomerName ON Invoice
FOR EACH ROW
BEGIN
  IF pkg_denorm.g_cascade THEN
    RETURN;
  END IF;

  IF UPDATING AND NOT UPDATING('OrderNo') THEN
    RAISE_APPLICATION_ERROR(-20002,
      'Customer data on an invoice cannot be changed manually; change the order or the customer');
  END IF;

  SELECT c.CustomerId, c.Name
    INTO :NEW.CustomerId, :NEW.CustomerName
    FROM SalesOrder so
    JOIN Customer c ON c.CustomerId = so.CustomerId
   WHERE so.OrderNo = :NEW.OrderNo;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20003, 'Order ' || :NEW.OrderNo || ' does not exist');
END;
/

-- T4: a renamed customer is cascaded to the invoices of its orders (2 levels).
--     Design choice: here the copy follows the master data, so the invoice
--     always shows the current name. If your domain needs historical accuracy
--     (the name as on the day of issue), do NOT create this trigger and
--     document the decision instead.
CREATE OR REPLACE TRIGGER trg_customer_invoice
AFTER UPDATE OF Name ON Customer
FOR EACH ROW
DECLARE
  l_old BOOLEAN := pkg_denorm.g_cascade;
BEGIN
  pkg_denorm.g_cascade := TRUE;
  UPDATE Invoice i
     SET CustomerName = :NEW.Name
   WHERE i.OrderNo IN (SELECT so.OrderNo FROM SalesOrder so
                        WHERE so.CustomerId = :NEW.CustomerId);
  pkg_denorm.g_cascade := l_old;
EXCEPTION
  WHEN OTHERS THEN
    pkg_denorm.g_cascade := l_old;
    RAISE;
END;
/

-- ---------------------------------------------------------------------
-- D3 (3NF) InvoiceItem.Amount
-- ---------------------------------------------------------------------

-- T5: the amount is always recomputed from quantity, price and discount
--     (also when someone tries to set it by hand)
CREATE OR REPLACE TRIGGER trg_invoiceitem_amount
BEFORE INSERT OR UPDATE ON InvoiceItem
FOR EACH ROW
BEGIN
  :NEW.Amount := ROUND(:NEW.Quantity * :NEW.Price * (1 - NVL(:NEW.DiscountPct, 0) / 100), 2);
END;
/

-- check that all triggers compiled (STATUS = VALID)
SELECT trigger_name, table_name, status
  FROM user_triggers
 ORDER BY table_name, trigger_name;
