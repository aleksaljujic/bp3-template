# Phase 1: Database Design

## What is asked

- A separate diagram for each document (order, invoice), not one integral model.
- A relational model with PK and FK marked.

> TODO: paste the diagrams / relational model of your domain here (or link to them).

## Scripts of this phase

| Script | What it does |
|---|---|
| `queries/00_reset.sql` | Drops all objects of the schema so the run starts clean |
| `queries/01_tables.sql` | Creates tables, keys and constraints |
| `queries/02_data.sql` | Inserts a handful of test rows |

## Domain: from order to invoice

A customer (in a city, in a country) places a **sales order** with **order items**
(product, quantity, price). An **invoice** is issued for an order, in a currency, with
**invoice items**. Lookups: Country, City, Unit, Currency, Incoterm.

> TODO: describe your domain in 5-10 sentences: which documents exist, how they relate, which lookups.

## Relational model

Constraint naming: `pk_<table>`, `fk_<abbr>_<target>`, `ck_<abbr>_<col>`.

| Table | Key | Foreign keys |
|---|---|---|
| Country | CountryCode | |
| City | CityId | fk_city_country |
| Customer | CustomerId | fk_customer_city |
| Unit | UnitCode | |
| Product | ProductCode | fk_product_unit |
| Currency | CurrencyCode | |
| Incoterm | IncotermCode | (lookup, removed in part 3) |
| SalesOrder | OrderNo | fk_so_customer, fk_so_incoterm |
| OrderItem | (OrderNo, ItemNo) | fk_oi_order, fk_oi_product |
| Invoice | InvoiceNo | fk_inv_order, fk_inv_city, fk_inv_currency |
| InvoiceItem | (InvoiceNo, ItemNo) | fk_ii_invoice, fk_ii_product |

> TODO: replace with your tables. For each table write one line: what a row represents.

### Constraints

- `OrderItem.Quantity > 0`, `OrderItem.Price > 0` (`ck_oi_quantity`, `ck_oi_price`).
- `InvoiceItem.DiscountPct` between 0 and 100, default 0.
- Composite keys on item tables: the item number is unique only inside the document.

> TODO: list your CHECK / UNIQUE / NOT NULL decisions and why.

## Test data (`02_data.sql`)

2 countries, 2 cities, 2 customers, 2 units, 3 products, currencies EUR and USD, incoterms
EXW and FCA, 2 sales orders (one without incoterm), 2 invoices with 1-2 items each.

> TODO: say why your data set covers the interesting cases (NULL foreign key, two currencies, several items).

## Run order

`00_reset` -> `01_tables` -> `02_data`
