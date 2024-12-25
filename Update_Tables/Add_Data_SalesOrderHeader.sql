DELETE FROM [CompanyX].[Sales].[SalesOrderHeader]
WHERE SalesOrderID >= 75124;


DECLARE @LatestDate DATETIME;

-- Get the latest date from the SalesOrderHeader table
SELECT @LatestDate = MAX(LatestDate)
FROM (
    SELECT MAX(OrderDate) AS LatestDate FROM [CompanyX].[Sales].[SalesOrderHeader]
    UNION ALL
    SELECT MAX(DueDate) FROM [CompanyX].[Sales].[SalesOrderHeader]
    UNION ALL
    SELECT MAX(ShipDate) FROM [CompanyX].[Sales].[SalesOrderHeader]
    UNION ALL
    SELECT MAX(ModifiedDate) FROM [CompanyX].[Sales].[SalesOrderHeader]
) AS CombinedDates;

DECLARE @Counter INT = 1;
DECLARE @CurrencyRateID INT = 13532; -- Start CurrencyRateID at 13532
DECLARE @StartingSalesOrderID INT = 75124; -- Starting SalesOrderID for new entries

WHILE @Counter <= 1000
BEGIN
    -- Generate random date intervals
    DECLARE @OrderDate DATETIME = DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 10) + 1, @LatestDate); -- Randomly add 1 to 10 days to @LatestDate
    DECLARE @DueDate DATETIME = DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 5) + 3, @OrderDate);      -- Randomly add 3 to 8 days to @OrderDate
    DECLARE @ShipDate DATETIME = DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 4) + 1, @OrderDate);     -- Randomly add 1 to 4 days to @OrderDate
    DECLARE @ModifiedDate DATETIME = @ShipDate;                                              -- ModifiedDate = ShipDate
    DECLARE @Status INT = 5 + ABS(CHECKSUM(NEWID()) % 2);                                    -- Randomly 5 or 6

    -- Random SalesPersonID
    DECLARE @SalesPersonID INT = (
        SELECT TOP 1 [BusinessEntityID] 
        FROM [CompanyX].[Sales].[SalesPerson]
--		(
--            SELECT [BusinessEntityID] FROM [CompanyX].[Sales].[SalesPerson]
--            UNION ALL
--            SELECT -1 AS [BusinessEntityID] -- Include -1 in the random selection
--       ) AS CombinedSalesPerson
        ORDER BY NEWID()
    );

    -- Determine OnlineOrderFlag based on SalesPersonID
    DECLARE @OnlineOrderFlag BIT = CASE WHEN @SalesPersonID = -1 THEN 1 ELSE 0 END;

    -- Random CustomerID
    DECLARE @CustomerID INT = (SELECT TOP 1 CustomerID FROM [test].[dbo].[DimCustomer] ORDER BY NEWID());

    -- Match TerritoryID from [Customer] table based on CustomerID
    DECLARE @TerritoryID INT = (
        SELECT TOP 1 TerritoryID
        FROM [CompanyX].[Sales].[Customer]
        WHERE CustomerID = @CustomerID
    );

    -- Match CreditCardID via BusinessEntityID
    DECLARE @PersonID INT = (
        SELECT TOP 1 PersonID
        FROM [CompanyX].[Sales].[Customer]
        WHERE CustomerID = @CustomerID
    );

    DECLARE @CreditCardID INT = (
        SELECT TOP 1 CreditCardID
        FROM [CompanyX].[Sales].[PersonCreditCard]
        WHERE BusinessEntityID = @PersonID
        ORDER BY NEWID()
    );

    -- Determine AddressID based on StoreID or PersonID
    DECLARE @StoreID INT = (
        SELECT TOP 1 StoreID
        FROM [CompanyX].[Sales].[Customer]
        WHERE CustomerID = @CustomerID
    );

    DECLARE @AddressID INT = (
        SELECT TOP 1 AddressID
        FROM [CompanyX].[Person].[BusinessEntityAddress]
        WHERE BusinessEntityID = 
        CASE 
            WHEN @StoreID IS NOT NULL THEN @StoreID
            ELSE @PersonID
        END
    );

    -- Random ShipMethodID between 1 and 5
    DECLARE @ShipMethodID INT = ABS(CHECKSUM(NEWID()) % 5) + 1; -- Random number between 1 and 5

    -- Random SubTotal
    DECLARE @SubTotal MONEY = CAST(ROUND(ABS(CHECKSUM(NEWID())) % 163931.0, 4) AS MONEY); -- Random value up to the current max SubTotal

    -- Random TaxAmt as 5–15% of SubTotal
    DECLARE @TaxAmt MONEY = CAST(ROUND(@SubTotal * (5 + ABS(CHECKSUM(NEWID()) % 11)) / 100.0, 4) AS MONEY);

    -- Random Freight as 1–5% of SubTotal
    DECLARE @Freight MONEY = CAST(ROUND(@SubTotal * (1 + ABS(CHECKSUM(NEWID()) % 5)) / 100.0, 4) AS MONEY);

    -- Calculate TotalDue
    DECLARE @TotalDue MONEY = CAST(ROUND(@SubTotal + @TaxAmt + @Freight, 4) AS MONEY);

	DECLARE @SalesOrderNumber NVARCHAR(20) = CONCAT('SO', @StartingSalesOrderID);

    INSERT INTO [CompanyX].[Sales].[SalesOrderHeader]
    (
        [RevisionNumber],         -- Revision number
        [OrderDate],              -- Order date
        [DueDate],                -- Due date
        [ShipDate],               -- Ship date
        [Status],                 -- Status
        [OnlineOrderFlag],        -- Online order flag
--		[SalesOrderNumber],		  
        [CustomerID],             -- Customer ID (random)
        [SalesPersonID],          -- Salesperson ID (random or -1)
        [TerritoryID],            -- TerritoryID matching CustomerID
        [BillToAddressID],        -- Same AddressID as ShipToAddressID
        [ShipToAddressID],        -- Same AddressID as BillToAddressID
        [ShipMethodID],           -- Random ShipMethodID (1 to 5)
        [CreditCardID],           -- CreditCardID matching PersonID
--        [CurrencyRateID],         -- Incremental CurrencyRateID
        [SubTotal],               -- Random Subtotal
        [TaxAmt],                 -- Random TaxAmt
        [Freight],                -- Random Freight
--        [TotalDue],               -- Sum of SubTotal, TaxAmt, and Freight
        [Comment],                -- Comment or notes
        [rowguid],                -- Unique identifier for the row
        [ModifiedDate]            -- Modified date
    )
    VALUES
    (
        ABS(CHECKSUM(NEWID()) % 10) + 1, -- Random RevisionNumber (1 to 10)
        @OrderDate,                      -- Random incremental [OrderDate]
        @DueDate,                        -- Random incremental [DueDate]
        @ShipDate,                       -- Random incremental [ShipDate]
        @Status,                         -- Random Status (5 or 6)
        @OnlineOrderFlag,                -- OnlineOrderFlag: 1 if SalesPersonID = -1, otherwise 0
--		@SalesOrderNumber,
        @CustomerID,                     -- Random [CustomerID]
        @SalesPersonID,                  -- Random [SalesPersonID] or -1
        @TerritoryID,                    -- TerritoryID matching CustomerID
        @AddressID,                      -- [BillToAddressID] (same as [ShipToAddressID])
        @AddressID,                      -- [ShipToAddressID] (same as [BillToAddressID])
        @ShipMethodID,                   -- Random [ShipMethodID] (1 to 5)
        @CreditCardID,                   -- CreditCardID matching PersonID
--        @CurrencyRateID,                 -- Incremental CurrencyRateID
        @SubTotal,                       -- Random [SubTotal]
        @TaxAmt,                         -- Random [TaxAmt]
        @Freight,                        -- Random [Freight]
--        @TotalDue,                       -- Sum of SubTotal, TaxAmt, and Freight
        NULL,                            -- [Comment]
        NEWID(),                         -- [rowguid]
        @ModifiedDate                    -- [ModifiedDate] = @ShipDate
    );

    -- Increment the CurrencyRateID
    SET @CurrencyRateID = @CurrencyRateID + 1;

    -- Update @LatestDate to ensure dates increment for new orders
    SET @LatestDate = @OrderDate;

    SET @Counter = @Counter + 1;

	SET @StartingSalesOrderID = @StartingSalesOrderID + 1
END;