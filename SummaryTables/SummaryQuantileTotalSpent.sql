WITH Query1 AS (
    SELECT 
        OrderYear,
        SUM(TotalSpent) AS TotalSpentInYear,
        AVG(TotalSpent) AS MeanTotalSpent,
        MIN(TotalSpent) AS MinAmountSpent,
        MAX(TotalSpent) AS MaxAmountSpent
    FROM (
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
),
Query2 AS (
    SELECT 
        OrderYear,
        Quartile,
        MIN(TotalSpent) AS QuantileValue
    FROM (
        SELECT  
            OrderYear,
            TotalSpent,
            NTILE(4) OVER (ORDER BY TotalSpent) AS Quartile
        FROM (
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
    ) AS OrderedNumbers
    GROUP BY 
        Quartile, OrderYear
)
SELECT 
    q2.OrderYear,
    q1.TotalSpentInYear,
    q1.MeanTotalSpent,
    q1.MinAmountSpent,
    q1.MaxAmountSpent,
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
