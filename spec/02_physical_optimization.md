# Spec: Part 3, Physical Optimization and Partitioning
Status: Draft
Source: prompts/02_physical_optimization.md
Scripts: queries/08_generate_data.sql, queries/09_indexes.sql, queries/10_partitioning.sql, queries/11_test_partitioning.sql

Follows the rules in [00_spec_workflow.md](00_spec_workflow.md).

## 0. Starting state and deviations

State after `00`-`07`: tables as in part 1, D1-D3, T1-T7, `Invoice.TotalAmount`, `Incoterm` replaced by `ck_so_incoterm`.

| Risk | Decision |
|---|---|
| Triggers fire during bulk insert (slower, but the data stays consistent) | keep enabled; insert in batches |
| `MODIFY PARTITION BY` needs all indexes/constraints convertible | drop or rebuild blocking indexes in `10`, recreate after |
| Optimizer may ignore an index on a tiny table | `08` first, then gather stats |

> TODO: list deviations from the prompt and anything your data model forces.

## 1. Style

Same as `spec/01_logical_optimization.md`, plus: every script prints a short summary (`DBMS_OUTPUT` or a final SELECT);
plans are printed with `DBMS_XPLAN.DISPLAY`.

## 2. `08_generate_data.sql`

### 2.0 Guard

If any customer key starts with `G-`, print "already generated" and skip everything.

### 2.1 Keys and volume

| Table | Rows | Key |
|---|---|---|
| Customer | 200 | `G-C0001`... |
| Product | 1000 | `G-P0001`... |
| SalesOrder | 5000 | `G-SO00001`... |
| Invoice | 50000 | `G-I000001`... |
| InvoiceItem | 1-3 per invoice | (`InvoiceNo`, 1..3) |

### 2.2 Product names

Prefix chosen from `PAPER BAG`, `BOX`, `LABEL`, ... plus a size and number; about half in mixed case ("Box Small 12")
so that `UPPER(Name)` is a meaningful predicate for I3.

### 2.3 Distribution

- `IssueDate`: even spread 2024-01-01 .. 2026-12-31 (`DATE '2024-01-01' + MOD(ORA_HASH(n), 1096)`).
- `CurrencyCode`: `EUR` when `MOD(ORA_HASH(n), 10) < 7`, else `USD`.
- Customers per invoice: `ORA_HASH` over 200 customers (about 250 invoices each).

### 2.4 Flow

Insert in order: Customer, Product, SalesOrder, Invoice (triggers fill D2), InvoiceItem (triggers fill D1, D3, T6 total);
COMMIT after each table; `DBMS_STATS.GATHER_SCHEMA_STATS(USER)`; print counts.

## 3. `09_indexes.sql`

### 3.1 Template per index

1. Comment: what query, why this index.
2. `EXPLAIN PLAN FOR <query>`; `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);` (before)
3. Drop if exists, `CREATE INDEX`, `DBMS_STATS.GATHER_TABLE_STATS`.
4. Same query again (after).

### 3.2 Indexes

| Id | Index | Query | Expected plan before | Expected plan after |
|---|---|---|---|---|
| I1 | `ix_invoice_customer_date` B-tree on `Invoice(CustomerId, IssueDate)` | invoices of one customer in a quarter | TABLE ACCESS FULL | INDEX RANGE SCAN (+ BY INDEX ROWID) |
| I2 | `ix_invoice_currency` bitmap on `Invoice(CurrencyCode)` | count of USD invoices in a month range | TABLE ACCESS FULL | BITMAP INDEX / FAST FULL SCAN (or explain why the optimizer prefers FULL: 30% selectivity) |
| I3 | `ix_product_upper_name` on `Product(UPPER(Name))` | `WHERE UPPER(Name) = 'BOX SMALL 12'` | TABLE ACCESS FULL | INDEX RANGE SCAN |

### 3.3 End

Show `user_indexes` for the schema and index sizes (`user_segments`).

## 4. `10_partitioning.sql`

### 4.1 Horizontal: `Invoice` by month

- Convert with `MODIFY PARTITION BY RANGE (IssueDate) INTERVAL (NUMTOYMINTERVAL(1,'MONTH')) (PARTITION p_before_2024 ...) ONLINE`.
- Local index `ix_invoice_date_loc ON Invoice(IssueDate) LOCAL`.
- Show `user_tab_partitions` (about 36 partitions + `p_before_2024`).
- Pruning plans: one month gives `PARTITION RANGE SINGLE`; a quarter gives `PARTITION RANGE ITERATOR`; no date filter gives `ALL`.

### 4.2 Vertical: `Customer`

