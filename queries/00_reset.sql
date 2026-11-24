-- =====================================================================
-- 00_reset.sql
-- Drops every object the template ever creates (parts 1, 2 and 3).
-- Re-runnable: objects that do not exist are skipped.
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Part 3 view CustomerFull (DROP TABLE does not drop views; the INSTEAD OF
-- triggers on the view are dropped together with it)
-- ---------------------------------------------------------------------
BEGIN
  FOR v IN (SELECT view_name FROM user_views WHERE view_name = 'CUSTOMERFULL') LOOP
    EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- Part 3 procedure p_change_incoterms (depends on SalesOrder)
-- ---------------------------------------------------------------------
BEGIN
  FOR p IN (SELECT object_name FROM user_objects
             WHERE object_type = 'PROCEDURE' AND object_name = 'P_CHANGE_INCOTERMS') LOOP
    EXECUTE IMMEDIATE 'DROP PROCEDURE ' || p.object_name;
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- Tables (children first; CustomerDetails from part 3 references Customer).
-- Triggers and indexes on the tables are dropped together with them.
-- ---------------------------------------------------------------------
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN (
    'CUSTOMERDETAILS',
    'INVOICEITEM','INVOICE','ORDERITEM','SALESORDER',
    'INCOTERM','CURRENCY','PRODUCT','UNIT','CUSTOMER','CITY','COUNTRY'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- Package pkg_denorm (dropped last: the triggers that used it are gone)
-- ---------------------------------------------------------------------
BEGIN
  FOR p IN (SELECT object_name FROM user_objects
             WHERE object_type = 'PACKAGE' AND object_name = 'PKG_DENORM') LOOP
    EXECUTE IMMEDIATE 'DROP PACKAGE ' || p.object_name;
  END LOOP;
END;
/
