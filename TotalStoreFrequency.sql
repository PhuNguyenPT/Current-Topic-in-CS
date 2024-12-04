SELECT 
	soh.CustomerID, 
    s.BusinessEntityID AS StoreID,
    YEAR(soh.OrderDate) AS OrderYear,
    COUNT(soh.SalesOrderID) AS TotalStoreFrequency
FROM 
    [CompanyX].[Sales].[SalesOrderHeader] soh
LEFT JOIN 
    [CompanyX].[Sales].[Store] s 
ON 
    soh.SalesPersonID = s.SalesPersonID
GROUP BY 
    s.BusinessEntityID, YEAR(soh.OrderDate), soh.CustomerID
ORDER BY 
	OrderYear,
	StoreID DESC; 