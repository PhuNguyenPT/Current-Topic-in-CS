SELECT 
    soh.CustomerID,
    s.BusinessEntityID AS StoreID,
	st.TerritoryID,
    s.Name AS StoreName,
    COUNT(soh.SalesOrderID) AS PurchaseCount,
    a.AddressLine1,
    a.AddressLine2,
    sp.CountryRegionCode,
    sp.Name AS StateProvinceName,
    adt.AddressTypeID,
    adt.Name AS AddressTypeName
FROM 
    [CompanyX].[Sales].[SalesOrderHeader] soh
LEFT JOIN 
    [CompanyX].[Sales].[Store] s ON soh.SalesPersonID = s.SalesPersonID
LEFT JOIN 
    [CompanyX].[Person].[BusinessEntity] be ON s.BusinessEntityID = be.BusinessEntityID
LEFT JOIN 
    [CompanyX].[Person].[BusinessEntityAddress] bea ON be.BusinessEntityID = bea.BusinessEntityID
LEFT JOIN 
    [CompanyX].[Person].[Address] a ON bea.AddressID = a.AddressID
LEFT JOIN 
    [CompanyX].[Person].[StateProvince] sp ON a.StateProvinceID = sp.StateProvinceID
LEFT JOIN 
    [CompanyX].[Person].[AddressType] adt ON bea.AddressTypeID = adt.AddressTypeID
left join
	[CompanyX].[Sales].[SalesTerritory] st On sp.TerritoryID = st.TerritoryID
GROUP BY 
    soh.CustomerID, 
    s.BusinessEntityID,
    s.Name, 
    a.AddressLine1,
    a.AddressLine2,
    sp.CountryRegionCode,
    sp.Name,
	st.TerritoryID,
    adt.AddressTypeID,
    adt.Name
ORDER BY 
    soh.CustomerID, 
    s.BusinessEntityID;
