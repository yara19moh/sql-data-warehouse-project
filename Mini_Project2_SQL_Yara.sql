USE SuperstoreDW;
DROP TABLE IF EXISTS RawSales;

USE SuperstoreDW;
SELECT name FROM sys.tables;

SELECT COUNT(*) FROM Central_Superstore;

USE SuperstoreDW;

-- Dimension: Customer
CREATE TABLE Dim_Customer (
    Customer_Key INT IDENTITY(1,1) PRIMARY KEY,
    Customer_ID NVARCHAR(50),
    Customer_Name NVARCHAR(100),
    Segment NVARCHAR(50)
);

-- Dimension: Product
CREATE TABLE Dim_Product (
    Product_Key INT IDENTITY(1,1) PRIMARY KEY,
    Product_ID NVARCHAR(50),
    Product_Name NVARCHAR(200),
    Category NVARCHAR(50),
    Sub_Category NVARCHAR(50)
);

-- Dimension: Location
CREATE TABLE Dim_Location (
    Location_Key INT IDENTITY(1,1) PRIMARY KEY,
    Country NVARCHAR(50),
    City NVARCHAR(50),
    State NVARCHAR(50),
    Postal_Code INT,
    Region NVARCHAR(50)
);

-- Dimension: Ship Mode
CREATE TABLE Dim_ShipMode (
    ShipMode_Key INT IDENTITY(1,1) PRIMARY KEY,
    Ship_Mode NVARCHAR(50)
);

-- Dimension: Date
CREATE TABLE Dim_Date (
    Date_Key INT IDENTITY(1,1) PRIMARY KEY,
    Full_Date DATE,
    Day INT,
    Month INT,
    MonthName NVARCHAR(20),
    Quarter INT,
    Year INT
);



INSERT INTO Dim_Customer (Customer_ID, Customer_Name, Segment)
SELECT DISTINCT Customer_ID, Customer_Name, Segment
FROM Central_Superstore;

--  Dim_Product
INSERT INTO Dim_Product (Product_ID, Product_Name, Category, Sub_Category)
SELECT DISTINCT Product_ID, Product_Name, Category, Sub_Category
FROM Central_Superstore;

--  Dim_Location
INSERT INTO Dim_Location (Country, City, State, Postal_Code, Region)
SELECT DISTINCT Country, City, State, Postal_Code, Region
FROM Central_Superstore;

--  Dim_ShipMode
INSERT INTO Dim_ShipMode (Ship_Mode)
SELECT DISTINCT Ship_Mode
FROM Central_Superstore;

--  Dim_Date
INSERT INTO Dim_Date (Full_Date, Day, Month, MonthName, Quarter, Year)
SELECT DISTINCT
    d AS Full_Date,
    DAY(d) AS Day,
    MONTH(d) AS Month,
    DATENAME(MONTH, d) AS MonthName,
    DATEPART(QUARTER, d) AS Quarter,
    YEAR(d) AS Year
FROM (
    SELECT Order_Date AS d FROM Central_Superstore
    UNION
    SELECT Ship_Date AS d FROM Central_Superstore
) AS AllDates;


CREATE TABLE Fact_Sales (
    Sale_Key INT IDENTITY(1,1) PRIMARY KEY,
    Row_ID INT,
    Order_ID NVARCHAR(50),
    Customer_Key INT FOREIGN KEY REFERENCES Dim_Customer(Customer_Key),
    Product_Key INT FOREIGN KEY REFERENCES Dim_Product(Product_Key),
    Location_Key INT FOREIGN KEY REFERENCES Dim_Location(Location_Key),
    ShipMode_Key INT FOREIGN KEY REFERENCES Dim_ShipMode(ShipMode_Key),
    OrderDate_Key INT FOREIGN KEY REFERENCES Dim_Date(Date_Key),
    ShipDate_Key INT FOREIGN KEY REFERENCES Dim_Date(Date_Key),
    Sales FLOAT,
    Quantity INT,
    Discount FLOAT,
    Profit FLOAT
);


INSERT INTO Fact_Sales (
    Row_ID, Order_ID, Customer_Key, Product_Key, Location_Key,
    ShipMode_Key, OrderDate_Key, ShipDate_Key, Sales, Quantity, Discount, Profit
)
SELECT
    cs.Row_ID,
    cs.Order_ID,
    dc.Customer_Key,
    dp.Product_Key,
    dl.Location_Key,
    dsm.ShipMode_Key,
    dord.Date_Key AS OrderDate_Key,
    dship.Date_Key AS ShipDate_Key,
    cs.Sales,
    cs.Quantity,
    cs.Discount,
    cs.Profit
