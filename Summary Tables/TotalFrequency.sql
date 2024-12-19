SELECT 
	CustomerID,
	COUNT(SalesOrderID) AS TotalFrequency,
	YEAR(OrderDate) as OrderYear
FROM 
	[CompanyX].[Sales].[SalesOrderHeader]
GROUP BY 
	CustomerID,
	YEAR(OrderDate)
