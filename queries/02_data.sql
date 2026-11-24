-- =====================================================================
-- 02_data.sql
-- Part 1: a handful of invented test rows for the example model.
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- =====================================================================

INSERT INTO Country (CountryCode, Name) VALUES ('AAA', 'Exampleland');
INSERT INTO Country (CountryCode, Name) VALUES ('BBB', 'Samplestan');

INSERT INTO City (CityId, Name, CountryCode) VALUES (1, 'Example City', 'AAA');
INSERT INTO City (CityId, Name, CountryCode) VALUES (2, 'Sample Town',  'BBB');

INSERT INTO Customer (CustomerId, Name, TaxId, Address, Phone, Email, Note, CityId)
VALUES (1, 'Example Customer A', 'TAX-0001', '1 Example Street', '+000 111 111', 'a@example.invalid', 'First example customer', 1);
INSERT INTO Customer (CustomerId, Name, TaxId, Address, Phone, Email, Note, CityId)
VALUES (2, 'Example Customer B', 'TAX-0002', '2 Sample Road', '+000 222 222', 'b@example.invalid', NULL, 2);

INSERT INTO Unit (UnitCode, Name) VALUES ('PCS', 'Pieces');
INSERT INTO Unit (UnitCode, Name) VALUES ('KG',  'Kilograms');

INSERT INTO Product (ProductCode, Name, UnitCode) VALUES ('PB-S',  'Paper bag small', 'PCS');
INSERT INTO Product (ProductCode, Name, UnitCode) VALUES ('BOX-M', 'Box medium',      'PCS');
INSERT INTO Product (ProductCode, Name, UnitCode) VALUES ('GLUE',  'Glue',            'KG');

INSERT INTO Currency (CurrencyCode, Name) VALUES ('EUR', 'Euro');
INSERT INTO Currency (CurrencyCode, Name) VALUES ('USD', 'US dollar');

INSERT INTO Incoterm (IncotermCode, Name) VALUES ('EXW', 'Ex Works');
INSERT INTO Incoterm (IncotermCode, Name) VALUES ('FCA', 'Free Carrier');

-- one order without an incoterm, one with EXW
INSERT INTO SalesOrder (OrderNo, OrderDate, CustomerId, IncotermCode)
VALUES ('SO-0001', DATE '2026-01-10', 1, NULL);
INSERT INTO SalesOrder (OrderNo, OrderDate, CustomerId, IncotermCode)
VALUES ('SO-0002', DATE '2026-01-20', 2, 'EXW');

INSERT INTO OrderItem (OrderNo, ItemNo, ProductCode, Quantity, Price) VALUES ('SO-0001', 1, 'PB-S',  1000, 0.06);
INSERT INTO OrderItem (OrderNo, ItemNo, ProductCode, Quantity, Price) VALUES ('SO-0001', 2, 'BOX-M',  200, 0.85);
INSERT INTO OrderItem (OrderNo, ItemNo, ProductCode, Quantity, Price) VALUES ('SO-0002', 1, 'GLUE',    50, 3.20);

INSERT INTO Invoice (InvoiceNo, IssueDate, DueDate, OrderNo, CityId, CurrencyCode)
VALUES ('I-0001', DATE '2026-01-15', DATE '2026-02-14', 'SO-0001', 1, 'EUR');
INSERT INTO Invoice (InvoiceNo, IssueDate, DueDate, OrderNo, CityId, CurrencyCode)
VALUES ('I-0002', DATE '2026-01-25', DATE '2026-02-24', 'SO-0002', 2, 'USD');

INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct) VALUES ('I-0001', 1, 'PB-S',  1000, 0.06, 5);
INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct) VALUES ('I-0001', 2, 'BOX-M',  200, 0.85, 0);
INSERT INTO InvoiceItem (InvoiceNo, ItemNo, ProductCode, Quantity, Price, DiscountPct) VALUES ('I-0002', 1, 'GLUE',    50, 3.20, 10);

COMMIT;