FROM Central_Superstore cs
JOIN Dim_Customer dc 
    ON cs.Customer_ID = dc.Customer_ID AND cs.Customer_Name = dc.Customer_Name AND cs.Segment = dc.Segment
JOIN Dim_Product dp 
    ON cs.Product_ID = dp.Product_ID AND cs.Product_Name = dp.Product_Name
JOIN Dim_Location dl 
    ON cs.City = dl.City AND cs.State = dl.State AND cs.Postal_Code = dl.Postal_Code
JOIN Dim_ShipMode dsm 
    ON cs.Ship_Mode = dsm.Ship_Mode
JOIN Dim_Date dord 
    ON cs.Order_Date = dord.Full_Date
JOIN Dim_Date dship 
    ON cs.Ship_Date = dship.Full_Date;

    SELECT COUNT(*) AS FactRowCount FROM Fact_Sales;


    -- Query 1: Total sales and profit by Category
SELECT 
    dp.Category,
    SUM(fs.Sales) AS Total_Sales,
    SUM(fs.Profit) AS Total_Profit,
    ROUND(SUM(fs.Profit) / SUM(fs.Sales) * 100, 2) AS Profit_Margin_Pct
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Key = dp.Product_Key
GROUP BY dp.Category
ORDER BY Total_Profit DESC;

-- Query 2: Top 10 most profitable products (JOIN)
SELECT TOP 10
    dp.Product_Name,
    SUM(fs.Profit) AS Total_Profit
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Key = dp.Product_Key
GROUP BY dp.Product_Name
ORDER BY Total_Profit DESC;

-- Query 3: Products losing money (CASE statement)
SELECT 
    dp.Product_Name,
    SUM(fs.Profit) AS Total_Profit,
    CASE 
        WHEN SUM(fs.Profit) < 0 THEN 'Loss'
        WHEN SUM(fs.Profit) = 0 THEN 'Break-even'
        ELSE 'Profit'
    END AS Profit_Status
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Key = dp.Product_Key
GROUP BY dp.Product_Name
HAVING SUM(fs.Profit) < 0
ORDER BY Total_Profit ASC;

-- Query 4: Profitability by discount level (CASE statement)
SELECT
    CASE
        WHEN Discount = 0 THEN '0% - No Discount'
        WHEN Discount <= 0.2 THEN '1-20%'
        WHEN Discount <= 0.4 THEN '21-40%'
        ELSE '40%+'
    END AS Discount_Range,
    SUM(Sales) AS Total_Sales,
    SUM(Profit) AS Total_Profit
FROM Fact_Sales
GROUP BY 
    CASE
        WHEN Discount = 0 THEN '0% - No Discount'
        WHEN Discount <= 0.2 THEN '1-20%'
        WHEN Discount <= 0.4 THEN '21-40%'
        ELSE '40%+'
    END
ORDER BY Total_Profit DESC;


-- Query 5: Customers ranked by total spending (CTE)
WITH CustomerSpending AS (
    SELECT 
        dc.Customer_Name,
        SUM(fs.Sales) AS Total_Spent,
        SUM(fs.Profit) AS Total_Profit
    FROM Fact_Sales fs
    JOIN Dim_Customer dc ON fs.Customer_Key = dc.Customer_Key
    GROUP BY dc.Customer_Name
)
SELECT TOP 10 *
FROM CustomerSpending
ORDER BY Total_Spent DESC;

-- Query 6: Monthly sales trend (CTE + JOIN)
WITH MonthlySales AS (
    SELECT
        dd.Year,
        dd.Month,
        dd.MonthName,
        SUM(fs.Sales) AS Total_Sales,
        SUM(fs.Profit) AS Total_Profit
    FROM Fact_Sales fs
    JOIN Dim_Date dd ON fs.OrderDate_Key = dd.Date_Key
    GROUP BY dd.Year, dd.Month, dd.MonthName
)
SELECT *
FROM MonthlySales
ORDER BY Year, Month;

-- Query 7: Customer segment performance (JOIN)
SELECT 
    dc.Segment,
    COUNT(DISTINCT fs.Order_ID) AS Total_Orders,
    SUM(fs.Sales) AS Total_Sales,
    SUM(fs.Profit) AS Total_Profit
