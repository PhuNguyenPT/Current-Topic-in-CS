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
DECLARE @LatestYear INT;

SELECT @LatestYear = YEAR(MAX(LatestDate))
FROM (
    SELECT MAX(OrderDate) AS LatestDate FROM [CompanyX].[Sales].[SalesOrderHeader2]
    UNION ALL
    SELECT MAX(DueDate) FROM [CompanyX].[Sales].[SalesOrderHeader2]
    UNION ALL
    SELECT MAX(ShipDate) FROM [CompanyX].[Sales].[SalesOrderHeader2]
    UNION ALL
    SELECT MAX(ModifiedDate) FROM [CompanyX].[Sales].[SalesOrderHeader2]
) AS CombinedDates;

-- Step 2: Generate the last day of the latest year
DECLARE @LastDayOfYear DATE = DATEFROMPARTS(@LatestYear, 12, 31);

-- Step 3: Find the maximum existing date in DimDate
DECLARE @MaxExistingDate DATE;

SELECT @MaxExistingDate = MAX(DateConstructed)
FROM (
    SELECT DATEFROMPARTS(Year, Month, Day) AS DateConstructed
    FROM test.dbo.DimDate
) AS ExistingDates;

-- Step 4: Insert missing dates into DimDate using a CTE to generate numbers
WITH Numbers AS (
    SELECT 0 AS Number
    UNION ALL
    SELECT Number + 1
    FROM Numbers
    WHERE Number < DATEDIFF(DAY, @MaxExistingDate, @LastDayOfYear)
)

INSERT INTO test.dbo.DimDate (Day, Month, Year, Quarter)
SELECT 
    DAY(CurrentDate) AS Day,         -- Extract day
    MONTH(CurrentDate) AS Month,     -- Extract month
    YEAR(CurrentDate) AS Year,       -- Extract year
    DATEPART(QUARTER, CurrentDate) AS Quarter  -- Extract quarter
FROM (
    SELECT DATEADD(DAY, Number, DATEADD(DAY, 1, @MaxExistingDate)) AS CurrentDate
    FROM Numbers
) AS DateRange
WHERE NOT EXISTS (
    SELECT 1
    FROM test.dbo.DimDate dd
    WHERE dd.Year = YEAR(CurrentDate) AND dd.Month = MONTH(CurrentDate) AND dd.Day = DAY(CurrentDate)
)
AND CurrentDate <= @LastDayOfYear  -- Explicitly ensure the date is not beyond 2024-12-31
OPTION (MAXRECURSION 0);  -- Allow unlimited recursion for large ranges