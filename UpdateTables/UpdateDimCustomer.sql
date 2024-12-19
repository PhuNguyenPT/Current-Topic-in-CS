INSERT INTO [CompanyX].[Person].[Person2]
([BusinessEntityID], [PersonType], [NameStyle], [Title], [FirstName], [MiddleName], 
 [LastName], [Suffix], [EmailPromotion], [AdditionalContactInfo], [Demographics], 
 [rowguid], [ModifiedDate])
VALUES 
((SELECT MAX([BusinessEntityID]) + 1 FROM [CompanyX].[Person].[Person2]), 'EM', 0, 'Mr.', 'John', 'A.', 'Doe', NULL, 1, NULL, '<IndividualSurvey xmlns="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"><TotalPurchaseYTD>-19.5</TotalPurchaseYTD><DateFirstPurchase>2003-11-17Z</DateFirstPurchase><BirthDate>1971-05-05Z</BirthDate><MaritalStatus>M</MaritalStatus><YearlyIncome>75001-100000</YearlyIncome><Gender>F</Gender><TotalChildren>0</TotalChildren><NumberChildrenAtHome>0</NumberChildrenAtHome><Education>Bachelors </Education><Occupation>Professional</Occupation><HomeOwnerFlag>0</HomeOwnerFlag><NumberCarsOwned>4</NumberCarsOwned><CommuteDistance>10+ Miles</CommuteDistance></IndividualSurvey>', 
 NEWID(), GETDATE());

INSERT INTO [CompanyX].[Sales].[Customer2]
([PersonID], [StoreID], [TerritoryID], [AccountNumber], [rowguid], [ModifiedDate])
VALUES 
((SELECT MAX([BusinessEntityID]) FROM [CompanyX].[Person].[Person2]), 934, 1,
CONCAT('AW', FORMAT((SELECT MAX([BusinessEntityID]) FROM [CompanyX].[Person].[Person2]), '00000000')),
NEWID(), GETDATE());

 -- Update existing id with new data in Person2
UPDATE [CompanyX].[Person].[Person2]
SET [FirstName] = 'First Name',
    [LastName] = 'Last Name',
    [ModifiedDate] = GETDATE()
WHERE [BusinessEntityID] = 307;

-- Update existing records in DimCustomer
WITH Customer2Data AS (
    SELECT 
        c2.CustomerID,
        p2.FirstName,
        p2.MiddleName,
        p2.LastName
    FROM 
        [CompanyX].[Sales].[Customer2] c2
    LEFT JOIN 
        [CompanyX].[Person].[Person2] p2
    ON 
    c2.PersonID = p2.BusinessEntityID
),
DimCustomerData AS (
    SELECT 
        dc.CustomerID,
        dc.FirstName,
        dc.MiddleName,
        dc.LastName
    FROM 
        test.dbo.DimCustomer dc
)

-- Update rows in DimCustomer that already exist
UPDATE dc
SET 
    dc.FirstName = c2.FirstName,
    dc.MiddleName = c2.MiddleName,
    dc.LastName = c2.LastName
FROM 
    test.dbo.DimCustomer dc
INNER JOIN 
    Customer2Data c2 ON dc.CustomerID = c2.CustomerID;

-- Insert new rows into DimCustomer for CustomerIDs not present
WITH Customer2Data AS (
    SELECT 
        c2.CustomerID,
        p2.FirstName,
        p2.MiddleName,
        p2.LastName
    FROM 
        [CompanyX].[Sales].[Customer2] c2
    LEFT JOIN 
        [CompanyX].[Person].[Person2] p2
    ON 
    c2.PersonID = p2.BusinessEntityID
),
DimCustomerData AS (
    SELECT 
        dc.CustomerID,
        dc.FirstName,
        dc.MiddleName,
        dc.LastName
    FROM 
        test.dbo.DimCustomer dc
)
INSERT INTO test.dbo.DimCustomer (CustomerID, FirstName, MiddleName, LastName)
SELECT 
    c2.CustomerID,
    c2.FirstName,
    c2.MiddleName,
    c2.LastName
FROM 
    Customer2Data c2
LEFT JOIN 
    DimCustomerData dc ON c2.CustomerID = dc.CustomerID
WHERE 
    dc.CustomerID IS NULL;
