# Code for Defense: Oracle / PL/SQL Cheat Sheet

Generic reference; examples use the orders/invoicing model.

> TODO: add the lines of your own scripts that you find hardest, with a one-line explanation each.

## Contents

1. SQL*Plus commands
2. PL/SQL block and SELECT INTO
3. Errors and RAISE_APPLICATION_ERROR
4. Re-runnable scripts
5. EXECUTE IMMEDIATE
6. Data dictionary views
7. Trigger anatomy, :NEW / :OLD
8. Flag package pattern
9. Mutating table and compound triggers
10. INSTEAD OF triggers
11. Transactions and DDL
12. EXPLAIN PLAN and DBMS_XPLAN
13. Index types
14. Partitioning

## 1. SQL*Plus commands (not SQL)

| Command | Meaning |
|---|---|
| `SET SERVEROUTPUT ON` | show `DBMS_OUTPUT.PUT_LINE` output |
| `SET LINESIZE 200`, `SET PAGESIZE 100` | output width / page length |
| `SET ECHO ON` | print each statement from a script |
| `SET DEFINE OFF` | do not treat `&` as a substitution variable |
| `COLUMN name FORMAT A30` | column width |
| `PROMPT text` | print text |
| `@file.sql` | run a script |
| `EXEC proc(args)` | one-line PL/SQL call |
| `/` | run the statement/PL/SQL block in the buffer |
| `SHOW ERRORS` | compile errors of the last object |
| `WHENEVER SQLERROR EXIT` | stop on first error |

A plain SQL statement ends with `;`. A PL/SQL object (trigger, procedure, package, anonymous block)
ends with `/` on its own line, because `;` appears inside the body. No blank lines inside a SQL
statement (SQL*Plus ends it there).

## 2. PL/SQL block

```sql
DECLARE
  v_name Customer.Name%TYPE;     -- type copied from the column
  v_cnt  NUMBER := 0;
BEGIN
  SELECT Name INTO v_name FROM Customer WHERE CustomerId = 1;
  DBMS_OUTPUT.PUT_LINE('Customer: ' || v_name);
EXCEPTION
  WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('none');
  WHEN TOO_MANY_ROWS THEN DBMS_OUTPUT.PUT_LINE('several');
END;
/
```

`SELECT ... INTO` must return exactly one row, otherwise NO_DATA_FOUND / TOO_MANY_ROWS.
`FOR r IN (SELECT ...) LOOP ... END LOOP;` iterates over many rows.

## 3. Errors

```sql
RAISE_APPLICATION_ERROR(-20001, 'IssueDate is copied from the invoice and cannot be changed manually');
```

- Codes -20000..-20999 are for your own errors; the client sees `ORA-20001: message`.
- In a trigger the statement is rolled back (statement-level rollback).
- Catch-and-rethrow (clean up first): `EXCEPTION WHEN OTHERS THEN <restore state>; RAISE;`
- `SQLCODE` / `SQLERRM` give the code and text inside a handler.
- Typical built-in errors: ORA-00001 unique violated, ORA-02290 check violated, ORA-02291 parent not found,
  ORA-02292 child exists, ORA-04091 mutating table.

Project error code map (example): -20001 T1, -20002 T3, -20010 T7, -20011 P1 value in use, -20012 P1 bad format.

> TODO: write your own code map.

## 4. Re-runnable scripts

Pattern A, loop over the dictionary:

```sql
BEGIN
  FOR t IN (SELECT table_name FROM user_tables) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE "' || t.table_name || '" CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/
```

Pattern B, try and ignore a known error:

```sql
BEGIN
  EXECUTE IMMEDIATE 'DROP INDEX ix_invoice_customer_date';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -1418 THEN RAISE; END IF;   -- ORA-01418: index does not exist
END;
/
```

Common "does not exist" codes: -942 table, -1418 index, -4080 trigger, -2443 constraint, -2289 sequence.

Pattern C, insert if missing: `MERGE INTO t USING (SELECT 'EXW' c FROM dual) s ON (t.c = s.c) WHEN NOT MATCHED THEN INSERT ...`.

Pattern D, guard against running twice: `SELECT COUNT(*) INTO v FROM Customer WHERE CustomerId LIKE 'G-%'; IF v > 0 THEN ... skip`.

## 5. EXECUTE IMMEDIATE

Runs a SQL string at run time. Needed for DDL inside PL/SQL.

