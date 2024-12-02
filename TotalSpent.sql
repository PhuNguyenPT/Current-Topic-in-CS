SELECT 
    CustomerID,
    SUM(TotalDue) AS TotalAmountSpent,
	YEAR(OrderDate) as OrderYear
FROM 
    [CompanyX].[Sales].[SalesOrderHeader]
GROUP BY 
    CustomerID,
	YEAR(OrderDate)
ORDER BY 
    CustomerID,
	YEAR(OrderDate);
