-- Use the target database
USE test;

-- Update existing records in FactCustomerChurn if there are changes in SalesOrderHeader
UPDATE fcc
SET 
    fcc.DateID = (
        SELECT TOP 1 dd.DateID
        FROM test.dbo.DimDate dd
        WHERE DAY(soh.OrderDate) = dd.Day
        AND MONTH(soh.OrderDate) = dd.Month
        AND YEAR(soh.OrderDate) = dd.Year
    ),
    fcc.CustomerID = (
        SELECT TOP 1 dc.CustomerID
        FROM test.dbo.DimCustomer dc
        WHERE soh.CustomerID = dc.CustomerID
    ),
    fcc.StoreID = (
        SELECT TOP 1 ds.StoreID
        FROM test.dbo.DimStore ds
        WHERE soh.SalesPersonID = ds.SalesPersonID
    ),
    fcc.SalesPersonID = soh.SalesPersonID,
    fcc.SubTotal = soh.SubTotal,
    fcc.Tax = soh.TaxAmt,
    fcc.Freight = soh.Freight,
    fcc.TotalDue = soh.TotalDue
FROM 
    dbo.FactCustomerChurn AS fcc
JOIN 
    [CompanyX].[Sales].[SalesOrderHeader2] AS soh
    ON fcc.SalesOrderID = soh.SalesOrderID
WHERE 
    -- Check for mismatched values
    (
        fcc.DateID <> (
            SELECT TOP 1 dd.DateID
            FROM test.dbo.DimDate dd
            WHERE DAY(soh.OrderDate) = dd.Day
            AND MONTH(soh.OrderDate) = dd.Month
            AND YEAR(soh.OrderDate) = dd.Year
        )
        OR fcc.CustomerID <> (
            SELECT TOP 1 dc.CustomerID
            FROM test.dbo.DimCustomer dc
            WHERE soh.CustomerID = dc.CustomerID
        )
        OR fcc.StoreID <> (
            SELECT TOP 1 ds.StoreID
            FROM test.dbo.DimStore ds
            WHERE soh.SalesPersonID = ds.SalesPersonID
        )
        OR fcc.SalesPersonID <> soh.SalesPersonID
        OR fcc.SubTotal <> soh.SubTotal
        OR fcc.Tax <> soh.TaxAmt
        OR fcc.Freight <> soh.Freight
        OR fcc.TotalDue <> soh.TotalDue
    );




-- Insert new SalesOrderIDs into FactCustomerChurn
INSERT INTO dbo.FactCustomerChurn (
    DateID, 
    CustomerID, 
    StoreID, 
    SalesOrderID, 
    SalesPersonID, 
    ProductID, 
    SpecialOfferID, 
    SubTotal, 
    Tax, 
    Freight, 
    TotalDue
)
SELECT 
    -- Map DateID from DimDate
    (
        SELECT TOP 1 dd.DateID
        FROM test.dbo.DimDate dd
        WHERE DAY(soh.OrderDate) = dd.Day
        AND MONTH(soh.OrderDate) = dd.Month
        AND YEAR(soh.OrderDate) = dd.Year
    ) AS DateID,
    -- Map CustomerID from DimCustomer
    (
        SELECT TOP 1 dc.CustomerID
        FROM test.dbo.DimCustomer dc
        WHERE soh.CustomerID = dc.CustomerID
    ) AS CustomerID,
    -- Map StoreID from DimStore
    (
        SELECT TOP 1 ds.StoreID
        FROM test.dbo.DimStore ds
        WHERE soh.SalesPersonID = ds.SalesPersonID
    ) AS StoreID,
    soh.SalesOrderID,
    soh.SalesPersonID,
    sod.ProductID,
    sod.SpecialOfferID,
    soh.SubTotal,
    soh.TaxAmt AS Tax,
    soh.Freight,
    soh.TotalDue
FROM 
    [CompanyX].[Sales].[SalesOrderHeader2] AS soh
JOIN 
    [CompanyX].[Sales].[SalesOrderDetail] AS sod 
    ON soh.SalesOrderID = sod.SalesOrderID
WHERE 
    soh.SalesOrderID NOT IN (
        SELECT SalesOrderID 
        FROM dbo.FactCustomerChurn
    )
ORDER BY 
    soh.SalesOrderID;
