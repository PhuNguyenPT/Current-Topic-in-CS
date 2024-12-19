WITH TotalStoreFrequency AS (
    SELECT 
		soh.CustomerID,
        s.BusinessEntityID AS StoreID,
        YEAR(soh.OrderDate) AS OrderYear,
        COUNT(soh.SalesOrderID) AS TotalFrequency
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] soh
    LEFT JOIN 
        [CompanyX].[Sales].[Store] s 
    ON 
        soh.SalesPersonID = s.SalesPersonID
    GROUP BY 
        s.BusinessEntityID, YEAR(soh.OrderDate), soh.CustomerID
)
SELECT 
    OrderYear,
	CustomerID,
    StoreID,
    SUM(TotalFrequency) AS StoreFrequency,
    AVG(TotalFrequency) AS MeanPurchaseCount,
    MIN(TotalFrequency) AS MinOfPurchaseCount,
    MAX(TotalFrequency) AS MaxOfPurchaseCount
FROM 
    TotalStoreFrequency
GROUP BY 
	CustomerID,
    OrderYear, 
	StoreID
ORDER BY
	OrderYear ASC,
	StoreID DESC,
	CustomerID ASC;
