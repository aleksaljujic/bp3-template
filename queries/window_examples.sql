-- =====================================================================
-- window_examples.sql
-- Analytic (window) function examples on the schema from 01_tables.sql.
-- Uses only part 1 columns (the amount is computed inline), so it works at any stage.
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- =====================================================================

-- 1) ROW_NUMBER / RANK / DENSE_RANK - rank items inside an invoice by amount
SELECT ii.InvoiceNo, ii.ItemNo,
       ROUND(ii.Quantity * ii.Price * (1 - ii.DiscountPct / 100), 2) AS Amount,
       ROW_NUMBER() OVER (PARTITION BY ii.InvoiceNo ORDER BY ii.Quantity * ii.Price DESC) AS RowNo,
       RANK()       OVER (PARTITION BY ii.InvoiceNo ORDER BY ii.Quantity * ii.Price DESC) AS Rnk,
       DENSE_RANK() OVER (PARTITION BY ii.InvoiceNo ORDER BY ii.Quantity * ii.Price DESC) AS DenseRnk
FROM InvoiceItem ii
ORDER BY ii.InvoiceNo, RowNo;

-- 2) Running total and share of the invoice total
SELECT ii.InvoiceNo, ii.ItemNo,
       ROUND(ii.Quantity * ii.Price * (1 - ii.DiscountPct / 100), 2) AS Amount,
       SUM(ii.Quantity * ii.Price * (1 - ii.DiscountPct / 100))
         OVER (PARTITION BY ii.InvoiceNo ORDER BY ii.ItemNo
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal,
       SUM(ii.Quantity * ii.Price * (1 - ii.DiscountPct / 100))
         OVER (PARTITION BY ii.InvoiceNo) AS InvoiceTotal,
       ROUND(100 * RATIO_TO_REPORT(ii.Quantity * ii.Price * (1 - ii.DiscountPct / 100))
                   OVER (PARTITION BY ii.InvoiceNo), 2) AS SharePct
FROM InvoiceItem ii
ORDER BY ii.InvoiceNo, ii.ItemNo;

-- 3) LAG / LEAD - previous and next invoice of the same customer
SELECT so.CustomerId, i.InvoiceNo, i.IssueDate,
       LAG(i.IssueDate)  OVER (PARTITION BY so.CustomerId ORDER BY i.IssueDate) AS PrevIssueDate,
       i.IssueDate - LAG(i.IssueDate) OVER (PARTITION BY so.CustomerId ORDER BY i.IssueDate) AS DaysSincePrev,
       LEAD(i.InvoiceNo) OVER (PARTITION BY so.CustomerId ORDER BY i.IssueDate) AS NextInvoice
FROM Invoice i
JOIN SalesOrder so ON so.OrderNo = i.OrderNo
ORDER BY so.CustomerId, i.IssueDate;

-- 4) Aggregate over a window without GROUP BY (rows are kept):
--    items per product and the order total next to each row
SELECT oi.OrderNo, oi.ItemNo, oi.ProductCode,
       oi.Quantity * oi.Price AS Value,
       SUM(oi.Quantity * oi.Price) OVER (PARTITION BY oi.OrderNo) AS OrderValue,
       COUNT(*)                    OVER (PARTITION BY oi.ProductCode) AS ProductLines,
       AVG(oi.Price)               OVER () AS AvgPriceAll
FROM OrderItem oi
ORDER BY oi.OrderNo, oi.ItemNo;

-- 5) FIRST_VALUE / LAST_VALUE - first and last invoice per currency
SELECT i.CurrencyCode, i.InvoiceNo, i.IssueDate,
       FIRST_VALUE(i.InvoiceNo) OVER (PARTITION BY i.CurrencyCode ORDER BY i.IssueDate
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS FirstInvoice,
       LAST_VALUE(i.InvoiceNo)  OVER (PARTITION BY i.CurrencyCode ORDER BY i.IssueDate
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastInvoice
FROM Invoice i
ORDER BY i.CurrencyCode, i.IssueDate;

-- 6) NTILE - split invoices into 2 buckets by issue date (use more buckets on large data)
SELECT i.InvoiceNo, i.IssueDate,
       NTILE(2) OVER (ORDER BY i.IssueDate) AS Bucket
FROM Invoice i
ORDER BY i.IssueDate;

-- 7) Top-N per group: the most valuable item of every invoice
SELECT InvoiceNo, ItemNo, ProductCode, Value
FROM (
  SELECT ii.InvoiceNo, ii.ItemNo, ii.ProductCode,
         ii.Quantity * ii.Price AS Value,
         ROW_NUMBER() OVER (PARTITION BY ii.InvoiceNo ORDER BY ii.Quantity * ii.Price DESC) AS rn
  FROM InvoiceItem ii
)
WHERE rn = 1
ORDER BY InvoiceNo;

-- 8) Moving average over the current and the previous invoice (sliding window by rows)
SELECT i.InvoiceNo, i.IssueDate, t.InvoiceValue,
       ROUND(AVG(t.InvoiceValue) OVER (ORDER BY i.IssueDate
                                       ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), 2) AS MovingAvg2
FROM Invoice i
JOIN (SELECT InvoiceNo, SUM(Quantity * Price * (1 - DiscountPct / 100)) AS InvoiceValue
        FROM InvoiceItem GROUP BY InvoiceNo) t ON t.InvoiceNo = i.InvoiceNo
ORDER BY i.IssueDate;
