SELECT 
    OrderYear,
    SUM(TotalAmountSpent) AS TotalAmountSpentInYear,
	AVG(TotalAmountSpent) AS MeanTotalAmountSpent,
	MIN(TotalAmountSpent) AS MinAmountSpent,
	MAX(TotalAmountSpent) AS MaxAmountSpent
FROM 
    (
        SELECT 
            CustomerID,
            SUM(TotalDue) AS TotalAmountSpent,
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
