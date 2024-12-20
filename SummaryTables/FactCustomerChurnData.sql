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
SELECT 
	dd.DateID,
	--cs.ChurnScore,
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

Order By DateID, SalesOrderID