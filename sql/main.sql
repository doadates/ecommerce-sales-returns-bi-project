CREATE TABLE dim_product(
	ProductID INT AUTO_INCREMENT PRIMARY KEY,
    StockCode VARCHAR(50),
    Description VARCHAR(255)
    );
  

CREATE TABLE dim_date(
	DateKEY INT PRIMARY KEY, 
    Date date,
    Year INT,
    Month INT,
    MonthName VARCHAR(20),
    Day INT
    );
    
CREATE TABLE dim_customer(
	CustomerID INT PRIMARY KEY,
    Country VARCHAR(50)
    );
    
    
CREATE TABLE fact_sales(
	SaleID INT AUTO_INCREMENT PRIMARY KEY ,
	InvoiceNo VARCHAR(100),
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    TotalPrice DECIMAL(10,2),
	IsReturn BIT,
    ProductID INT,
    DateKEY INT,
    CustomerID INT,
    FOREIGN KEY (ProductID) REFERENCES dim_product(ProductID),
	FOREIGN KEY (DateKEY) REFERENCES dim_date(DateKEY),
    FOREIGN KEY (CustomerID) REFERENCES dim_customer(CustomerID)
    
	);
    


CREATE TABLE stg_sales (
  InvoiceNo   VARCHAR(50),
  StockCode   VARCHAR(50),
  Description VARCHAR(255),
  Quantity    INT,
  InvoiceDate DATETIME,
  UnitPrice   DECIMAL(10,2),
  CustomerID  INT,
  Country VARCHAR(100),
  IsReturn VARCHAR(10),
  TotalPrice DECIMAL(10,2),
  Year INT,
  Month INT,
  Day INT
);

 
-- -----------------------CUSTOMER---------------------------------------------------------- 
-- duplicate entry for customer
-- how many customers have more than one country 

SELECT CustomerID, COUNT(DISTINCT Country) AS countrynum
FROM stg_sales
GROUP BY CustomerID
HAVING countrynum > 1
ORDER BY countrynum;

-- so now let’s delete (ignore) the countries with fewer occurrences
-- For each customer (CustomerID):
-- In which country (Country) did they make the most transactions (sales)?
-- Take the country with the highest count and insert it into the target table (dim_customer).

INSERT INTO dim_customer (CustomerID, Country)
SELECT CustomerID, Country
FROM (
  SELECT CustomerID, TRIM(Country) AS Country, COUNT(*) AS cnt,
    ROW_NUMBER() OVER (
      PARTITION BY CustomerID
      ORDER BY COUNT(*) DESC, TRIM(Country)
    ) AS rn
  FROM stg_sales
  WHERE CustomerID IS NOT NULL
  GROUP BY CustomerID, TRIM(Country)
) AS ranked
WHERE rn = 1;


SELECT *
FROM dim_customer;

SELECT *
FROM stg_sales;
-- -------------------PRODUCT-----------------------------------
INSERT INTO dim_product (StockCode, Description)
SELECT DISTINCT StockCode, Description
FROM stg_sales
WHERE StockCode IS NOT NULL AND Description IS NOT NULL;

SELECT *
FROM dim_product;


-- -------------------DATE-----------------------------------



UPDATE stg_sales
SET InvoiceDate = NULL
WHERE InvoiceDate = '0000-00-00 00:00:00';


INSERT INTO dim_date (DateKEY, Date, Year, Month, MonthName, Day)
SELECT
  DATE_FORMAT(d, '%Y%m%d') AS DateKEY,
  d AS Date,
  YEAR(d) AS Year,
  MONTH(d) AS Month,
  MONTHNAME(d) AS MonthName,
  DAY(d) AS Day
FROM (
  SELECT DISTINCT DATE(InvoiceDate) AS d
  FROM stg_sales
  WHERE InvoiceDate > '1000-01-01' OR InvoiceDate IS NULL
) AS unique_dates
WHERE DATE_FORMAT(d, '%Y%m%d') NOT IN (
  SELECT DateKEY FROM dim_date
);

SELECT * FROM stg_sales
WHERE InvoiceDate < '1000-01-01';
-- --------------FACTSALES-------------------------------------

INSERT INTO fact_sales(
InvoiceNo, Quantity, UnitPrice, TotalPrice, IsReturn, ProductID, DateKEY, CustomerID)
SELECT
stg_sales.InvoiceNo, 
stg_sales.Quantity, 
stg_sales.UnitPrice, 
stg_sales.Quantity * stg_sales.UnitPrice as TotalPrice, 
CASE WHEN stg_sales.IsReturn= 'FALSE' THEN 0 ELSE 1 END AS IsReturn,
dim_product.ProductID, 
dim_date.DateKEY, 
dim_customer.CustomerID
FROM stg_sales 
JOIN dim_product
ON stg_sales.StockCode = dim_product.StockCode
JOIN dim_customer
ON stg_sales.CustomerID = dim_customer.CustomerID
JOIN dim_date
ON DATE(stg_sales.InvoiceDate) = dim_date.Date;

select * 
from fact_sales;

-- -------------CONTROL--------------------
-- 1) Are there any NULL/empty foreign keys?
SELECT 
  SUM(CustomerID IS NULL) AS null_cust,
  SUM(ProductID  IS NULL) AS null_prod,
  SUM(DateKey    IS NULL) AS null_date
FROM fact_sales;

-- 2) Check for negative/zero values
SELECT 
  SUM(Quantity <= 0) AS non_pos_qty,
  SUM(UnitPrice < 0) AS neg_price
FROM fact_sales;


-- 3) Is the date range reasonable?
SELECT MIN(DateKey) AS min_date, MAX(DateKey) AS max_date FROM fact_sales;


-- ++++++++++++++++++++++


select * 
from fact_sales
WHERE IsReturn=1;  
