WITH LatestOrderByYear AS (
    SELECT 
        soh.CustomerID,
        soh.SalesOrderID,
        soh.OrderDate,
        soh.TotalDue,
        ROW_NUMBER() OVER (PARTITION BY soh.CustomerID ORDER BY soh.OrderDate DESC) AS RowNum
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] AS soh
    WHERE 
        soh.OrderDate BETWEEN DATEADD(YEAR, -1, DATEFROMPARTS(2014, 12, 31)) AND DATEFROMPARTS(2014, 12, 31)
),
LatestOrderBy9Months AS (
    SELECT 
        soh.CustomerID,
        soh.SalesOrderID,
        soh.OrderDate,
        soh.TotalDue,
        ROW_NUMBER() OVER (PARTITION BY soh.CustomerID ORDER BY soh.OrderDate DESC) AS RowNum
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] AS soh
    WHERE 
        soh.OrderDate BETWEEN DATEADD(MONTH, -9, DATEFROMPARTS(2014, 12, 31)) AND DATEFROMPARTS(2014, 12, 31)
),
LatestOrderBy6Months AS (
    SELECT 
        soh.CustomerID,
        soh.SalesOrderID,
        soh.OrderDate,
        soh.TotalDue,
        ROW_NUMBER() OVER (PARTITION BY soh.CustomerID ORDER BY soh.OrderDate DESC) AS RowNum
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] AS soh
    WHERE 
        soh.OrderDate BETWEEN DATEADD(MONTH, -6, DATEFROMPARTS(2014, 12, 31)) AND DATEFROMPARTS(2014, 12, 31)
),
LatestOrderBy3Months AS (
    SELECT 
        soh.CustomerID,
        soh.SalesOrderID,
        soh.OrderDate,
        soh.TotalDue,
        ROW_NUMBER() OVER (PARTITION BY soh.CustomerID ORDER BY soh.OrderDate DESC) AS RowNum
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] AS soh
    WHERE 
        soh.OrderDate BETWEEN DATEADD(MONTH, -3, DATEFROMPARTS(2014, 12, 31)) AND DATEFROMPARTS(2014, 12, 31)
)
SELECT 
    soh.CustomerID,
    loby.SalesOrderID,
    loby.OrderDate as LatestOrderDateByYear,
	lob9m.OrderDate as LatestOrderDateBy9Months,
	lob6m.OrderDate as LatestOrderDateBy6Months,
	lob3m.OrderDate as LatestOrderDateBy3Months,
    loby.TotalDue
FROM
    (SELECT DISTINCT CustomerID FROM [CompanyX].[Sales].[SalesOrderHeader]) AS soh
LEFT JOIN 
    LatestOrderByYear AS loby ON soh.CustomerID = loby.CustomerID AND loby.RowNum = 1
LEFT JOIN
	LatestOrderBy9Months AS lob9m ON soh.CustomerID = lob9m.CustomerID AND lob9m.RowNum = 1
LEFT JOIN
	LatestOrderBy6Months AS lob6m ON soh.CustomerID = lob6m.CustomerID AND lob6m.RowNum = 1
LEFT JOIN
	LatestOrderBy3Months AS lob3m ON soh.CustomerID = lob3m.CustomerID AND lob3m.RowNum = 1
ORDER BY
    LatestOrderDateByYear,
	LatestOrderDateBy9Months,
	LatestOrderDateBy6Months,
	LatestOrderDateBy3Months DESC;
