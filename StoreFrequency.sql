SELECT 
    CustomerID,
    SalesPersonID,
    COUNT(SalesOrderID) AS PurchaseCount
FROM 
    [CompanyX].[Sales].[SalesOrderHeader]
GROUP BY 
    CustomerID, 
    SalesPersonID
ORDER BY 
    CustomerID, 
    SalesPersonID;
