-- Use the target database
USE test;

DELETE FROM dbo.FactCustomerChurn;
DELETE FROM dbo.DimCustomer;
DELETE FROM dbo.DimDate;
-- DELETE FROM dbo.DimStore;
DELETE FROM dbo.DimSalesPerson;

--------------------------------------------------------------------------------------

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
--------------------------------------------------------------------------------------


WITH SalesOrder AS (
	SELECT
		soh.SalesOrderID,
		CASE 
            WHEN soh.SalesPersonID IS NULL THEN -1 
            ELSE soh.SalesOrderID 
		END as SalesPersonID,
		soh.SubTotal,
		soh.TaxAmt,
		soh.Freight,
		soh.TotalDue,
		soh.OrderDate,
		soh.CustomerID
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader] AS soh
)
, 
SalesPersonFrequencyData AS (
	SELECT 
		so.CustomerID, 
		so.SalesPersonID,
    COUNT(CASE 
            WHEN so.SalesPersonID IS NULL THEN -1 
            ELSE so.SalesOrderID 
         END) AS SalesPersonFrequency
	FROM 
		SalesOrder so
	GROUP BY 
		so.SalesPersonID, so.CustomerID
),
MetricData AS (
	SELECT 
		CustomerID,
		MAX(OrderDate) AS LatestOrderDate,
		SUM(TotalDue) AS TotalSpent,
		COUNT(SalesOrderID) AS TotalFrequency,
		DATEDIFF(DAY, MAX(OrderDate), GETDATE()) AS Recency
	FROM 
		SalesOrder
	GROUP BY 
		CustomerID
)
,
ChurnRatioData AS (
	SELECT 
		so.OrderDate,
		so.CustomerID,
		CAST(( (tfs.Score + rs.Score + tss.Score + spfs.Score) / 40.000 ) AS DECIMAL(4, 3)) AS ChurnRatio, 
		tfs.Score AS TotalFrequencyScore,
		rs.Score AS RecencyScore,
		tss.Score AS TotalSpentScore,
		md.Recency,
		so.SalesOrderID,
		so.SalesPersonID,
		md.TotalFrequency,
		spf.SalesPersonFrequency,
		spfs.Score AS SalesPersonFrequencyScore,
		CAST(so.SubTotal AS DECIMAL(20, 4)) AS SubTotal,
		CAST(so.TaxAmt AS DECIMAL(20, 4)) AS TaxAmt,
		CAST(so.Freight AS DECIMAL(20, 4)) AS Freight,
		CAST(so.TotalDue AS DECIMAL(20, 4)) AS TotalDue,
		CAST(md.TotalSpent AS DECIMAL(20, 4)) AS TotalSpent
	FROM 
	SalesOrder so
	JOIN
		MetricData md
	ON so.CustomerID = md.CustomerID
	LEFT JOIN
		SalesPersonFrequencyData spf
	ON so.CustomerID = spf.CustomerID AND
		so.SalesPersonID = spf.SalesPersonID

	LEFT JOIN test.dbo.DimTotalFreqScore tfs
	ON tfs.LowerLimit <= md.TotalFrequency AND md.TotalFrequency < tfs.UpperLimit

	LEFT JOIN test.dbo.DimRecencyScore rs
	ON  rs.LowerLimit <= md.Recency AND md.Recency < rs.UpperLimit

	LEFT JOIN test.dbo.DimTotalSpentScore tss
	ON tss.LowerLimit <= CAST(md.TotalSpent AS DECIMAL(20, 4)) AND CAST(md.TotalSpent AS DECIMAL(20, 4)) < tss.UpperLimit

	LEFT JOIN test.dbo.DimSalesPersonFreqScore spfs
	ON spfs.LowerLimit <= spf.SalesPersonFrequency AND spf.SalesPersonFrequency < spfs.UpperLimit
)

-- Change DimCustomer
INSERT INTO test.dbo.DimCustomer (CustomerID, FirstName, MiddleName, LastName,
CurrentRecency, CurrentRecencyScore, CurrentTotalFreq, CurrentTotalFreqScore,
CurrentTotalSpent, CurrentTotalSpentScore)
SELECT 
    c.CustomerID,
    p.FirstName,
    p.MiddleName,
    p.LastName,
	md.recency AS CurrentRecency,
	rs.Score AS CurrentRecencyScore,
	md.TotalFrequency AS CurrentTotalFreq,
	tfs.Score AS CurrentTotalFreqScore,
	CAST(md.TotalSpent AS DECIMAL(20, 4)) AS CurrentTotalSpent,
	tss.Score AS TotalSpentScore
