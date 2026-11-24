-- =====================================================================
-- 03_denormalization.sql
-- Part 2: adds redundant columns and fills them for existing rows.
-- D1 (2NF), D2 (3NF through 2 levels), D3 (3NF, derived attribute)
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Not re-runnable (ALTER TABLE ADD): run 00_reset.sql and 01..03 again.
-- =====================================================================

-- D1 (2NF): issue date of the invoice in the invoice item
--     InvoiceItem(InvoiceNo, ItemNo): IssueDate depends only on InvoiceNo
--     (part of the primary key)
ALTER TABLE InvoiceItem ADD (IssueDate DATE);
UPDATE InvoiceItem ii
   SET IssueDate = (SELECT i.IssueDate FROM Invoice i WHERE i.InvoiceNo = ii.InvoiceNo);

-- D2 (3NF, 2 levels): customer data on the invoice
--     Invoice -> SalesOrder -> Customer
--     CustomerId is a short-circuit key (new FK to Customer),
--     CustomerName is pre-joined data
ALTER TABLE Invoice ADD (
  CustomerId   NUMBER(10),
  CustomerName VARCHAR2(200)
);
UPDATE Invoice i
   SET (CustomerId, CustomerName) =
       (SELECT c.CustomerId, c.Name
          FROM SalesOrder so
          JOIN Customer c ON c.CustomerId = so.CustomerId
         WHERE so.OrderNo = i.OrderNo);
ALTER TABLE Invoice ADD CONSTRAINT fk_inv_customer FOREIGN KEY (CustomerId) REFERENCES Customer;

-- D3 (3NF, derived attribute): amount of the invoice item
--     (Quantity, Price, DiscountPct) -> Amount
ALTER TABLE InvoiceItem ADD (Amount NUMBER(16,2));
UPDATE InvoiceItem
   SET Amount = ROUND(Quantity * Price * (1 - NVL(DiscountPct, 0) / 100), 2);

COMMIT;
