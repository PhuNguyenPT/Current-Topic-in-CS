With Query1 AS (
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
),
Query2 AS (
    SELECT 
        OrderYear,
        Quartile,
        MIN(TotalPurchases) AS QuantileValue
    FROM (
        SELECT  
            OrderYear,
            TotalPurchases,
            NTILE(4) OVER (ORDER BY TotalPurchases) AS Quartile
        FROM (
            SELECT 
                CustomerID,
                COUNT(SalesOrderID) AS TotalPurchases,
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
    q1.sum_total_purchase,
    q1.max_total_purchase,
    q1.min_total_purchase,
    q1.max_total_purchase,
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