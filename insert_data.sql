-- Use the target database
USE test;

-- Insert dates for the range 2011-2014 with incrementing DateID
INSERT INTO test.dbo.DimDate (Day, Month, Year, Quarter)
SELECT 
    DAY(CurrentDate) AS Day,                             -- Extracts only the day
    MONTH(CurrentDate) AS Month,                         -- Extracts the month
    YEAR(CurrentDate) AS Year,                           -- Extracts the year
    DATEPART(QUARTER, CurrentDate) AS Quarter            -- Extracts the quarter
FROM (
    -- Generate all dates between 2011-01-01 and 2014-12-31
    SELECT DATEADD(DAY, Number, '2011-01-01') AS CurrentDate
    FROM master.dbo.spt_values
    WHERE Type = 'P' AND Number <= DATEDIFF(DAY, '2011-01-01', '2014-12-31')
) AS DateRange
ORDER BY CurrentDate;  -- Ensure the dates are in ascending order


-- Change DimCustomer
INSERT INTO test.dbo.DimCustomer (CustomerID, FirstName, MiddleName, LastName)
SELECT 
    c.CustomerID,
    p.FirstName,
    p.MiddleName,
    p.LastName
FROM 
    [CompanyX].[Sales].[Customer] AS c
JOIN 
    [CompanyX].[Person].[Person] AS p 
ON 
    c.PersonID = p.BusinessEntityID;

-- Change DimStore
INSERT INTO test.dbo.DimStore (BusinessEntityID,StoreName, AddressLine1, AddressLine2, PostalCode, CountryRegionCode, StateName)
SELECT 
    s.BusinessEntityID,
    s.Name AS StoreName,
    a.AddressLine1,
    a.AddressLine2,
    a.PostalCode,
    sp.CountryRegionCode,
    sp.Name AS StateName
FROM 
    [CompanyX].[Sales].[Store] s 
LEFT JOIN 
    [CompanyX].[Person].[BusinessEntity] be ON s.BusinessEntityID = be.BusinessEntityID
LEFT JOIN 
    [CompanyX].[Person].[BusinessEntityAddress] bea ON be.BusinessEntityID = bea.BusinessEntityID
LEFT JOIN 
    [CompanyX].[Person].[Address] a ON bea.AddressID = a.AddressID
LEFT JOIN 
    [CompanyX].[Person].[StateProvince] sp ON a.StateProvinceID = sp.StateProvinceID