# Prompt: Re-sync Part 3 After Part 2 Changed

The part 2 design of this Oracle project changed (for example from 7 denormalizations to 3, or the reverse). I am giving you new versions of three scripts. Replace the existing files with them exactly, then adapt the part 3 scripts and run everything.

## 1. Replace these files

Use the attached files as-is: `queries/03_denormalization.sql`, `04_triggers.sql`, `05_tests.sql`.

New part 2 contents (example, adapt):

- D1 (2NF): `InvoiceItem.IssueDate`; T1, T2
- D2 (3NF, 2 levels): `Invoice.CustomerId`, `CustomerName`; T3, T4
- D3 (3NF): `InvoiceItem.Amount`; T5
- Package `pkg_denorm` (flag `g_cascade`) is created in `04_triggers.sql`.

Removed (list columns, FKs and triggers that no longer exist): `<LIST>`.

Check `00_reset.sql` and `00b_reset_part3.sql`: dropping tables removes triggers, but if a script drops removed triggers or columns by name, guard it or remove it so that 00 still runs cleanly.

## 2. Adapt the part 3 scripts (06-11)

- Renumber triggers so part 3 continues after the last part 2 trigger (T6, T7, ...). Update comments, tests and docs.
- Remove references to removed columns and triggers; check that every statement in `06`-`11` still compiles.
- Check interactions: which part 2 triggers fire when part 3 scripts insert or update data (`08` inserts with triggers enabled)?

## 3. Run and verify

Start from a clean schema: `./run_all.sh` (00..11). List every `ORA-`/`PLS-`/`SP2-` line and say whether it is expected (marked `(expected)` in the tests) or a bug; fix bugs in the scripts.

## 4. Collect the results

Write `results/results.md` in the format described in `results/README.md` (setup table, per step SQL + expected + actual + status, summary table). Do not commit it.

> TODO: fill in your list of changes.
