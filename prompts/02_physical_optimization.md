# Prompt: Physical Optimization and Partitioning (part 3b, 3c)

Oracle Database 23ai Free, user `app`. Scripts `00`-`07` exist (and `00b`). Read them all. Do NOT modify them.
Create: `08_generate_data.sql`, `09_indexes.sql`, `10_partitioning.sql`, `11_test_partitioning.sql`.
Style: English comments, ASCII only, `/` after PL/SQL, header block, sections with `-- ----`, `SET SERVEROUTPUT ON` where needed.

Before writing code, write the spec to `spec/02_physical_optimization.md` (sections: starting state and deviations, style, per-script requirements, test table, documentation content, acceptance checklist) and stop for review.

## 08: data generation

- Set-based `INSERT ... SELECT ... CONNECT BY LEVEL`; no row-by-row loops. Deterministic (use `ORA_HASH`, not `DBMS_RANDOM`).
- Keys prefixed `G-`; the script must detect a previous run and skip.
- Volumes: about 200 customers, 1000 products (names like `PAPER BAG ...`, `BOX ...`, mixed case, needed for I3), 5000 sales orders, 50000 invoices, 1-3 items each.
- `IssueDate` spread over 2024-01-01 .. 2026-12-31; `CurrencyCode` about 70% EUR, 30% USD.
- Triggers stay enabled (they fill the denormalized columns and totals). COMMIT in batches.
- End with `DBMS_STATS.GATHER_SCHEMA_STATS(USER)` and a count summary.

## 09: indexes

Template per index: the query (comment saying what it answers), `EXPLAIN PLAN FOR` + `DBMS_XPLAN.DISPLAY` before, drop-if-exists, `CREATE INDEX`, gather stats, plan after. Re-runnable.

- **I1** B-tree composite `ix_invoice_customer_date ON Invoice(CustomerId, IssueDate)`: invoices of one customer in a range.
- **I2** bitmap `ix_invoice_currency ON Invoice(CurrencyCode)`: counts by currency. Comment on why bitmap is poor for concurrent DML.
- **I3** function-based `ix_product_upper_name ON Product(UPPER(Name))`: case-insensitive search.
- Choose queries and values so the optimizer actually picks the index; if not, explain in a comment (selectivity) rather than forcing a hint.

## 10: partitioning

- Horizontal: `ALTER TABLE Invoice MODIFY PARTITION BY RANGE (IssueDate) INTERVAL (NUMTOYMINTERVAL(1,'MONTH')) (PARTITION p_before_2024 VALUES LESS THAN (DATE '2024-01-01')) ONLINE`; local index `ix_invoice_date_loc`; show `user_tab_partitions`; pruning plans (`PARTITION RANGE SINGLE` and `ITERATOR`). Handle objects that block the conversion (existing indexes/constraints) and make the script re-runnable where practical.
- Vertical: move `Address, Phone, Email, Note` of `Customer` into `CustomerDetails` (1:1, PK = FK `CustomerId`), copy data, drop the columns, create view `CustomerFull` with the original column order, and INSTEAD OF INSERT/UPDATE/DELETE triggers on the view. Show the relational model before and after in comments.

## 11: tests

Insert an invoice in a month without partition (created automatically, show it), pruning plan, DML through `CustomerFull` (insert, update, delete, verify base tables), ROLLBACK.

## Run and report

`./run_all.sh 08_generate_data` ... in order. Report the plans (before/after cost) and every unexpected `ORA-` line.

> TODO: change table names, volumes and the columns you split to match your model.
