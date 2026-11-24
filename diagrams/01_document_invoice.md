# Conceptual model: document "Invoice"

Conceptual diagram of one business document: only the entities the invoice touches. The invoice is issued for a sales order (see [Sales order](01_document_sales_order.md)); the customer is reached through the order.

```mermaid
erDiagram
    Invoice {
        varchar2 InvoiceNo PK
        date IssueDate
        date DueDate
    }
    InvoiceItem {
        varchar2 InvoiceNo PK, FK
        number ItemNo PK
        number Quantity
        number Price
        number DiscountPct
    }
    SalesOrder {
        varchar2 OrderNo PK
        date OrderDate
    }
    Customer {
        number CustomerId PK
        varchar2 Name
    }
    City {
        number CityId PK
        varchar2 Name
    }
    Currency {
        varchar2 CurrencyCode PK
        varchar2 Name
    }
    Product {
        varchar2 ProductCode PK
        varchar2 Name
    }
    SalesOrder ||--o{ Invoice : "is invoiced by"
    Customer ||--o{ SalesOrder : "places"
    City ||--o{ Invoice : "place of issue"
    Currency ||--o{ Invoice : "in currency"
    Invoice ||--o{ InvoiceItem : "contains"
    Product ||--o{ InvoiceItem : "invoiced as"
```

## Legend

- `||--o{` : one-to-many (exactly one on the left, zero or many on the right).
- `InvoiceItem` is a weak entity: its key is (InvoiceNo, ItemNo).
- The path Invoice -> SalesOrder -> Customer is the two-level dependency that part 2 shortcuts with redundant columns ([03_relational_part2.md](03_relational_part2.md)).