FROM 
    [CompanyX].[Sales].[Customer] AS c
JOIN 
    [CompanyX].[Person].[Person] AS p 
ON 
    c.PersonID = p.BusinessEntityID
JOIN
	MetricData md
	ON c.CustomerID = md.CustomerID

LEFT JOIN test.dbo.DimTotalFreqScore tfs
ON tfs.LowerLimit <= md.TotalFrequency AND md.TotalFrequency < tfs.UpperLimit

LEFT JOIN test.dbo.DimRecencyScore rs
ON  rs.LowerLimit <= md.Recency AND md.Recency < rs.UpperLimit

LEFT JOIN test.dbo.DimTotalSpentScore tss
ON tss.LowerLimit <= CAST(md.TotalSpent AS DECIMAL(20, 4)) AND CAST(md.TotalSpent AS DECIMAL(20, 4)) < tss.UpperLimit;


--------------------------------------------------------------------------------------


-- Change DimSalesPerson
INSERT INTO test.dbo.DimSalesPerson(
    SalesPersonID,
    CustomerID,
    FirstName,
    MiddleName,
    LastName,
    CurrentSalesPersonFrequency,
	CurrentSalesPersonFrequencyScore
)

SELECT DISTINCT
    CASE
        WHEN soh.SalesPersonID IS NULL THEN -1
        ELSE soh.SalesPersonID
    END AS SalesPersonID,
    soh.CustomerID,
    p.FirstName,
    p.MiddleName,
    p.LastName,
    spf.SalesPersonFrequency AS CurrentSalesPersonFrequency,
	spfs.Score AS CurrentSalesPersonFrequencyScore
FROM 
    [CompanyX].[Sales].[SalesOrderHeader] AS soh
LEFT JOIN 
	[CompanyX].[Sales].[SalesPerson] AS sp
    ON sp.BusinessEntityID = soh.SalesPersonID
LEFT JOIN 
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
LEFT JOIN test.dbo.DimSalesPersonFreqScore spfs
	ON spfs.LowerLimit <= spf.SalesPersonFrequency AND spf.SalesPersonFrequency < spfs.UpperLimit;


--------------------------------------------------------------------------------------


-- Change DimStore
-- INSERT INTO test.dbo.DimStore (BusinessEntityID, SalesPersonID, StoreName, AddressLine1, AddressLine2, PostalCode, CountryRegionCode, StateName)
-- SELECT 
--     s.BusinessEntityID,
-- 	s.SalesPersonID,
--     s.Name AS StoreName,
--     a.AddressLine1,
--     a.AddressLine2,
--     a.PostalCode,
--     sp.CountryRegionCode,
--     sp.Name AS StateName
-- FROM 
--     [CompanyX].[Sales].[Store] s 
-- LEFT JOIN 
--     [CompanyX].[Person].[BusinessEntity] be ON s.BusinessEntityID = be.BusinessEntityID
-- LEFT JOIN 
--     [CompanyX].[Person].[BusinessEntityAddress] bea ON be.BusinessEntityID = bea.BusinessEntityID
-- LEFT JOIN 
--     [CompanyX].[Person].[Address] a ON bea.AddressID = a.AddressID
-- LEFT JOIN 
--     [CompanyX].[Person].[StateProvince] sp ON a.StateProvinceID = sp.StateProvinceID
-- ORDER BY
-- 	s.BusinessEntityID;


--------------------------------------------------------------------------------------


