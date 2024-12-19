-- Insert New Date to SalesOrderHeader2
DECLARE @BaseOrderDate DATETIME = GETDATE(); -- Today's date as the base OrderDate

INSERT INTO [CompanyX].[Sales].[SalesOrderHeader2]
([RevisionNumber], [OrderDate], [DueDate], [ShipDate], [Status], [OnlineOrderFlag], [SalesOrderNumber], 
[PurchaseOrderNumber], [AccountNumber], [CustomerID], [SalesPersonID], [TerritoryID], [BillToAddressID], [ShipToAddressID], 
[ShipMethodID], [CreditCardID], [CreditCardApprovalCode], [CurrencyRateID], [SubTotal], [TaxAmt], [Freight], [TotalDue], 
[Comment], [rowguid], [ModifiedDate])
VALUES
(
    1,                              -- RevisionNumber
    @BaseOrderDate,                 -- OrderDate (base date)
    DATEADD(DAY, 5, @BaseOrderDate),-- DueDate (OrderDate + 5 days)
    DATEADD(DAY, 2, @BaseOrderDate),-- ShipDate (OrderDate + 2 days)
    5,                              -- Status
    1,                              -- OnlineOrderFlag
    'SO75126',                      -- SalesOrderNumber
    NULL,                           -- PurchaseOrderNumber
    '10-4030-020002',               -- AccountNumber
    20002,                          -- CustomerID
    NULL,                           -- SalesPersonID
    7,                              -- TerritoryID
    14052,                          -- BillToAddressID
    14052,                          -- ShipToAddressID
    2,                              -- ShipMethodID
    10102,                          -- CreditCardID
    'TEST123458',                   -- CreditCardApprovalCode
    NULL,                           -- CurrencyRateID
    700.00,                         -- SubTotal
    56.00,                          -- TaxAmt
    14.00,                          -- Freight
    770.00,                         -- TotalDue
    'Test row with calculated dates', -- Comment
    NEWID(),                        -- Generate a new unique rowguid
    DATEADD(DAY, 2, @BaseOrderDate) -- ModifiedDate (same as ShipDate)
);



-- Step 1: Find the latest date in DimDate
DECLARE @LatestDimDate DATE;
SELECT @LatestDimDate = MAX(CAST(CONCAT([Year], '-', [Month], '-', [Day]) AS DATE))
FROM test.dbo.DimDate;

-- Step 2: Find the latest date in SalesOrderHeader2
DECLARE @LatestSalesDate DATE;
SELECT @LatestSalesDate = MAX(LatestSalesDate)
FROM (
    SELECT MAX([OrderDate]) AS LatestSalesDate FROM [CompanyX].[Sales].[SalesOrderHeader2]
    UNION ALL
    SELECT MAX([DueDate]) FROM [CompanyX].[Sales].[SalesOrderHeader2]
    UNION ALL
    SELECT MAX([ShipDate]) FROM [CompanyX].[Sales].[SalesOrderHeader2]
    UNION ALL
    SELECT MAX([ModifiedDate]) FROM [CompanyX].[Sales].[SalesOrderHeader2]
) AS SalesDates;

-- Step 3: Check if we need to add new dates
IF @LatestSalesDate > @LatestDimDate
BEGIN
    -- Insert missing dates into DimDate
    WITH DateRange AS (
        SELECT DATEADD(DAY, Number, @LatestDimDate) AS CurrentDate
        FROM master.dbo.spt_values
        WHERE Type = 'P'
          AND Number <= DATEDIFF(DAY, @LatestDimDate, @LatestSalesDate)
    )
    INSERT INTO test.dbo.DimDate (Day, Month, Year, Quarter)
    SELECT 
        DAY(CurrentDate) AS Day,
        MONTH(CurrentDate) AS Month,
        YEAR(CurrentDate) AS Year,
        DATEPART(QUARTER, CurrentDate) AS Quarter
    FROM DateRange
    WHERE CurrentDate > @LatestDimDate
    ORDER BY CurrentDate;
END
