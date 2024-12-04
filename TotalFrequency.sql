SELECT 
	CustomerID,
	COUNT(SalesOrderID) AS TotalPurchases,
	YEAR(OrderDate) as OrderYear
FROM 
	[CompanyX].[Sales].[SalesOrderHeader]
GROUP BY 
	CustomerID,
	YEAR(OrderDate)