WITH SalesOrder AS (
	SELECT
		soh.SalesOrderID,
		CASE 
            WHEN soh.SalesPersonID IS NULL THEN -1 
            ELSE soh.SalesOrderID 
		END as SalesPersonID,
		soh.SubTotal,
		soh.TaxAmt,
		soh.Freight,
		soh.TotalDue,
		soh.OrderDate,
		soh.CustomerID
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader] AS soh
)
, 
SalesPersonFrequencyData AS (
	SELECT 
		so.CustomerID, 
		so.SalesPersonID,
    COUNT(CASE 
            WHEN so.SalesPersonID IS NULL THEN -1 
            ELSE so.SalesOrderID 
         END) AS SalesPersonFrequency
	FROM 
		SalesOrder so
	GROUP BY 
		so.SalesPersonID, so.CustomerID
),
MetricData AS (
	SELECT 
		CustomerID,
		MAX(OrderDate) AS LatestOrderDate,
		SUM(TotalDue) AS TotalSpent,
		COUNT(SalesOrderID) AS TotalFrequency,
		DATEDIFF(DAY, MAX(OrderDate), GETDATE()) AS Recency
	FROM 
		SalesOrder
	GROUP BY 
		CustomerID
)
,
ChurnRatioData AS (
	SELECT 
		so.OrderDate,
		so.CustomerID,
		CAST(( (tfs.Score + rs.Score + tss.Score + spfs.Score) / 40.000 ) AS DECIMAL(4, 3)) AS ChurnRatio, 
		tfs.Score AS TotalFrequencyScore,
		rs.Score AS RecencyScore,
		tss.Score AS TotalSpentScore,
		md.Recency,
		so.SalesOrderID,
		so.SalesPersonID,
		md.TotalFrequency,
		spf.SalesPersonFrequency,
		spfs.Score AS SalesPersonFrequencyScore,
		CAST(so.SubTotal AS DECIMAL(20, 4)) AS SubTotal,
		CAST(so.TaxAmt AS DECIMAL(20, 4)) AS TaxAmt,
		CAST(so.Freight AS DECIMAL(20, 4)) AS Freight,
		CAST(so.TotalDue AS DECIMAL(20, 4)) AS TotalDue,
		CAST(md.TotalSpent AS DECIMAL(20, 4)) AS TotalSpent
	FROM 
	SalesOrder so
	JOIN
		MetricData md
	ON so.CustomerID = md.CustomerID
	LEFT JOIN
		SalesPersonFrequencyData spf
	ON so.CustomerID = spf.CustomerID AND
		so.SalesPersonID = spf.SalesPersonID

	LEFT JOIN test.dbo.DimTotalFreqScore tfs
	ON tfs.LowerLimit <= md.TotalFrequency AND md.TotalFrequency < tfs.UpperLimit

	LEFT JOIN test.dbo.DimRecencyScore rs
	ON  rs.LowerLimit <= md.Recency AND md.Recency < rs.UpperLimit

	LEFT JOIN test.dbo.DimTotalSpentScore tss
	ON tss.LowerLimit <= CAST(md.TotalSpent AS DECIMAL(20, 4)) AND CAST(md.TotalSpent AS DECIMAL(20, 4)) < tss.UpperLimit

	LEFT JOIN test.dbo.DimSalesPersonFreqScore spfs
	ON spfs.LowerLimit <= spf.SalesPersonFrequency AND spf.SalesPersonFrequency < spfs.UpperLimit
)

-- Change FactCustomerChurn
INSERT INTO test.dbo.FactCustomerChurn (
       [DateID],
       [ChurnScore],
       [ChurnRatio],
       [TotalFrequencyScore],
       [RecencyScore],
       [TotalSpentScore],
       [CustomerID],
       [Recency],
       [SalesOrderID],
       [SalesPersonID],
       [TotalFrequency],
       [SalesPersonFrequency],
       [SalesPersonFrequencyScore],
       [SubTotal],
       [Tax],
       [Freight],
       [TotalDue],
       [TotalSpent]
)
SELECT 
	dd.DateID,
	cs.ChurnScore,
	crd.ChurnRatio, 
	crd.TotalFrequencyScore,
	crd.RecencyScore,
	crd.TotalSpentScore,
	dc.CustomerID,
	crd.Recency,
	crd.SalesOrderID,
	crd.SalesPersonID,
	crd.TotalFrequency,
	crd.SalesPersonFrequency,
	crd.SalesPersonFrequencyScore,
	crd.SubTotal,
	crd.TaxAmt,
	crd.Freight,
	crd.TotalDue,
	crd.TotalSpent

FROM 
	ChurnRatioData crd

JOIN test.dbo.DimDate dd
ON DAY(crd.OrderDate) = dd.Day
   AND MONTH(crd.OrderDate) = dd.Month
   AND YEAR(crd.OrderDate) = dd.Year

JOIN test.dbo.DimCustomer dc
ON crd.CustomerID = dc.CustomerID

LEFT JOIN test.dbo.DimChurnScore cs
    ON cs.LowerLimit <= crd.ChurnRatio AND crd.ChurnRatio < cs.UpperLimit

Order By DateID, SalesOrderID;
