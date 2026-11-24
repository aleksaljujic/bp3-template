# Relational model after part 2 (denormalization)

Source: [queries/03_denormalization.sql](../queries/03_denormalization.sql), [queries/04_triggers.sql](../queries/04_triggers.sql). Explanation: [explanations/02_denormalization.md](../explanations/02_denormalization.md). Assignment: [assignments/02_denormalization.md](../assignments/02_denormalization.md).

Same model as [part 1](02_relational_part1.md) plus redundant columns, marked in the diagram by a comment: `D1 2NF`, `D2 3NF 2 levels`, `D3 derived`. New foreign key: fk_inv_customer (Invoice.CustomerId -> Customer).

```mermaid
erDiagram
    Country {
        varchar2 CountryCode PK
        varchar2 Name
    }
    City {
        number CityId PK
        varchar2 Name
        varchar2 CountryCode FK
    }
    Unit {
        varchar2 UnitCode PK
        varchar2 Name
    }
    Currency {
        varchar2 CurrencyCode PK
        varchar2 Name
    }
    Incoterm {
        varchar2 IncotermCode PK
        varchar2 Name
    }
    Customer {
        number CustomerId PK
        varchar2 Name
        varchar2 TaxId
        varchar2 Address
        varchar2 Phone
        varchar2 Email
        varchar2 Note
        number CityId FK
    }
    Product {
        varchar2 ProductCode PK
        varchar2 Name
        varchar2 UnitCode FK
    }
    SalesOrder {
        varchar2 OrderNo PK
        date OrderDate
        number CustomerId FK
        varchar2 IncotermCode FK
    }
    OrderItem {
        varchar2 OrderNo PK, FK
        number ItemNo PK
        varchar2 ProductCode FK
        number Quantity
        number Price
    }
    Invoice {
        varchar2 InvoiceNo PK
        date IssueDate
        date DueDate
        varchar2 OrderNo FK
        number CityId FK
        varchar2 CurrencyCode FK
        number CustomerId FK "D2 3NF 2 levels"
        varchar2 CustomerName "D2 3NF 2 levels"
    }
    InvoiceItem {
        varchar2 InvoiceNo PK, FK
        number ItemNo PK
        varchar2 ProductCode FK
        number Quantity
        number Price
        number DiscountPct
        date IssueDate "D1 2NF"
        number Amount "D3 derived"
    }
    Country ||--o{ City : "CountryCode"
    City ||--o{ Customer : "CityId"
    Unit ||--o{ Product : "UnitCode"
    Customer ||--o{ SalesOrder : "CustomerId"
    SalesOrder ||--o{ OrderItem : "OrderNo"
    Product ||--o{ OrderItem : "ProductCode"
    SalesOrder ||--o{ Invoice : "OrderNo"
    City ||--o{ Invoice : "CityId"
    Currency ||--o{ Invoice : "CurrencyCode"
    Invoice ||--o{ InvoiceItem : "InvoiceNo"
    Product ||--o{ InvoiceItem : "ProductCode"
    Incoterm |o--o{ SalesOrder : "IncotermCode"
    Customer ||--o{ Invoice : "CustomerId (D2 shortcut)"
```

## Redundant columns and the triggers that keep them consistent

| Label | Normal form | Column | Source of the value | Trigger(s) |
|---|---|---|---|---|
| D1 | 2NF | InvoiceItem.IssueDate | Invoice.IssueDate | `trg_invoiceitem_date` (T1: fills on insert / invoice change, forbids manual change); `trg_invoice_date_items` (T2: cascades a changed Invoice.IssueDate to the items) |
| D2 | 3NF, 2 levels (Invoice -> SalesOrder -> Customer) | Invoice.CustomerId, Invoice.CustomerName | Customer.CustomerId, Customer.Name via SalesOrder | `trg_invoice_customer` (T3: fills on insert / order change, forbids manual change); `trg_customer_invoice` (T4: cascades a renamed Customer.Name to the invoices of its orders) |
| D3 | 3NF, derived attribute | InvoiceItem.Amount | ROUND(Quantity * Price * (1 - NVL(DiscountPct, 0) / 100), 2) | `trg_invoiceitem_amount` (T5: always recomputed) |

Support: package `pkg_denorm` holds the flag `g_cascade`, TRUE while T2 or T4 changes the copies, so T1 and T3 let the cascade through.
