-- Insert new data to Store2
INSERT INTO [CompanyX].[Sales].[Store2] 
	([BusinessEntityID], [Name], [SalesPersonID], [Demographics], [rowguid], [ModifiedDate])
VALUES 
	(20777, 
	'New Bike World', 
	280, 
	'<StoreSurvey xmlns="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey">
	<AnnualSales>800000</AnnualSales>
	<AnnualRevenue>80000</AnnualRevenue>
	<BankName>International Security</BankName>
	<BusinessType>BM</BusinessType>
	<YearOpened>1975</YearOpened>
	<Specialty>Touring</Specialty>
	<SquareFeet>19000</SquareFeet>
	<Brands>2</Brands>
	<Internet>T1</Internet>
	<NumberEmployees>18</NumberEmployees>
	</StoreSurvey>',
	NEWID(), 
	GETDATE());

-- Update existing id with new data in Store2
UPDATE [CompanyX].[Sales].[Store2]
SET [Name] = 'New Name', 
    [ModifiedDate] = GETDATE() -- Or specify a specific date, e.g., '2024-12-17 10:00:00'
WHERE [BusinessEntityID] = 1986;


-- Update existing records in DimStore
WITH Store2Data AS (
    SELECT 
        s2.BusinessEntityID,
        s2.SalesPersonID,
        s2.Name AS StoreName,
        a.AddressLine1,
        a.AddressLine2,
        a.PostalCode,
        sp.CountryRegionCode,
        sp.Name AS StateName
    FROM 
        [CompanyX].[Sales].[Store2] s2
    LEFT JOIN 
        [CompanyX].[Person].[BusinessEntity] be ON s.BusinessEntityID = be.BusinessEntityID
    LEFT JOIN 
        [CompanyX].[Person].[BusinessEntityAddress2] bea ON s2.BusinessEntityID = bea.BusinessEntityID
    LEFT JOIN 
        [CompanyX].[Person].[Address2] a ON bea.AddressID = a.AddressID
    LEFT JOIN 
        [CompanyX].[Person].[StateProvince2] sp ON a.StateProvinceID = sp.StateProvinceID
),
DimStoreData AS (
    SELECT 
        dim.BusinessEntityID,
        dim.SalesPersonID,
        dim.StoreName,
        dim.AddressLine1,
        dim.AddressLine2,
        dim.PostalCode,
        dim.CountryRegionCode,
        dim.StateName
    FROM 
        test.dbo.DimStore dim
)

-- Update rows in DimStore that already exist
UPDATE dim
SET 
    dim.SalesPersonID = s2.SalesPersonID,
    dim.StoreName = s2.StoreName,
    dim.AddressLine1 = s2.AddressLine1,
    dim.AddressLine2 = s2.AddressLine2,
    dim.PostalCode = s2.PostalCode,
    dim.CountryRegionCode = s2.CountryRegionCode,
    dim.StateName = s2.StateName
FROM 
    test.dbo.DimStore dim
INNER JOIN 
    Store2Data s2 ON dim.BusinessEntityID = s2.BusinessEntityID;

-- Insert new rows into DimStore for BusinessEntityIDs not present
WITH Store2Data AS (
    SELECT 
        s2.BusinessEntityID,
        s2.SalesPersonID,
        s2.Name AS StoreName,
        a.AddressLine1,
        a.AddressLine2,
        a.PostalCode,
        sp.CountryRegionCode,
        sp.Name AS StateName
    FROM 
        [CompanyX].[Sales].[Store2] s2
    LEFT JOIN 
        [CompanyX].[Person].[BusinessEntity] be ON s.BusinessEntityID = be.BusinessEntityID
    LEFT JOIN 
        [CompanyX].[Person].[BusinessEntityAddress2] bea ON s2.BusinessEntityID = bea.BusinessEntityID
    LEFT JOIN 
        [CompanyX].[Person].[Address2] a ON bea.AddressID = a.AddressID
    LEFT JOIN 
        [CompanyX].[Person].[StateProvince2] sp ON a.StateProvinceID = sp.StateProvinceID
),
DimStoreData AS (
    SELECT 
        dim.BusinessEntityID,
        dim.SalesPersonID,
        dim.StoreName,
        dim.AddressLine1,
        dim.AddressLine2,
        dim.PostalCode,
        dim.CountryRegionCode,
        dim.StateName
    FROM 
        test.dbo.DimStore dim
)
INSERT INTO test.dbo.DimStore (BusinessEntityID, SalesPersonID, StoreName, AddressLine1, AddressLine2, PostalCode, CountryRegionCode, StateName)
SELECT 
    s2.BusinessEntityID,
    s2.SalesPersonID,
    s2.StoreName,
    s2.AddressLine1,
    s2.AddressLine2,
    s2.PostalCode,
    s2.CountryRegionCode,
    s2.StateName
FROM 
    Store2Data s2
LEFT JOIN 
    DimStoreData dim ON s2.BusinessEntityID = dim.BusinessEntityID
WHERE 
    dim.BusinessEntityID IS NULL;
