# queries/

SQL scripts of the project, written for Oracle Database 23ai Free and run in SQL*Plus as the application user
(`app/app`, service `FREEPDB1`). The scripts are numbered in the order in which they are meant to be run.
The example model is orders and invoicing; every script starts with
`-- TEMPLATE: replace the example model (orders/invoices) with your own domain.`

## Scripts

| File | Part | Purpose | Re-runnable |
|---|---|---|---|
| `00_reset.sql` | all | Drops everything the template creates (tables incl. CustomerDetails and Incoterm, view CustomerFull, package pkg_denorm, procedure p_change_incoterms) | yes |
| `01_tables.sql` | 1 | Normalized relational model: tables, keys, constraints | no (run 00 first) |
| `02_data.sql` | 1 | A handful of invented test rows | no (run 00, 01 first) |
| `03_denormalization.sql` | 2 | Redundant columns D1 (2NF), D2 (3NF, 2 levels), D3 (3NF, derived) and their initial fill | no (ALTER TABLE ADD) |
| `04_triggers.sql` | 2 | Package `pkg_denorm` and triggers T1..T5 that keep the redundant data consistent | yes (CREATE OR REPLACE) |
| `05_tests.sql` | 2 | Statements that fire T1..T5, expected errors included; ends with ROLLBACK | yes |
| `00b_reset_part3.sql` | 3 | Undoes the logical optimization of part 3 (T6, T7, P1, TotalAmount, incoterm check; recreates Incoterm) | yes |
| `06_logical_optimization.sql` | 3a | Technique 1 (stored derivable value, T6/T7) and technique 2 (hard-coded values, P1) | no (use 00b to undo) |
| `07_test_logical.sql` | 3a | Tests of T6, T7 and P1, including expected errors | yes |
| `08_generate_data.sql` | 3b | Generates a large data set (keys with prefix `G-`) and gathers statistics | yes (guarded against a second run) |
| `09_indexes.sql` | 3b | Three index types (B-tree, bitmap, function-based) with execution plans before and after | yes (drops indexes first) |
| `10_partitioning.sql` | 3c | Horizontal (interval range on Invoice) and vertical (CustomerDetails + view CustomerFull) partitioning | partly (idempotent where practical) |
| `11_test_partitioning.sql` | 3c | Tests of partition pruning and of DML through CustomerFull; ends with ROLLBACK | yes |
| `joins_examples.sql` | - | 8 JOIN examples on the example model (read-only) | yes |
| `window_examples.sql` | - | 8 analytic function examples on the example model (read-only) | yes |

## Run order

```
00_reset -> 01_tables -> 02_data                              (part 1)
         -> 03_denormalization -> 04_triggers -> 05_tests     (part 2)
         -> 06_logical_optimization -> 07_test_logical        (part 3a)
         -> 08_generate_data -> 09_indexes                    (part 3b)
         -> 10_partitioning -> 11_test_partitioning           (part 3c)
```

To repeat only part 3a, run `00b_reset_part3.sql` and then `06`. To start everything from scratch, run
`00_reset.sql` and the whole sequence. The root `run_all.sh` runs the scripts in this order and writes the
outputs to `results/`.

## Conventions

- Numbering: `NN_name.sql` in run order; `00b` is an extra reset step that belongs between parts; example scripts
  have no number because they are not part of the sequence.
- Header: every file starts with a `-- ====` block containing the file name and a one-sentence purpose;
  sections are separated by `-- ----` lines. Comments are in English, files are ASCII only.
- Labels: `D#` denormalization, `T#` triggers, `P#` procedures, `I#` indexes. The same label is used in the
  SQL comments, in the explanations and in the assignment documents, so a reader can follow one idea across files.
- Every PL/SQL object ends with `/` on its own line; SQL statements contain no blank lines.
- Error codes (`RAISE_APPLICATION_ERROR`): `-20001..-20009` part 2, `-20010..-20019` part 3.
- Tests: each test has a header block with the expected result, then the statement, then a `SELECT` that shows
  the outcome. A statement that must fail is marked `ERROR ORA-200xx (expected)` in its header; SQL*Plus prints
  the error and continues. Any other error is a real problem. Test scripts end with `ROLLBACK` so they can be repeated.
- DDL commits implicitly in Oracle: a `ROLLBACK` does not undo `ALTER TABLE`, only DML before it.

## Adapting to your own model

1. Rewrite `01_tables.sql` and `02_data.sql` for your domain; keep the constraint naming
   (`pk_<table>`, `fk_<abbr>_<target>`, `ck_<abbr>_<col>`).
2. Choose your own denormalization examples (at least one 2NF, one 3NF, one through two or more levels) and
   adapt `03` and `04`; keep the `pkg_denorm.g_cascade` flag pattern (save the old value, set TRUE, restore it
   also in the exception handler).
3. Write `05_tests.sql` so that every trigger has at least one positive test and every `RAISE_APPLICATION_ERROR`
   has a test that provokes it.
4. Update the object lists in `00_reset.sql` (and `00b_reset_part3.sql`) whenever you add a table, view, package
   or procedure, otherwise the sequence stops being re-runnable.
5. Replace the example `joins_examples.sql` and `window_examples.sql` queries with ones on your own tables.
