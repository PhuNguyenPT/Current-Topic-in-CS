SELECT 
	OrderYear,
	SUM(TotalFrequency) AS SumTotalFrequency,
	AVG(TotalFrequency) AS MeanTotalFrequency,
	MIN(TotalFrequency) AS MinTotalFrequency,
	MAX(TotalFrequency) AS MaxTotalFrequency
FROM (
	SELECT 
		CustomerID,
		COUNT(SalesOrderID) AS TotalFrequency,
		YEAR(OrderDate) as OrderYear
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader]
	GROUP BY 
		CustomerID,
		YEAR(OrderDate)
) AS YEARLY_DATA
GROUP BY OrderYear
ORDER BY OrderYear;
