-- =====================================================================
-- joins_examples.sql
-- JOIN examples for trying out queries (schema from 01_tables.sql, data from 02_data.sql).
-- Uses only part 1 columns, so it works at any stage.
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- =====================================================================

-- 1) Customers with city and country (INNER JOIN through 3 tables)
SELECT c.CustomerId, c.Name AS Customer, ci.Name AS City, co.Name AS Country
FROM Customer c
JOIN City    ci ON ci.CityId      = c.CityId
JOIN Country co ON co.CountryCode = ci.CountryCode
ORDER BY c.CustomerId;

-- 2) Order with items, product and unit
SELECT so.OrderNo, so.OrderDate, c.Name AS Customer, oi.ItemNo, p.Name AS Product,
       oi.Quantity, u.Name AS Unit, oi.Price, oi.Quantity * oi.Price AS Value
FROM SalesOrder so
JOIN Customer  c  ON c.CustomerId  = so.CustomerId
JOIN OrderItem oi ON oi.OrderNo    = so.OrderNo
JOIN Product   p  ON p.ProductCode = oi.ProductCode
JOIN Unit      u  ON u.UnitCode    = p.UnitCode
ORDER BY so.OrderNo, oi.ItemNo;

-- 3) LEFT JOIN: all orders, with the incoterm name when there is one
SELECT so.OrderNo, so.IncotermCode, t.Name AS IncotermName
FROM SalesOrder so
LEFT JOIN Incoterm t ON t.IncotermCode = so.IncotermCode
ORDER BY so.OrderNo;

-- 4) The same table joined twice in different roles (City): customer city vs invoice city
SELECT i.InvoiceNo, c.Name AS Customer,
       cc.Name AS CustomerCity,
       ic.Name AS InvoiceCity
FROM Invoice i
JOIN SalesOrder so ON so.OrderNo    = i.OrderNo
JOIN Customer   c  ON c.CustomerId  = so.CustomerId
JOIN City       cc ON cc.CityId     = c.CityId
JOIN City       ic ON ic.CityId     = i.CityId
ORDER BY i.InvoiceNo;

-- 5) Self join: pairs of different customers located in the same city
--    (returns no rows with the default data; add a customer in an existing city to see it)
SELECT a.Name AS CustomerA, b.Name AS CustomerB, ci.Name AS City
FROM Customer a
JOIN Customer b ON b.CityId = a.CityId AND b.CustomerId > a.CustomerId
JOIN City    ci ON ci.CityId = a.CityId;

-- 6) GROUP BY over a join: invoice value per customer and currency
SELECT c.Name AS Customer, i.CurrencyCode,
       COUNT(DISTINCT i.InvoiceNo) AS Invoices,
       SUM(ii.Quantity * ii.Price * (1 - ii.DiscountPct / 100)) AS Total
FROM Customer c
JOIN SalesOrder  so ON so.CustomerId = c.CustomerId
JOIN Invoice     i  ON i.OrderNo     = so.OrderNo
JOIN InvoiceItem ii ON ii.InvoiceNo  = i.InvoiceNo
GROUP BY c.Name, i.CurrencyCode
HAVING SUM(ii.Quantity * ii.Price) > 0
ORDER BY Total DESC;

-- 7) Anti join: orders that have not been invoiced yet (LEFT JOIN ... IS NULL)
SELECT so.OrderNo, so.OrderDate
FROM SalesOrder so
LEFT JOIN Invoice i ON i.OrderNo = so.OrderNo
WHERE i.InvoiceNo IS NULL;

-- 8) FULL OUTER JOIN: products against order items (never ordered / orphan rows)
SELECT p.ProductCode, p.Name, COUNT(oi.ItemNo) AS TimesOrdered
FROM Product p
FULL OUTER JOIN OrderItem oi ON oi.ProductCode = p.ProductCode
GROUP BY p.ProductCode, p.Name
ORDER BY TimesOrdered DESC, p.ProductCode;
