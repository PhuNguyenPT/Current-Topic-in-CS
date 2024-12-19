With Query1 AS (
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
),
Query2 AS (
    SELECT 
        OrderYear,
        Quartile,
        MIN(TotalFrequency) AS QuantileValue
    FROM (
        SELECT  
            OrderYear,
            TotalFrequency,
            NTILE(4) OVER (ORDER BY TotalFrequency) AS Quartile
        FROM (
            SELECT 
                CustomerID,
                COUNT(SalesOrderID) AS TotalFrequency,
                YEAR(OrderDate) AS OrderYear
            FROM 
                [CompanyX].[Sales].[SalesOrderHeader]
            GROUP BY 
                CustomerID,
                YEAR(OrderDate)
        ) AS YearlyData
    ) AS OrderedNumbers
    GROUP BY 
        Quartile, OrderYear
)
SELECT 
    q2.OrderYear,
    q1.SumTotalFrequency,
    q1.MeanTotalFrequency,
    q1.MinTotalFrequency,
    q1.MaxTotalFrequency,
    q2.Quartile,
    q2.QuantileValue
FROM 
    Query2 q2
RIGHT JOIN 
    Query1 q1
ON 
    q2.OrderYear = q1.OrderYear
ORDER BY 
    q2.OrderYear,
	q2.Quartile;
