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
INSERT INTO test.dbo.DimStore (BusinessEntityID, SalesPersonID, StoreName, AddressLine1, AddressLine2, PostalCode, CountryRegionCode, StateName)
SELECT 
    s.BusinessEntityID,
	s.SalesPersonID,
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
ORDER BY
	s.BusinessEntityID;

WITH LatestOrderDates AS (
    SELECT 
        CustomerID,
        MAX(OrderDate) AS LatestOrderDate
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader]
    GROUP BY 
        CustomerID
),

RecencyData AS (
    -- Step 2: Calculate days since the last order for each customer
    SELECT 
        CustomerID,
        DATEDIFF(DAY, LatestOrderDate, GETDATE()) AS Recency
    FROM 
        LatestOrderDates
),

TotalStoreFrequencyData AS (
	SELECT 
		soh.CustomerID, 
		s.BusinessEntityID AS StoreID,
		COUNT(soh.SalesOrderID) AS TotalStoreFrequency
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader] soh
	LEFT JOIN 
		[CompanyX].[Sales].[Store] s 
	ON 
		soh.SalesPersonID = s.SalesPersonID
	GROUP BY 
		s.BusinessEntityID, soh.CustomerID
),

TotalFrequencyData AS (
	SELECT 
		CustomerID,
		COUNT(SalesOrderID) AS TotalFrequency
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader]
	GROUP BY 
		CustomerID
),

TotalSpentData AS (
	SELECT 
		CustomerID,
		SUM(TotalDue) AS TotalSpent
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader]
	GROUP BY 
		CustomerID
),

ChurnScoreData AS (
	SELECT [ChurnScoreID]
			,[ChurnScore]
			,[LowerLimit]
			,[UpperLimit]
			,[ChurnLevel]
	FROM 
		[test].[dbo].[DimChurnScore]
),

TotalFrequencyScoreData AS (
	SELECT [TotalFreqScoreID]
		  ,[Score]
		  ,[LowerLimit]
		  ,[UpperLimit]
	  FROM [test].[dbo].[DimTotalFreqScore]
),

RecencyScoreData AS (
	SELECT [RecencyScoreID]
		  ,[Score]
		  ,[LowerLimit]
		  ,[UpperLimit]
	  FROM [test].[dbo].[DimRecencyScore]
),

TotalSpentScoreData AS (
	SELECT [TotalSpentScoreID]
		  ,[Score]
		  ,[LowerLimit]
		  ,[UpperLimit]
	  FROM [test].[dbo].[DimTotalSpentScore]
)


-- Change FactCustomerChurn
INSERT INTO test.dbo.FactCustomerChurn (
	   [DateID]
      ,[ChurnScore]
      ,[ChurnRatio]
      ,[TotalFrequencyScore]
      ,[RecencyScore]
      ,[TotalSpentScore]
      ,[CustomerID]
      ,[StoreID]
      ,[Recency]
      ,[SalesOrderID]
      ,[SalesPersonID]
      ,[TotalFrequency]
	  ,[TotalStoreFrequency]
      ,[StoreFrequencyScore]
      ,[StoreChurnRatio]
      ,[ProductID]
      ,[SpecialOfferID]
      ,[SubTotal]
      ,[Tax]
      ,[Freight]
      ,[TotalDue]
      ,[TotalSpent])
SELECT 
    (
        SELECT TOP 1 dd.DateID
        FROM test.dbo.DimDate dd
        WHERE DAY(soh.OrderDate) = dd.Day
        AND MONTH(soh.OrderDate) = dd.Month
        AND YEAR(soh.OrderDate) = dd.Year
    ) AS DateID,

	NULL, --[ChurnScore]
	NULL, --[ChurnRatio]
	NULL, --[TotalFrequencyScore]
    NULL, --[RecencyScore]
    NULL, --[TotalSpentScore]

	(
        SELECT TOP 1 dc.CustomerID
        FROM test.dbo.DimCustomer dc
        WHERE soh.CustomerID = dc.CustomerID
    ) AS CustomerID,

	st.StoreID,
	r.Recency,
    soh.SalesOrderID,
    soh.SalesPersonID,
	tf.TotalFrequency,
	tsf.TotalStoreFrequency,

    NULL, --[StoreFrequencyScore]

	NULL, -- ( CAST((TotalFrequencyScore + RecencyScore + TotalSpentScore) / 30.0 AS DECIMAL(5, 2)) AS ChurnRatio ) AS StoreChurnRatio

    sod.ProductID,
    sod.SpecialOfferID,
    soh.SubTotal,
    soh.TaxAmt AS Tax,
    soh.Freight,
    soh.TotalDue,
	ts.TotalSpent

FROM 
    [CompanyX].[Sales].[SalesOrderHeader] AS soh
LEFT JOIN 
    [CompanyX].[Sales].[SalesOrderDetail] AS sod
ON soh.SalesOrderID = sod.SalesOrderID

LEFT JOIN
	(
		SELECT
			CustomerID,
			TotalFrequency
		FROM TotalFrequencyData
	) AS tf
ON soh.CustomerID = tf.CustomerID

LEFT JOIN
	(
        SELECT ds.StoreID,
				ds.SalesPersonID
        FROM test.dbo.DimStore ds
    ) AS st
ON soh.SalesPersonID = st.SalesPersonID

LEFT JOIN
	(
		SELECT
			CustomerID,
			Recency
		FROM 
			RecencyData
	) AS r
ON soh.CustomerID = r.CustomerID

LEFT JOIN
	(
		SELECT 
			CustomerID, 
			StoreID,
			TotalStoreFrequency
		FROM 
			TotalStoreFrequencyData
	) AS tsf
ON soh.CustomerID = tsf.CustomerID

LEFT JOIN
	(
		SELECT
			CustomerID,
			TotalSpent
		FROM 
			TotalSpentData
	) AS ts
ON soh.CustomerID = ts.CustomerID
	
ORDER BY 
    soh.SalesOrderID;