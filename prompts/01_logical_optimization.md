# Prompt: Logical Optimization (part 3a)

You are working on an Oracle Database 23ai Free university project (course `<COURSE NAME>`, part 3: database optimization). Existing scripts in `queries/`:

- `00_reset.sql`: drops the schema objects
- `01_tables.sql`: normalized tables
- `02_data.sql`: test data
- `03_denormalization.sql`: part 2 redundant columns (D1-D3)
- `04_triggers.sql`: part 2 triggers T1-T5, including package `pkg_denorm` with flag `g_cascade`
- `05_tests.sql`: part 2 tests

Read ALL of them first. Do NOT modify them. Create three new scripts: `06_logical_optimization.sql`, `07_test_logical.sql` and `00b_reset_part3.sql`.

Style: English comments, ASCII only, every PL/SQL object terminated with `/` on its own line, no blank lines inside SQL statements, same naming conventions as `04_triggers.sql`. Header block with file name and purpose.

## Technique 1: storing derivable values, `Invoice.TotalAmount`

The total of an invoice is the sum of `InvoiceItem.Amount` (kept correct by T5).

1. `ALTER TABLE Invoice ADD TotalAmount NUMBER(16,2) DEFAULT 0 NOT NULL;` then fill it from the items. The fill must pass the guard trigger: run it before creating the guard, or set `pkg_denorm.g_cascade` around it.
2. **T6 `trg_invoiceitem_total`**: COMPOUND trigger `FOR INSERT OR UPDATE OF Quantity, Price, DiscountPct, InvoiceNo OR DELETE ON InvoiceItem`.
   - AFTER EACH ROW collects `:NEW.InvoiceNo`, and `:OLD.InvoiceNo` on delete or when InvoiceNo changes.
   - AFTER STATEMENT recomputes `TotalAmount = NVL(SUM(Amount), 0)` per collected invoice.
   - Save, set TRUE, and restore `pkg_denorm.g_cascade`; also restore in the exception handler, then re-raise.
   - Explain in a comment why a compound trigger is needed (ORA-04091).
3. **T7 `trg_invoice_total_guard`**: `BEFORE INSERT OR UPDATE OF TotalAmount ON Invoice FOR EACH ROW`. INSERT sets 0. UPDATE without the flag raises `-20010`.
4. Check interactions with existing triggers (T1-T5). The update of Invoice inside T6 must not fire anything that reads InvoiceItem.

## Technique 2: hard-coded values, table `Incoterm`

`Incoterm` is small and stable; only `SalesOrder.IncotermCode` references it (`fk_so_incoterm`).

1. Print the current values with `DBMS_OUTPUT` for the documentation.
2. Drop the FK, drop the table, add `ck_so_incoterm CHECK (IncotermCode IN ('EXW','FCA'))` using exactly the existing values.
3. **P1 `p_change_incoterms(p_list IN VARCHAR2)`**:
   - Parse a comma-separated list; `UPPER(TRIM(...))`, remove duplicates.
   - Validate every value with `^[A-Z0-9]{1,10}$`, else `-20012` (protects the dynamic SQL from injection).
   - Refuse if a value in use would be removed: `-20011`, name the values with `LISTAGG`.
   - DDL via `EXECUTE IMMEDIATE`: add `ck_so_incoterm_new`, drop `ck_so_incoterm`, rename. Never leave the table without a constraint.
   - Print the new constraint text. Comment that DDL commits implicitly.
4. `00b_reset_part3.sql`: idempotent undo (drop T6, T7, P1, column, constraints; recreate `Incoterm`, rows and FK).

## Tests: `07_test_logical.sql`

Same style as `05_tests.sql`: header with EXPECTED result, statement, SELECT after each step.

1. `TotalAmount` equals `SUM(Amount)` for all invoices.
2. Insert an item: total increases.
3. Update Quantity: total changes.
4. Delete an item: total decreases (0 for an invoice without items).
5. Multi-row statement touching two invoices.
6. Move an item to another invoice: both totals change.
7. Manual `UPDATE ... SET TotalAmount`: `ERROR ORA-20010 (expected)`.
8. ROLLBACK.
9. Invalid incoterm insert: `ORA-02290 (expected)`. `p_change_incoterms('EXW,FCA,DAP')`, insert DAP works.
10. Remove a used value: `-20011`. Bad format `'EXW;DROP'`: `-20012`.
11. Final ROLLBACK, then `EXEC p_change_incoterms('EXW,FCA')` (DDL is not rolled back).

## Constraints

- Do not change files outside the three new scripts.
- Scripts must be re-runnable (run `00b` then `06` again must work).
- Run them in SQL*Plus as `app/app@//localhost:1521/FREEPDB1` (`./run_all.sh 06_logical_optimization`) and report every `ORA-` line that is not expected.

> TODO: replace the example names and add your own domain-specific rules.