| Step | Requirement |
|---|---|
| Table | `CustomerDetails(CustomerId PK/FK, Address, Phone, Email, Note)` |
| Data | copy from `Customer`, then drop the four columns |
| View | `CustomerFull` with the original column order |
| Triggers | INSTEAD OF INSERT (two inserts), UPDATE (two updates), DELETE (details first, then customer) |
| Documentation | relational model of `Customer` before and after (in comments) |

## Requirements

| ID | Statement | Source | Acceptance | Verified by |
|---|---|---|---|---|
| R-01 | `08` MUST generate the volumes in section 2.1 and MUST do nothing on a second run | prompt | row counts; second run prints "already generated" | section 7 |
| R-02 | `08` MUST use set-based inserts with triggers enabled | prompt | no row-by-row loop; D1-D3 and totals filled | review, count checks |
| R-03 | `09` MUST create at least two different index types, each with a plan before and after | assignment 3.2 | plans printed in `results/09_indexes.txt` | review |
| R-04 | At least one query MUST change from TABLE ACCESS FULL to an index access | assignment 3.2 | I1 and I3 plans | section 3.2 |
| R-05 | `Invoice` MUST be range-partitioned by month with automatic partition creation | assignment 3.3 | `user_tab_partitions` lists the partitions | section 4.1, test 1 |
| R-06 | A one-month query MUST show partition pruning | assignment 3.3 | `PARTITION RANGE SINGLE` | test 2 |
| R-07 | `CustomerFull` MUST support INSERT, UPDATE and DELETE through INSTEAD OF triggers | assignment 3.3 | base tables change correctly | tests 3-5 |
| R-08 | `09` and `10` SHOULD be re-runnable | style | second run without unexpected errors | review |

## Tasks

| ID | Covers | Owns (files it may write) | Reads | Depends on | Done when |
|---|---|---|---|---|---|
| K-01 | R-01, R-02 | `queries/08_generate_data.sql` | spec, `01`-`07` | none | counts match section 2.1 |
| K-02 | R-03, R-04, R-08 | `queries/09_indexes.sql` | spec, `01`-`04` | none | before/after plans for I1-I3 |
| K-03 | R-05, R-07, R-08 | `queries/10_partitioning.sql` | spec, `01`, `04` | none | partitions and view exist |
| K-04 | R-05..R-07 (tests) | `queries/11_test_partitioning.sql` | spec | K-03 (names) | each step has its expected result |
| K-05 | integration | `results/` | all | K-01..K-04 | full run passes, only expected errors |

Serialization: K-01 writes data into the shared schema; K-05 runs everything on a clean schema, one task at a time.

## 5. Test plan: `11_test_partitioning.sql`

| # | Action | Expected |
|---|---|---|
| 1 | Insert an invoice dated in a month with no partition | row inserted; a new system-named partition appears in `user_tab_partitions` |
| 2 | Query that month | `PARTITION RANGE SINGLE` |
| 3 | `INSERT INTO CustomerFull (...)` | one row in `Customer`, one in `CustomerDetails` |
| 4 | `UPDATE CustomerFull SET Phone = ...` | `CustomerDetails.Phone` changed |
| 5 | `DELETE FROM CustomerFull WHERE CustomerId = ...` | rows removed from both tables |
| 6 | ROLLBACK | row counts as before (the new partition stays: DDL-like) |

## 6. Documentation content

- 6.1 For each index: query, reason for the type, plan before/after (operation and cost), size.
- 6.2 Relational model before/after for the vertically split table.
- 6.3 Screenshot list: `08` counts, each index plan pair, partition list, pruning plan, view DML test.

## 7. Execution and verification

`./run_all.sh 08_generate_data`, then `09`, `10`, `11`. Check counts, plan operations, and that a second run of `08` does nothing.

## 8. Acceptance checklist

- [ ] `08` generates the volumes above in a reasonable time and refuses to run twice
- [ ] Each index has a before and after plan; at least two distinct types
- [ ] Pruning is visible in the plan (`PARTITION RANGE SINGLE`)
- [ ] `CustomerFull` supports INSERT, UPDATE and DELETE
- [ ] `10` can be re-run (or documents why not)
- [ ] No ORA- errors other than those marked expected
- [ ] Every `R-xx` has evidence (test step, plan or query)

## 9. Open questions

| # | Question | Options | Recommendation | Decision |
|---|---|---|---|---|
| O1 | Keep the bitmap index if the optimizer ignores it at 30% selectivity? | keep and explain / change the query / drop | change the query to a selective combined filter, keep the index | TODO |
| O2 | Which indexes block `MODIFY PARTITION BY`? | drop and recreate / keep | check `user_indexes`, drop only the blocking ones | TODO |

> TODO: add your own questions; the human closes them before the status becomes Approved.

## Changelog

- YYYY-MM-DD: created (Draft)