```sql
EXECUTE IMMEDIATE 'ALTER TABLE SalesOrder ADD CONSTRAINT ck_so_incoterm_new CHECK (IncotermCode IN (' || v_list || '))';
EXECUTE IMMEDIATE 'UPDATE Invoice SET TotalAmount = 0 WHERE InvoiceNo = :1' USING v_no;   -- bind variable
```

Values from outside must be validated (for example with `REGEXP_LIKE(v, '^[A-Z0-9]{1,10}$')`) before they
are concatenated into DDL: otherwise SQL injection. DDL cannot use bind variables.

## 6. Data dictionary views

| View | Shows |
|---|---|
| `user_tables`, `user_tab_columns` | tables, columns |
| `user_constraints`, `user_cons_columns` | constraints (type P, R, C, U) and columns |
| `user_indexes`, `user_ind_columns` | indexes |
| `user_triggers` | triggers (`trigger_name`, `status`, `trigger_body`) |
| `user_source` | source of procedures, packages, triggers |
| `user_errors` | compile errors |
| `user_objects` | everything, with `status` VALID/INVALID |
| `user_tab_partitions`, `user_part_tables` | partitions |

Names are stored UPPER CASE: `WHERE table_name = 'INVOICE'`.

## 7. Trigger anatomy

```sql
CREATE OR REPLACE TRIGGER trg_invoiceitem_date
BEFORE INSERT OR UPDATE OF InvoiceNo, IssueDate ON InvoiceItem   -- timing, event, columns, table
FOR EACH ROW                                                      -- row level
WHEN (NEW.InvoiceNo IS NOT NULL)                                  -- optional filter (no colon)
DECLARE
  v_date DATE;
BEGIN
  SELECT IssueDate INTO v_date FROM Invoice WHERE InvoiceNo = :NEW.InvoiceNo;
  :NEW.IssueDate := v_date;                                       -- allowed only in BEFORE
END;
/
```

- **BEFORE** triggers can change `:NEW`; **AFTER** triggers cannot, but can do other DML.
- `:NEW` = row after the change (INSERT, UPDATE); `:OLD` = row before (UPDATE, DELETE). `:OLD` is NULL on INSERT.
- Predicates `INSERTING`, `UPDATING`, `UPDATING('Col')`, `DELETING` tell which event fired.
- `UPDATE OF col` fires only when the column appears in the SET list (even if the value is unchanged).
- Statement level (no `FOR EACH ROW`) runs once per statement and has no `:NEW`/`:OLD`.
- Several triggers on one table: order is undefined unless `FOLLOWS other_trigger` is used.
- `ALTER TRIGGER name DISABLE|ENABLE`; `DROP TRIGGER name`.

## 8. Flag package pattern

Problem: a cascade trigger updates a column that a guard trigger forbids to change manually.

```sql
CREATE OR REPLACE PACKAGE pkg_denorm AS
  g_cascade BOOLEAN := FALSE;
END pkg_denorm;
/
-- in the cascade trigger:
DECLARE v_old BOOLEAN;
BEGIN
  v_old := pkg_denorm.g_cascade;      -- 1. save
  pkg_denorm.g_cascade := TRUE;       -- 2. raise
  UPDATE InvoiceItem SET IssueDate = :NEW.IssueDate WHERE InvoiceNo = :NEW.InvoiceNo;
  pkg_denorm.g_cascade := v_old;      -- 3. restore the OLD value, not FALSE (nested cascades)
EXCEPTION WHEN OTHERS THEN
  pkg_denorm.g_cascade := v_old;      -- 4. restore also on error, then re-raise
  RAISE;
END;
/
-- in the guard trigger:
IF NOT pkg_denorm.g_cascade THEN RAISE_APPLICATION_ERROR(-20001, '...'); END IF;
```

Package variables live per session, so the flag does not leak between users. If a script recreates
the package, the other scripts keep working because the spec is the same.

## 9. Mutating table and compound triggers

A row trigger on table X cannot read or modify X (ORA-04091), because X is in the middle of the statement.
Compound trigger solution: collect keys per row, process after the statement.