FROM Fact_Sales fs
JOIN Dim_Customer dc ON fs.Customer_Key = dc.Customer_Key
GROUP BY dc.Segment
ORDER BY Total_Sales DESC;

-- Query 8: Average shipping duration by ship mode (JOIN)
SELECT 
    dsm.Ship_Mode,
    AVG(DATEDIFF(DAY, dord.Full_Date, dship.Full_Date)) AS Avg_Shipping_Days
FROM Fact_Sales fs
JOIN Dim_ShipMode dsm ON fs.ShipMode_Key = dsm.ShipMode_Key
JOIN Dim_Date dord ON fs.OrderDate_Key = dord.Date_Key
JOIN Dim_Date dship ON fs.ShipDate_Key = dship.Date_Key
GROUP BY dsm.Ship_Mode
ORDER BY Avg_Shipping_Days;

-- Query 9 (revised): States with sales above the overall average state sales (subquery)
SELECT 
    dl.State,
    SUM(fs.Sales) AS Total_Sales
FROM Fact_Sales fs
JOIN Dim_Location dl ON fs.Location_Key = dl.Location_Key
GROUP BY dl.State
HAVING SUM(fs.Sales) > (
    SELECT AVG(StateSales) FROM (
        SELECT SUM(fs2.Sales) AS StateSales
        FROM Fact_Sales fs2
        JOIN Dim_Location dl2 ON fs2.Location_Key = dl2.Location_Key
        GROUP BY dl2.State
    ) AS StateAvg
);

-- Query 10: Top selling Sub-Category per Category (subquery)
SELECT dp.Category, dp.Sub_Category, SUM(fs.Sales) AS Total_Sales
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Key = dp.Product_Key
GROUP BY dp.Category, dp.Sub_Category
ORDER BY dp.Category, Total_Sales DESC;

-- Query 11: States with negative average profit (CASE + HAVING)
SELECT 
    dl.State,
    AVG(fs.Profit) AS Avg_Profit,
    CASE WHEN AVG(fs.Profit) < 0 THEN 'Review Needed' ELSE 'Healthy' END AS Status
FROM Fact_Sales fs
JOIN Dim_Location dl ON fs.Location_Key = dl.Location_Key
GROUP BY dl.State
HAVING AVG(fs.Profit) < 0;

-- Query 12: Quarterly sales trend (JOIN)
SELECT 
    dd.Year,
    dd.Quarter,
    SUM(fs.Sales) AS Total_Sales,
    SUM(fs.Profit) AS Total_Profit
FROM Fact_Sales fs
JOIN Dim_Date dd ON fs.OrderDate_Key = dd.Date_Key
GROUP BY dd.Year, dd.Quarter
ORDER BY dd.Year, dd.Quarter;

-- Query 13: Orders with quantity greater than average (subquery)
SELECT fs.Order_ID, fs.Quantity, fs.Sales
FROM Fact_Sales fs
WHERE fs.Quantity > (SELECT AVG(Quantity) FROM Fact_Sales)
ORDER BY fs.Quantity DESC;

-- Query 14: Customer count and total profit per Segment and Category (JOIN x2)
SELECT 
    dc.Segment,
    dp.Category,
    COUNT(DISTINCT dc.Customer_Key) AS Customer_Count,
    SUM(fs.Profit) AS Total_Profit
FROM Fact_Sales fs
JOIN Dim_Customer dc ON fs.Customer_Key = dc.Customer_Key
JOIN Dim_Product dp ON fs.Product_Key = dp.Product_Key
GROUP BY dc.Segment, dp.Category
ORDER BY dc.Segment, Total_Profit DESC;

-- Query 15: Sales performance category using CASE
SELECT 
    fs.Order_ID,
    fs.Sales,
    CASE 
        WHEN fs.Sales < 50 THEN 'Low'
        WHEN fs.Sales BETWEEN 50 AND 200 THEN 'Medium'
        ELSE 'High'
    END AS Sales_Performance_Category
FROM Fact_Sales fs;


-- View: Category profitability summary


SELECT * FROM vw_CategoryProfitability ORDER BY Total_Profit DESC;


-- Stored Procedure: Sales KPIs by year

EXEC sp_GetSalesKPIsByYear @InputYear = 2013;