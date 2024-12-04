SELECT 
    OrderYear,
    SUM(TotalSpent) AS TotalSpentInYear,
	AVG(TotalSpent) AS MeanTotalSpent,
	MIN(TotalSpent) AS MinAmountSpent,
	MAX(TotalSpent) AS MaxAmountSpent
FROM 
    (
        SELECT 
            CustomerID,
            SUM(TotalDue) AS TotalSpent,
            YEAR(OrderDate) AS OrderYear
        FROM 
            [CompanyX].[Sales].[SalesOrderHeader]
        GROUP BY 
            CustomerID,
            YEAR(OrderDate)
    ) AS YearlyData
GROUP BY 
    OrderYear
ORDER BY 
    OrderYear;
