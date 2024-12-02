WITH LatestPurchase AS (
    SELECT 
        CustomerID,
        MAX(OrderDate) AS LatestOrderDate
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader]
    GROUP BY 
        CustomerID
),
OneYearWindow AS (
    SELECT 
        soh.CustomerID,
        soh.SalesOrderID,
        soh.OrderDate,
        soh.TotalDue,
        ROW_NUMBER() OVER (PARTITION BY soh.CustomerID ORDER BY soh.OrderDate DESC) AS RowNum
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] AS soh
    JOIN 
        LatestPurchase AS lp ON soh.CustomerID = lp.CustomerID
    WHERE 
        soh.OrderDate BETWEEN DATEADD(year, -1, lp.LatestOrderDate) AND lp.LatestOrderDate
)
SELECT 
    CustomerID,
    SalesOrderID,
    OrderDate,
    TotalDue
FROM 
    OneYearWindow
WHERE 
    RowNum = 1
ORDER BY 
    CustomerID;