```sql
CREATE OR REPLACE TRIGGER trg_invoiceitem_total
FOR INSERT OR UPDATE OF Quantity, Price, DiscountPct, InvoiceNo OR DELETE ON InvoiceItem
COMPOUND TRIGGER
  TYPE t_set IS TABLE OF NUMBER INDEX BY VARCHAR2(20);   -- associative array used as a set
  g_keys t_set;
  AFTER EACH ROW IS BEGIN
    IF :NEW.InvoiceNo IS NOT NULL THEN g_keys(:NEW.InvoiceNo) := 1; END IF;
    IF :OLD.InvoiceNo IS NOT NULL THEN g_keys(:OLD.InvoiceNo) := 1; END IF;
  END AFTER EACH ROW;
  AFTER STATEMENT IS
    k VARCHAR2(20);
  BEGIN
    k := g_keys.FIRST;
    WHILE k IS NOT NULL LOOP
      UPDATE Invoice SET TotalAmount = NVL((SELECT SUM(Amount) FROM InvoiceItem WHERE InvoiceNo = k), 0)
      WHERE InvoiceNo = k;
      k := g_keys.NEXT(k);
    END LOOP;
    g_keys.DELETE;
  END AFTER STATEMENT;
END;
/
```

Sections: BEFORE STATEMENT, BEFORE EACH ROW, AFTER EACH ROW, AFTER STATEMENT. Variables declared in the
compound body live for one statement.

## 10. INSTEAD OF triggers

A view over a join is not directly updatable. `CREATE TRIGGER ... INSTEAD OF INSERT ON CustomerFull FOR EACH ROW`
replaces the DML: you insert into the base tables yourself using `:NEW`. One trigger per event.

## 11. Transactions and DDL

- `COMMIT` makes changes permanent, `ROLLBACK` discards changes since the last commit.
- DDL (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`) commits implicitly before and after.
  A test that calls DDL (like `p_change_incoterms`) must restore the state by hand.
- Tests use `ROLLBACK` at the end so they can be repeated.

## 12. EXPLAIN PLAN and DBMS_XPLAN

```sql
EXPLAIN PLAN FOR
SELECT * FROM Invoice WHERE CustomerId = 'G-100' AND IssueDate >= DATE '2025-01-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Gather statistics first: `EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'INVOICE');` or `GATHER_SCHEMA_STATS(USER)`.
The optimizer is cost-based and needs statistics to choose an index.

| Operation | Meaning |
|---|---|
| TABLE ACCESS FULL | scans all rows |
| INDEX RANGE SCAN | index, many entries |
| INDEX UNIQUE SCAN | index, one entry |
| TABLE ACCESS BY INDEX ROWID | fetch the row found in the index |
| BITMAP INDEX ... / BITMAP CONVERSION | bitmap access |
| HASH JOIN / NESTED LOOPS | join methods |
| PARTITION RANGE SINGLE / ITERATOR / ALL | partition pruning: one / several / all partitions |

Read the plan from the innermost, most indented line outwards. Columns: Rows (estimate), Cost.
`Predicate Information` shows which condition is used as access and which as filter.
`EXPLAIN PLAN` does not run the query; use `/*+ GATHER_PLAN_STATISTICS */` and `DBMS_XPLAN.DISPLAY_CURSOR` for actual rows.

## 13. Index types

| Type | Syntax | Use |
|---|---|---|
| B-tree | `CREATE INDEX ix ON t(a)` | default; equality and range |
| Composite | `CREATE INDEX ix ON t(a, b)` | equality column first, range column second; usable for prefix `a` |
| Unique | `CREATE UNIQUE INDEX ...` | also enforces uniqueness |
| Bitmap | `CREATE BITMAP INDEX ix ON t(flag)` | low cardinality, read-mostly (reporting) |
| Function-based | `CREATE INDEX ix ON t(UPPER(name))` | query uses the same expression |
| Reverse key, descending, invisible | options | special cases |
| Local (partitioned) | `... LOCAL` | one index partition per table partition |

An index costs space and slows DML. A query that returns a large share of the table is faster with a full scan.

## 14. Partitioning

Horizontal (rows are split):

```sql
ALTER TABLE Invoice MODIFY PARTITION BY RANGE (IssueDate)
  INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
  (PARTITION p_before_2024 VALUES LESS THAN (DATE '2024-01-01')) ONLINE;
SELECT partition_name, high_value FROM user_tab_partitions WHERE table_name = 'INVOICE';
```

Other schemes: LIST, HASH, composite. Benefits: partition pruning, easier archiving (`DROP PARTITION`),
smaller local indexes. Local index: `CREATE INDEX ... LOCAL`; global index spans all partitions.

Vertical (columns are split): rarely used columns go to a 1:1 table with PK = FK, a view joins them
back, INSTEAD OF triggers keep the old interface. Benefit: narrow hot table, more rows per block.
