-- =====================================================================
-- 01_tables.sql
-- Part 1: creates the normalized relational model (tables and constraints).
-- -- TEMPLATE: replace the example model (orders/invoices) with your own domain.
-- Naming: pk_<table>, fk_<abbr>_<target>, ck_<abbr>_<col>.
-- =====================================================================

-- ---------- lookup tables ----------
CREATE TABLE Country (
  CountryCode  VARCHAR2(3)   CONSTRAINT pk_country PRIMARY KEY,
  Name         VARCHAR2(100) NOT NULL
);

CREATE TABLE City (
  CityId       NUMBER(10)    CONSTRAINT pk_city PRIMARY KEY,
  Name         VARCHAR2(100) NOT NULL,
  CountryCode  VARCHAR2(3)   NOT NULL CONSTRAINT fk_city_country REFERENCES Country
);

CREATE TABLE Unit (
  UnitCode     VARCHAR2(10)  CONSTRAINT pk_unit PRIMARY KEY,
  Name         VARCHAR2(50)  NOT NULL
);

CREATE TABLE Currency (
  CurrencyCode VARCHAR2(3)   CONSTRAINT pk_currency PRIMARY KEY,
  Name         VARCHAR2(50)  NOT NULL
);

-- lookup table; removed in part 3 (technique "hard-coded values")
CREATE TABLE Incoterm (
  IncotermCode VARCHAR2(10)  CONSTRAINT pk_incoterm PRIMARY KEY,
  Name         VARCHAR2(100)
);

-- ---------- master data ----------
CREATE TABLE Customer (
  CustomerId   NUMBER(10)    CONSTRAINT pk_customer PRIMARY KEY,
  Name         VARCHAR2(200) NOT NULL,
  TaxId        VARCHAR2(30),
  Address      VARCHAR2(200),
  Phone        VARCHAR2(50),
  Email        VARCHAR2(100),
  Note         VARCHAR2(4000),
  CityId       NUMBER(10)    NOT NULL CONSTRAINT fk_customer_city REFERENCES City
);

CREATE TABLE Product (
  ProductCode  VARCHAR2(30)  CONSTRAINT pk_product PRIMARY KEY,
  Name         VARCHAR2(200) NOT NULL,
  UnitCode     VARCHAR2(10)  NOT NULL CONSTRAINT fk_product_unit REFERENCES Unit
);

-- ---------- orders ----------
CREATE TABLE SalesOrder (
  OrderNo      VARCHAR2(20)  CONSTRAINT pk_salesorder PRIMARY KEY,
  OrderDate    DATE          NOT NULL,
  CustomerId   NUMBER(10)    NOT NULL CONSTRAINT fk_so_customer REFERENCES Customer,
  IncotermCode VARCHAR2(10)  CONSTRAINT fk_so_incoterm REFERENCES Incoterm
);

CREATE TABLE OrderItem (
  OrderNo      VARCHAR2(20)  CONSTRAINT fk_oi_order REFERENCES SalesOrder,
  ItemNo       NUMBER(4),
  ProductCode  VARCHAR2(30)  NOT NULL CONSTRAINT fk_oi_product REFERENCES Product,
  Quantity     NUMBER(14,3)  NOT NULL CONSTRAINT ck_oi_quantity CHECK (Quantity > 0),
  Price        NUMBER(14,5)  NOT NULL CONSTRAINT ck_oi_price CHECK (Price > 0),
  CONSTRAINT pk_orderitem PRIMARY KEY (OrderNo, ItemNo)
);

-- ---------- invoices ----------
CREATE TABLE Invoice (
  InvoiceNo    VARCHAR2(20)  CONSTRAINT pk_invoice PRIMARY KEY,
  IssueDate    DATE          NOT NULL,
  DueDate      DATE          NOT NULL,
  OrderNo      VARCHAR2(20)  NOT NULL CONSTRAINT fk_inv_order REFERENCES SalesOrder,
  CityId       NUMBER(10)    NOT NULL CONSTRAINT fk_inv_city REFERENCES City,
  CurrencyCode VARCHAR2(3)   NOT NULL CONSTRAINT fk_inv_currency REFERENCES Currency
);

CREATE TABLE InvoiceItem (
  InvoiceNo    VARCHAR2(20)  CONSTRAINT fk_ii_invoice REFERENCES Invoice,
  ItemNo       NUMBER(4),
  ProductCode  VARCHAR2(30)  NOT NULL CONSTRAINT fk_ii_product REFERENCES Product,
  Quantity     NUMBER(14,3)  NOT NULL CONSTRAINT ck_ii_quantity CHECK (Quantity > 0),
  Price        NUMBER(14,5)  NOT NULL CONSTRAINT ck_ii_price CHECK (Price > 0),
  DiscountPct  NUMBER(5,2)   DEFAULT 0 NOT NULL
               CONSTRAINT ck_ii_discountpct CHECK (DiscountPct BETWEEN 0 AND 100),
  CONSTRAINT pk_invoiceitem PRIMARY KEY (InvoiceNo, ItemNo)
);
