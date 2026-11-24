# Phase 2: Denormalization

## What is asked

- Denormalization breaking 2NF and 3NF, at least one through 2+ levels.
- Triggers that keep the redundant data consistent.
- Before/after models, trigger specification table, tests.

## Scripts of this phase

| Script | What it does |
|---|---|
| `queries/03_denormalization.sql` | Adds the redundant columns and fills them from the source |
| `queries/04_triggers.sql` | Package `pkg_denorm` and triggers T1-T5 |
| `queries/05_tests.sql` | Tests with expected results, ends with ROLLBACK |

## Why denormalize at all

Normalized data needs joins. Copying a value next to where it is read removes a join and speeds
up reads, at the price of redundancy: every copy must be kept in sync, which is the job of the
triggers.

> TODO: name the queries in your domain that become simpler or faster.

## D1: breaking 2NF, issue date on invoice items

`InvoiceItem(InvoiceNo, ItemNo, ..., IssueDate)`. `IssueDate` depends only on `InvoiceNo`,
which is part of the key: a partial dependency, so 2NF is broken. Source: `Invoice.IssueDate`.

- T1 `trg_invoiceitem_date`: fills the copy; manual change is forbidden (-20001).
- T2 `trg_invoice_date_items`: when `Invoice.IssueDate` changes, cascades to items.

> TODO: write the dependency in your model and which attribute is copied where.

## D2: breaking 3NF through 2 levels, customer on invoice

`Invoice -> SalesOrder -> Customer`. `Invoice.CustomerId` and `Invoice.CustomerName` are copied
two levels up. The dependency is transitive: InvoiceNo -> OrderNo -> CustomerId -> Name.

- T3 `trg_invoice_customer`: fills from SalesOrder and Customer; manual change forbidden (-20002).
- T4 `trg_customer_invoice`: when `Customer.Name` changes, cascades to invoices (2 levels).
  Design choice: the cascade is a trigger on the source table, not a trigger per intermediate table.

> TODO: draw the chain for your model and explain why each level needs (or does not need) a trigger.

## D3: breaking 3NF, derived attribute

`InvoiceItem.Amount = ROUND(Quantity * Price * (1 - DiscountPct / 100), 2)`.
It is determined by other non-key attributes: a derived column.

- T5 `trg_invoiceitem_amount`: always recomputes on insert/update.

> TODO: which derived value fits your domain?

## How triggers do not disturb each other: `pkg_denorm`

Cascade triggers update tables that have guard triggers (which forbid manual change). The
package variable `pkg_denorm.g_cascade` tells the guard "this change is legitimate".
Pattern: save old value, set TRUE, do the update, restore the old value (also in the exception handler).
See `04_code_for_defense.md`, section on the flag package.

## Tests (`05_tests.sql`)

| Test | Action | Expected |
|---|---|---|
| Fill on insert | insert item without IssueDate | IssueDate copied from invoice |
| Manual change | update item IssueDate | ERROR ORA-20001 (expected) |
| Cascade | update Invoice.IssueDate | all items follow |
| Customer rename | update Customer.Name | invoices of the customer follow |
| Amount | update Quantity | Amount recomputed |

> TODO: replace with your tests and the actual output (see `results/`).

## What to hand in

Models before and after, trigger table (see `05_normal_forms_and_triggers.md`), screenshots of the tests.

## Run order

`00_reset` -> `01` -> `02` -> `03_denormalization` -> `04_triggers` -> `05_tests`
