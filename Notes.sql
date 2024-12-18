-- Delete all but 1 row
DELETE FROM [CompanyX].[Sales].[SalesOrderHeader2]
WHERE SalesOrderID NOT IN (
    SELECT TOP 1 SalesOrderID
    FROM [CompanyX].[Sales].[SalesOrderHeader2]
    ORDER BY (SELECT NULL) -- Replace with an actual column if order matters
);

-- Change the SalesOrderHeader2 Row Data
UPDATE [CompanyX].[Sales].[SalesOrderHeader2]
SET 
    CustomerID = CustomerID + 2,
    OrderDate = DATEADD(DAY, 2, OrderDate),
    DueDate = DATEADD(DAY, 2, DueDate),
    ShipDate = DATEADD(DAY, 2, ShipDate),
    SubTotal = SubTotal * 2,
    TaxAmt = TaxAmt * 2,
    Freight = Freight * 2,
    TotalDue = TotalDue * 2,
    ModifiedDate = DATEADD(DAY, 2, ModifiedDate);
