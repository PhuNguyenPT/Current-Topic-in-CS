SELECT 
	OrderYear,
	SUM(TotalPurchases) AS sum_total_purchase,
	AVG(TotalPurchases) AS avg_total_purchase,
	MIN(TotalPurchases) AS min_total_purchase,
	MAX(TotalPurchases) AS max_total_purchase
FROM (
	SELECT 
		CustomerID,
		COUNT(SalesOrderID) AS TotalPurchases,
		YEAR(OrderDate) as OrderYear
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader]
	GROUP BY 
		CustomerID,
		YEAR(OrderDate)
) AS YEARLY_DATA
GROUP BY OrderYear
ORDER BY OrderYear;