# Relational model after part 1 (normalized)

Source: [queries/01_tables.sql](../queries/01_tables.sql). Explanation: [explanations/01_database_design.md](../explanations/01_database_design.md). Assignment: [assignments/01_database_design.md](../assignments/01_database_design.md).

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
    }
    InvoiceItem {
        varchar2 InvoiceNo PK, FK
        number ItemNo PK
        varchar2 ProductCode FK
        number Quantity
        number Price
        number DiscountPct
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
```

## Compact notation

PK = primary key, FK->Target = foreign key. Composite keys are in the PK list.

| Table | Columns |
|---|---|
| Country | Country(**CountryCode**, Name) |
| City | City(**CityId**, Name, CountryCode FK->Country) |
| Unit | Unit(**UnitCode**, Name) |
| Currency | Currency(**CurrencyCode**, Name) |
| Incoterm | Incoterm(**IncotermCode**, Name) |
| Customer | Customer(**CustomerId**, Name, TaxId, Address, Phone, Email, Note, CityId FK->City) |
| Product | Product(**ProductCode**, Name, UnitCode FK->Unit) |
| SalesOrder | SalesOrder(**OrderNo**, OrderDate, CustomerId FK->Customer, IncotermCode FK->Incoterm) |
| OrderItem | OrderItem(**OrderNo FK->SalesOrder, ItemNo**, ProductCode FK->Product, Quantity, Price) |
| Invoice | Invoice(**InvoiceNo**, IssueDate, DueDate, OrderNo FK->SalesOrder, CityId FK->City, CurrencyCode FK->Currency) |
| InvoiceItem | InvoiceItem(**InvoiceNo FK->Invoice, ItemNo**, ProductCode FK->Product, Quantity, Price, DiscountPct) |

Check constraints: Quantity > 0 and Price > 0 (OrderItem, InvoiceItem), DiscountPct BETWEEN 0 AND 100.
Optional (nullable) columns: Customer.TaxId, Address, Phone, Email, Note; SalesOrder.IncotermCode; Incoterm.Name.
