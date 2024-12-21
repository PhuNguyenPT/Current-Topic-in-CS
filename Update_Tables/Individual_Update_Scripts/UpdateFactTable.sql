--  Update Script for FactCustomerChurn
USE test;
------------------------------------------------------------------------------------------------------
WITH SalesOrder AS (
	SELECT
		soh.SalesOrderID,
		CASE 
            WHEN soh.SalesPersonID IS NULL THEN -1 
            ELSE soh.SalesPersonID 
		END AS SalesPersonID,
		soh.SubTotal,
		soh.TaxAmt,
		soh.Freight,
		soh.TotalDue,
		soh.OrderDate,
		soh.CustomerID
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader2] AS soh
), 

SalesPersonData AS (
	SELECT 
		CustomerID,
		SalesPersonID
	FROM
		SalesOrder
	GROUP BY
		CustomerID,
		SalesPersonID
), 

SalesPersonFrequencyData AS (
	SELECT 
		spd.CustomerID, 
		spd.SalesPersonID,
    COUNT(CASE 
            WHEN spd.SalesPersonID IS NULL THEN -1 
            ELSE spd.SalesPersonID 
         END) AS SalesPersonFrequency
	FROM 
		SalesOrder so
	LEFT JOIN
		SalesPersonData spd
	ON	so.CustomerID = spd.CustomerID AND so.SalesPersonID = spd.SalesPersonID
	GROUP BY 
		spd.SalesPersonID, spd.CustomerID
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
),

NewFact AS (
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
)


-- Update existing records in FactCustomerChurn if there are changes in SalesOrderHeader
UPDATE fcc
SET 
    fcc.DateID = nf.DateID,
    fcc.ChurnScore = nf.ChurnScore,
    fcc.ChurnRatio = nf.ChurnRatio,
    fcc.TotalFrequencyScore = nf.TotalFrequencyScore,
    fcc.RecencyScore = nf.RecencyScore,
    fcc.TotalSpentScore = nf.TotalSpentScore,
    fcc.Recency = nf.Recency,
    fcc.CustomerID = nf.CustomerID,
    fcc.SalesPersonID = nf.SalesPersonID,
    fcc.TotalFrequency = nf.TotalFrequency,
    fcc.SalesPersonFrequency = nf.SalesPersonFrequency,
    fcc.SalesPersonFrequencyScore = nf.SalesPersonFrequencyScore,
    fcc.SubTotal = nf.SubTotal,
    fcc.Tax = nf.TaxAmt,
    fcc.Freight = nf.Freight,
    fcc.TotalDue = nf.TotalDue,
    fcc.TotalSpent = nf.TotalSpent

FROM 
    dbo.FactCustomerChurn AS fcc
JOIN 
    NewFact AS nf
    ON fcc.SalesOrderID = nf.SalesOrderID
WHERE 
    -- Check for mismatched values
    (
        fcc.DateID <> nf.DateID
        OR fcc.CustomerID <> nf.CustomerID
        OR fcc.SalesPersonID <> nf.SalesPersonID
        OR fcc.SubTotal <> nf.SubTotal
        OR fcc.Tax <> nf.TaxAmt
        OR fcc.Freight <> nf.Freight
        OR fcc.TotalDue <> nf.TotalDue
    );
------------------------------------------------------------------------------------------------------

-- Update FactCustomerChurn with TotalFrequency and TotalSpent

WITH SalesOrder AS (
	SELECT
		soh.SalesOrderID,
		CASE 
            WHEN soh.SalesPersonID IS NULL THEN -1 
            ELSE soh.SalesPersonID 
		END AS SalesPersonID,
		soh.SubTotal,
		soh.TaxAmt,
		soh.Freight,
		soh.TotalDue,
		soh.OrderDate,
		soh.CustomerID
	FROM 
		[CompanyX].[Sales].[SalesOrderHeader2] AS soh
), 

SalesPersonData AS (
	SELECT 
		CustomerID,
		SalesPersonID
	FROM
		SalesOrder
	GROUP BY
		CustomerID,
		SalesPersonID
), 

SalesPersonFrequencyData AS (
	SELECT 
		spd.CustomerID, 
		spd.SalesPersonID,
    COUNT(CASE 
            WHEN spd.SalesPersonID IS NULL THEN -1 
            ELSE spd.SalesPersonID 
         END) AS SalesPersonFrequency
	FROM 
		SalesOrder so
	LEFT JOIN
		SalesPersonData spd
	ON	so.CustomerID = spd.CustomerID AND so.SalesPersonID = spd.SalesPersonID
	GROUP BY 
		spd.SalesPersonID, spd.CustomerID
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
),

NewFact AS (
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

    LEFT JOIN test.dbo.DimDate dd
    ON DAY(crd.OrderDate) = dd.Day
    AND MONTH(crd.OrderDate) = dd.Month
    AND YEAR(crd.OrderDate) = dd.Year

    JOIN test.dbo.DimCustomer dc
    ON crd.CustomerID = dc.CustomerID

    LEFT JOIN test.dbo.DimChurnScore cs
    ON cs.LowerLimit <= crd.ChurnRatio AND crd.ChurnRatio < cs.UpperLimit
)



INSERT INTO dbo.FactCustomerChurn (
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
    nf.DateID,
	nf.ChurnScore,
	nf.ChurnRatio, 
	nf.TotalFrequencyScore,
	nf.RecencyScore,
	nf.TotalSpentScore,
	nf.CustomerID,
	nf.Recency,
	nf.SalesOrderID,
	nf.SalesPersonID,
	nf.TotalFrequency,
	nf.SalesPersonFrequency,
	nf.SalesPersonFrequencyScore,
	nf.SubTotal,
	nf.TaxAmt,
	nf.Freight,
	nf.TotalDue,
	nf.TotalSpent
FROM
    NewFact AS nf
WHERE 
    nf.SalesOrderID NOT IN (
        SELECT SalesOrderID 
        FROM dbo.FactCustomerChurn
    )
ORDER BY 
    nf.SalesOrderID;