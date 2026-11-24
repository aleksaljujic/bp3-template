# Spec: Part 3, Logical Optimization
Status: Draft
Source: prompts/01_logical_optimization.md
Scripts: queries/06_logical_optimization.sql, queries/07_test_logical.sql, queries/00b_reset_part3.sql

Follows the rules in [00_spec_workflow.md](00_spec_workflow.md).

## 0. Starting state and deviations

State after `00`-`05`:

| Item | State |
|---|---|
| Tables | Country, City, Customer, Unit, Product, Currency, Incoterm, SalesOrder, OrderItem, Invoice, InvoiceItem |
| Denormalization | D1 `InvoiceItem.IssueDate`, D2 `Invoice.CustomerId/CustomerName`, D3 `InvoiceItem.Amount` |
| Triggers | T1-T5; package `pkg_denorm` with `g_cascade` (created in `04`) |
| Error codes in use | -20001 .. -20009 |

Deviations from the prompt:

> TODO: list anything the implementation does differently from the prompt, and why. Example: the package is not recreated in `06` because `04` already creates it.

## 1. Style

- English comments, ASCII only; header block with file name and purpose; sections with `-- ----`.
- Every PL/SQL object ends with `/` on its own line; no blank lines inside SQL statements.
- Naming: `trg_<table>_<purpose>`, `p_<verb>_<noun>`, `ck_<abbr>_<col>`.
- Re-runnable: `00b` then `06` works; `06` twice does not fail.

## 2. `06_logical_optimization.sql`

### 2.1 Technique 1: `Invoice.TotalAmount`

| Item | Requirement |
|---|---|
| Column | `TotalAmount NUMBER(16,2) DEFAULT 0 NOT NULL`, filled from `SUM(InvoiceItem.Amount)` before the guard exists (or with the flag set) |
| T6 `trg_invoiceitem_total` | COMPOUND, `FOR INSERT OR UPDATE OF Quantity, Price, DiscountPct, InvoiceNo OR DELETE`; collect keys (new and old) in AFTER EACH ROW; recompute `NVL(SUM(Amount),0)` in AFTER STATEMENT; flag save/set/restore, restore also in the exception handler |
| T7 `trg_invoice_total_guard` | `BEFORE INSERT OR UPDATE OF TotalAmount ON Invoice FOR EACH ROW`; INSERT sets 0; UPDATE with flag FALSE raises -20010 |
| Interaction | T5 computes `Amount` before the row is stored, so T6 sees final values; the update of Invoice in T6 triggers T3 only if its columns are in the SET list (they are not) |

### 2.2 Technique 2: Incoterm lookup replaced by CHECK

| Item | Requirement |
|---|---|
| Step 1 | print current rows (EXW, FCA) with DBMS_OUTPUT |
| Step 2 | drop `fk_so_incoterm`, drop table `Incoterm` |
| Step 3 | `ALTER TABLE SalesOrder ADD CONSTRAINT ck_so_incoterm CHECK (IncotermCode IN ('EXW','FCA'))` (NULL stays allowed) |
| P1 `p_change_incoterms(p_list VARCHAR2)` | parse comma list, `UPPER(TRIM)`, dedupe; each value matches `^[A-Z0-9]{1,10}$` else -20012; refuse removal of used values with -20011 (values via LISTAGG); add `ck_so_incoterm_new`, drop `ck_so_incoterm`, rename; print result; comment "DDL commits implicitly" |

## 2.3 `00b_reset_part3.sql`

Drop T6, T7, P1, column `TotalAmount`, `ck_so_incoterm`, `ck_so_incoterm_new` (ignore "does not exist");
recreate `Incoterm` with EXW and FCA and `fk_so_incoterm`; no error if run twice.

## Requirements

