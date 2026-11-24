# Phase 3: Optimization

## What is asked

- Logical optimization: two techniques, each with a trigger and/or procedure.
- Physical optimization: two or more index types, plans before and after.
- Partitioning: one horizontal, one vertical.

## Scripts of this phase

| Script | What it does |
|---|---|
| `queries/06_logical_optimization.sql` | Technique 1 (T6, T7) and technique 2 (P1) |
| `queries/07_test_logical.sql` | Tests for 06 |
| `queries/00b_reset_part3.sql` | Optional undo of 06 |
| `queries/08_generate_data.sql` | Bulk data for meaningful plans |
| `queries/09_indexes.sql` | I1-I3 with plans |
| `queries/10_partitioning.sql` | Horizontal and vertical partitioning |
| `queries/11_test_partitioning.sql` | Tests for 10 |

# Part 1: Logical optimization (06, 07)

## Technique 1: storing derivable values, `Invoice.TotalAmount`

Reports ask for the total of an invoice constantly. Computing `SUM(InvoiceItem.Amount)` each time
is a join plus aggregation. The total is stored on `Invoice`.

- T6 `trg_invoiceitem_total`: COMPOUND trigger on InvoiceItem (insert, update of the relevant
  columns, delete). AFTER EACH ROW collects the affected `InvoiceNo` values (old and new if the
  item moves to another invoice); AFTER STATEMENT recomputes the totals. A plain row trigger
  would read the table it is changing: ORA-04091 (mutating table).
- T7 `trg_invoice_total_guard`: insert sets 0; manual update raises -20010 unless `g_cascade`.

Interaction with part 2: T5 computes `Amount` before the row is stored, so T6 sums correct values.

> TODO: which derived value in your model? Which table holds the details it is built from?

## Technique 2: hard-coded values, Incoterm lookup becomes a CHECK

The lookup `Incoterm` has few, stable rows and is only referenced by `SalesOrder`. Joining it brings
nothing. The FK `fk_so_incoterm` and the table are dropped, and `ck_so_incoterm CHECK (IncotermCode IN ('EXW','FCA'))` is added.

- P1 `p_change_incoterms(p_list)`: changes the allowed set. Parses a comma list, `UPPER(TRIM)`,
  dedupes, validates `^[A-Z0-9]{1,10}$` (-20012, injection guard), refuses to remove values still in
  use (-20011), then adds the new constraint, drops the old one, renames. DDL commits implicitly.

> TODO: which lookup in your model is small and stable enough?

## Tests (07)

insert/update/delete an item and check `TotalAmount`; multi-row statement; move an item between
invoices; manual update -> -20010; invalid incoterm -> ORA-02290; add `DAP` through P1; remove a used
value -> -20011; bad format -> -20012; restore with `EXEC p_change_incoterms('EXW,FCA')`.

# Part 2: Physical optimization, indexes (08, 09)

## Why 08 first

On 5 rows the optimizer always scans the table. About 50000 invoices are generated (set-based
`INSERT ... SELECT ... CONNECT BY LEVEL`, keys prefixed `G-`, guarded against a second run), then
`DBMS_STATS.GATHER_SCHEMA_STATS`.

## I1: B-tree composite, `Invoice(CustomerId, IssueDate)`

Query: invoices of one customer in a date range. Equality column first, range column second.
Plan before: TABLE ACCESS FULL. After: INDEX RANGE SCAN.

## I2: bitmap, `Invoice(CurrencyCode)`

Low cardinality (two values). Good for counts and combined filters in read-mostly data; poor for
concurrent DML because a bitmap locks many rows.

## I3: function-based, `Product(UPPER(Name))`

Query `WHERE UPPER(Name) = 'BOX SMALL'`. A normal index on Name cannot be used because of the function.

> TODO: for each index of yours: query, why this type, plan before, plan after (paste from `results/09_indexes.txt`).

# Part 3: Partitioning (10, 11)

## Horizontal: `Invoice` by month

`ALTER TABLE Invoice MODIFY PARTITION BY RANGE (IssueDate) INTERVAL (NUMTOYMINTERVAL(1,'MONTH')) (PARTITION p_before_2024 VALUES LESS THAN (DATE '2024-01-01')) ONLINE`.
New months get partitions automatically. A query on one month reads one partition: **partition
pruning** (`PARTITION RANGE SINGLE`, or `ITERATOR` for a range). A local index `ix_invoice_date_loc`
is equipartitioned with the table.

## Vertical: `Customer` split into `Customer` + `CustomerDetails`

Rarely used wide columns (Address, Phone, Email, Note) move to `CustomerDetails` (1:1, PK = FK
`CustomerId`). The view `CustomerFull` has the original shape; INSTEAD OF INSERT/UPDATE/DELETE
triggers on it keep old code working.

> TODO: which table and which columns in your model? Draw the relational model before and after.

## Tests (11)

Insert into a month without partition (created automatically); pruning plan; DML through the view; ROLLBACK.

## Overview of all triggers and procedures

See `05_normal_forms_and_triggers.md`.

## Run order

`00_reset` ... `05_tests` -> `06` -> `07` -> `08` -> `09` -> `10` -> `11`
