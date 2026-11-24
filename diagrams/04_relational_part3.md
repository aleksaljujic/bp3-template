# Relational model after part 3 (optimization)

Source: [queries/06_logical_optimization.sql](../queries/06_logical_optimization.sql), [queries/10_partitioning.sql](../queries/10_partitioning.sql). Explanation: [explanations/03_optimization.md](../explanations/03_optimization.md). Assignment: [assignments/03_optimization.md](../assignments/03_optimization.md).

Changes relative to [part 2](03_relational_part2.md):

1. Invoice.TotalAmount added (stored derived value, technique 1).
2. Table Incoterm removed; SalesOrder.IncotermCode is protected by CHECK `ck_so_incoterm` (technique 2, hard-coded values).
3. Customer split vertically: Address, Phone, Email, Note moved to CustomerDetails (1:1); view `CustomerFull` restores the original column set.
4. Invoice horizontally partitioned by month (physical change, not visible as columns).

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
    Customer {
        number CustomerId PK
        varchar2 Name
        varchar2 TaxId
        number CityId FK
    }
    CustomerDetails {
        number CustomerId PK, FK
        varchar2 Address
        varchar2 Phone
        varchar2 Email
        varchar2 Note
    }
    CustomerFull {
        number CustomerId "view"
        varchar2 Name "view"
        varchar2 TaxId "view"
        varchar2 Address "view"
        varchar2 Phone "view"
        varchar2 Email "view"
        varchar2 Note "view"
        number CityId "view"
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
        varchar2 IncotermCode "CHECK ck_so_incoterm EXW or FCA"
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
        date IssueDate "partition key"
        date DueDate
        varchar2 OrderNo FK
        number CityId FK
        varchar2 CurrencyCode FK
        number CustomerId FK "D2"
        varchar2 CustomerName "D2"
        number TotalAmount "derived, new"
    }
    InvoiceItem {
        varchar2 InvoiceNo PK, FK
        number ItemNo PK
        varchar2 ProductCode FK
        number Quantity
        number Price
        number DiscountPct
        date IssueDate "D1"
        number Amount "D3"
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
    Customer ||--o{ Invoice : "CustomerId"
    Customer ||--o| CustomerDetails : "CustomerId 1 to 1"
    Customer ||--|| CustomerFull : "view over Customer + CustomerDetails"
```

## Notes

- **Invoice partitioning**: `PARTITION BY RANGE (IssueDate) INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))` with the initial empty partition `p_before_2024`; Oracle creates one partition per month automatically. `pk_invoice` stays a global index.
- **CustomerDetails**: PK is also FK (`fk_cd_customer`, ON DELETE CASCADE), which makes the relationship 1:1. Writes through `CustomerFull` are handled by INSTEAD OF triggers `trg_customerfull_ins`, `trg_customerfull_upd`, `trg_customerfull_del`.
- **TotalAmount**: kept by `trg_invoiceitem_total` (compound trigger on InvoiceItem), guarded against manual change by `trg_invoice_total_guard`.
- **Incoterm values** before removal: EXW = Ex Works, FCA = Free Carrier. The procedure `p_change_incoterms` rewrites the CHECK.

## Before / after for the changed tables

| Table | Before (part 2) | After (part 3) |
|---|---|---|
| Incoterm | Incoterm(**IncotermCode**, Name) | removed (DROP TABLE) |
| SalesOrder | IncotermCode FK->Incoterm (fk_so_incoterm) | IncotermCode with CHECK ck_so_incoterm IN ('EXW','FCA'), no FK |
| Invoice | no TotalAmount; ordinary table | + TotalAmount NUMBER(16,2) DEFAULT 0 NOT NULL; partitioned by month on IssueDate |
| Customer | CustomerId, Name, TaxId, Address, Phone, Email, Note, CityId | CustomerId, Name, TaxId, CityId |
| CustomerDetails | does not exist | CustomerDetails(**CustomerId FK->Customer**, Address, Phone, Email, Note), 1:1 |
| CustomerFull | does not exist | view: Customer LEFT JOIN CustomerDetails, original column order |