| ID | Statement | Source | Acceptance | Verified by |
|---|---|---|---|---|
| R-01 | `Invoice.TotalAmount` MUST equal `SUM(InvoiceItem.Amount)` after every insert, update or delete of items | assignment 3.1, technique 1 | equal for all invoices | tests 1-6 |
| R-02 | A multi-row statement on items MUST NOT raise ORA-04091 | prompt | correct totals for both invoices | test 5 |
| R-03 | A manual update of `TotalAmount` MUST fail with ORA-20010 | prompt | error raised, value unchanged | test 7 |
| R-04 | `SalesOrder.IncotermCode` MUST be restricted by `ck_so_incoterm` after the `Incoterm` table is dropped | technique 2 | ORA-02290 on an unknown value | test 9 |
| R-05 | `p_change_incoterms` MUST reject malformed values (-20012) before any DDL and values in use (-20011) | prompt | errors raised, constraint unchanged | tests 11, 12 |
| R-06 | `00b_reset_part3.sql` MUST be idempotent | style | runs twice without error, restores the part 2 state | review |
| R-07 | The tests SHOULD leave the database in the starting state | style | `ck_so_incoterm` lists EXW, FCA | test 13 |

## Tasks

| ID | Covers | Owns (files it may write) | Reads | Depends on | Done when |
|---|---|---|---|---|---|
| K-01 | R-01..R-05 | `queries/06_logical_optimization.sql` | spec, `01`-`04` | none | file compiles without errors |
| K-02 | R-06 | `queries/00b_reset_part3.sql` | spec, `01`, `02`, `06` | K-01 (object names) | runs twice without error |
| K-03 | R-01..R-05, R-07 (tests) | `queries/07_test_logical.sql` | spec, `05` | none | each step has its expected result in the header |
| K-04 | integration | `results/` | all | K-01..K-03 | full run passes, only expected errors (workflow section 6) |

## 3. Test plan: `07_test_logical.sql`, expected results

| # | Action | Expected |
|---|---|---|
| 1 | Compare `TotalAmount` with `SUM(Amount)` for all invoices | equal for every row |
| 2 | Insert an item into I-0001 | total increases by the new item's Amount |
| 3 | Update Quantity of an item | total changes accordingly |
| 4 | Delete an item | total decreases; invoice without items has 0 |
| 5 | One UPDATE touching items of two invoices | both totals correct |
| 6 | Move an item to another invoice (`SET InvoiceNo`) | old and new invoice both correct |
| 7 | `UPDATE Invoice SET TotalAmount = 1` | ERROR ORA-20010 (expected) |
| 8 | ROLLBACK | totals back to the initial values |
| 9 | Insert order with `IncotermCode = 'DAP'` | ERROR ORA-02290 (expected) |
| 10 | `EXEC p_change_incoterms('exw, fca ,dap, DAP')` | constraint now allows EXW, FCA, DAP; insert of DAP succeeds |
| 11 | `EXEC p_change_incoterms('FCA')` while an order uses EXW | ERROR ORA-20011 naming EXW (expected) |
| 12 | `EXEC p_change_incoterms('EXW;DROP')` | ERROR ORA-20012 (expected) |
| 13 | ROLLBACK, then `EXEC p_change_incoterms('EXW,FCA')` | original state restored (DDL is not rolled back) |

Expected unexpected-error count in the output: 5 expected errors (rows 7, 9, 11, 12 and any in row 10 if testing invalid input).

> TODO: adjust to your data; add real expected numbers (for example TotalAmount of I-0001 = 150.00).

## 4. Documentation content

- Model before and after (Invoice with `TotalAmount`; SalesOrder without FK to Incoterm).
- Reason for each technique (read cost vs write cost; join removed vs flexibility lost).
- Trigger table entries for T6 and T7, procedure description for P1.

## 5. Acceptance checklist

- [ ] `./run_all.sh` runs 00..07 on a clean database; only the expected errors appear
- [ ] `00b` followed by `06` and `07` works
- [ ] No file other than the three scripts was changed
- [ ] The flag is restored on every path (success and exception)
- [ ] P1 rejects bad input before any DDL runs
- [ ] The final state after `07` equals the state before it (constraint list EXW, FCA)
- [ ] Every `R-xx` has evidence (test step or query)

## 6. Open questions

| # | Question | Options | Recommendation | Decision |
|---|---|---|---|---|
| O1 | Should T7 also forbid inserting a non-zero `TotalAmount`? | forbid (set 0) / allow | set 0 on insert | TODO |
| O2 | Should the totals of existing rows be recomputed inside `06` or by a separate script? | in `06` / separate | in `06`, before T7 exists | TODO |

> TODO: add your own questions; the human closes them before the status becomes Approved.

## Changelog

- YYYY-MM-DD: created (Draft)
