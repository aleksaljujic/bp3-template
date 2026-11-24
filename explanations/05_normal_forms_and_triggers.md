# Normal Forms and Triggers, Explained Simply

> TODO: replace the example model with yours but keep the structure.

# Part 1: Normal forms

## Functional dependency

`A -> B` means: knowing A you know exactly one B. `InvoiceNo -> IssueDate`: one invoice has one date.

## 1NF

Atomic values, no repeating groups, every row identifiable by a key. Example: items are rows in
`InvoiceItem`, not a list inside `Invoice`.

## 2NF

1NF and no **partial dependency**: no non-key attribute depends on only part of a composite key.
Relevant only for composite keys.

Example (D1): `InvoiceItem(InvoiceNo, ItemNo, ProductCode, ..., IssueDate)`. `InvoiceNo -> IssueDate`,
but the key is (InvoiceNo, ItemNo): partial dependency, 2NF broken on purpose.

## 3NF

2NF and no **transitive dependency**: a non-key attribute must not depend on another non-key attribute.

Example 1 (D2, 2 levels): `InvoiceNo -> OrderNo -> CustomerId -> Name`. Storing `CustomerId` and `CustomerName`
on `Invoice` breaks 3NF (OrderNo determines them, they are not part of the key).

Example 2 (D3, derived): `Amount` is computed from `Quantity`, `Price`, `DiscountPct`.

## Summary

| Id | Form broken | Redundant column | Source | Levels |
|---|---|---|---|---|
| D1 | 2NF | InvoiceItem.IssueDate | Invoice.IssueDate | 1 |
| D2 | 3NF | Invoice.CustomerId, CustomerName | Invoice -> SalesOrder -> Customer | 2 |
| D3 | 3NF | InvoiceItem.Amount | Quantity, Price, DiscountPct | derived |

## Why denormalization always needs triggers

A redundant copy can become inconsistent: source changes, copy does not (update anomaly), or somebody
edits the copy. Triggers fill the copy on insert, cascade source changes, and forbid manual edits.

# Part 2: All triggers

## Map

| Id | Trigger | Table | Event | Purpose |
|---|---|---|---|---|
| T1 | trg_invoiceitem_date | InvoiceItem | BEFORE INSERT/UPDATE OF InvoiceNo, IssueDate | fill IssueDate; forbid manual (-20001) |
| T2 | trg_invoice_date_items | Invoice | AFTER UPDATE OF IssueDate | cascade to items |
| T3 | trg_invoice_customer | Invoice | BEFORE INSERT/UPDATE OF OrderNo, CustomerId, CustomerName | fill customer; forbid manual (-20002) |
| T4 | trg_customer_invoice | Customer | AFTER UPDATE OF Name | cascade name to invoices (2 levels) |
| T5 | trg_invoiceitem_amount | InvoiceItem | BEFORE INSERT/UPDATE | compute Amount |
| T6 | trg_invoiceitem_total | InvoiceItem | COMPOUND insert/update/delete | recompute Invoice.TotalAmount |
| T7 | trg_invoice_total_guard | Invoice | BEFORE INSERT/UPDATE OF TotalAmount | insert 0; forbid manual (-20010) |
| T8..T10 | `trg_customerfull_ins`, `trg_customerfull_upd`, `trg_customerfull_del` (INSTEAD OF) | CustomerFull (view) | INSERT / UPDATE / DELETE | route DML to Customer + CustomerDetails (`queries/10_partitioning.sql`) |

> TODO: add the columns "when it fires" and "tables it touches" for your own triggers.

## D1: T1, T2

**T1** fills `IssueDate` from the invoice. If someone changes `IssueDate` manually and `g_cascade` is
FALSE: error -20001. **T2** fires when the invoice date changes, raises the flag and updates the items;
T1 sees the flag and lets the change through. Together: copy is always right, only T2 may change it.

> TODO: one worked example with before/after rows from your data.

## D2: T3, T4

**T3** looks up the customer through the order and writes id and name. **T4** is on the source table
(Customer): one cascade update reaches all invoices through the order (2 levels), so no trigger is
needed on the middle table. Alternative: a chain of cascades (more triggers, more moving parts).

## D3: T5

Always recomputes `Amount`, whatever the client sends. Rounding: `ROUND(..., 2)`.

## Phase 3: T6, T7

**T6** compound trigger: row section collects invoice numbers, statement section recomputes totals
with `NVL(SUM(Amount), 0)` (so an invoice with no items gets 0). Handles delete and moving an item.
**T7** sets 0 on insert and forbids manual changes (-20010), unless the flag is set.
Order on `InvoiceItem`: T5 (before) computes the amount, then T6 (after) sums it.

## Vertical partitioning triggers

INSTEAD OF triggers on `CustomerFull`: insert writes a row to `Customer` and one to `CustomerDetails`;
update updates both; delete removes the details first, then the customer.

## The flag `pkg_denorm.g_cascade`

| Who raises it | Who checks it |
|---|---|
| T2, T4, T6 (around cascade updates) | T1, T3, T7 (guards) |

## Template for a defense answer

1. What is the redundancy (which column, where does the truth live)?
2. Which normal form is broken and why (the dependency)?
3. Which triggers keep it consistent: fill, cascade, forbid?
4. What happens on a manual change (show the error)?
5. What is the cost (write overhead, more code) and what is the gain (no join)?

> TODO: write your own 1-minute answer for each D and each logical technique.
