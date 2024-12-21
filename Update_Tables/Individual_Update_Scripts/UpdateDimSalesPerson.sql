-- Merge script to update or insert data in DimSalesPerson
MERGE INTO test.dbo.DimSalesPerson AS Target
USING (
    SELECT DISTINCT
        CASE
            WHEN sp.BusinessEntityID IS NULL THEN -1
            ELSE sp.BusinessEntityID
        END AS SalesPersonID,
        soh.CustomerID,
        p.FirstName,
        p.MiddleName,
        p.LastName,
        ISNULL(spf.SalesPersonFrequency, 0) AS CurrentSalesPersonFrequency
    FROM 
        [CompanyX].[Sales].[SalesPerson] AS sp
    JOIN 
        [CompanyX].[Sales].[SalesOrderHeader] AS soh
        ON sp.BusinessEntityID = soh.SalesPersonID
    JOIN 
        [CompanyX].[Person].[Person] AS p 
        ON sp.BusinessEntityID = p.BusinessEntityID
    LEFT JOIN 
        ( -- Subquery to calculate SalesPersonFrequency
            SELECT 
                SalesPersonID, 
                CustomerID, 
                COUNT(SalesOrderID) AS SalesPersonFrequency
            FROM 
                [CompanyX].[Sales].[SalesOrderHeader]
            GROUP BY 
                SalesPersonID, CustomerID
        ) AS spf
        ON sp.BusinessEntityID = spf.SalesPersonID 
        AND soh.CustomerID = spf.CustomerID
) AS Source
ON Target.SalesPersonID = Source.SalesPersonID
   AND Target.CustomerID = Source.CustomerID
-- Update existing rows with any changes in name or frequency
WHEN MATCHED AND (
    Target.FirstName <> Source.FirstName OR
    Target.MiddleName <> Source.MiddleName OR
    Target.LastName <> Source.LastName OR
    Target.CurrentSalesPersonFrequency <> Source.CurrentSalesPersonFrequency
) THEN
    UPDATE SET
        Target.FirstName = Source.FirstName,
        Target.MiddleName = Source.MiddleName,
        Target.LastName = Source.LastName,
        Target.CurrentSalesPersonFrequency = Source.CurrentSalesPersonFrequency
-- Insert new rows if not already present
WHEN NOT MATCHED BY TARGET THEN
    INSERT (SalesPersonID, CustomerID, FirstName, MiddleName, LastName, CurrentSalesPersonFrequency)
    VALUES (
        Source.SalesPersonID,
        Source.CustomerID,
        Source.FirstName,
        Source.MiddleName,
        Source.LastName,
        Source.CurrentSalesPersonFrequency
    );
