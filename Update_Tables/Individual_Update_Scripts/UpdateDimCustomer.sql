INSERT INTO [CompanyX].[Person].[Person2]
([BusinessEntityID], [PersonType], [NameStyle], [Title], [FirstName], [MiddleName], 
 [LastName], [Suffix], [EmailPromotion], [AdditionalContactInfo], [Demographics], 
 [rowguid], [ModifiedDate])
VALUES 
((SELECT MAX([BusinessEntityID]) + 1 FROM [CompanyX].[Person].[Person2]), 'EM', 0, 'Mr.', 'John', 'A.', 'Doe', NULL, 1, NULL, '<IndividualSurvey xmlns="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"><TotalPurchaseYTD>-19.5</TotalPurchaseYTD><DateFirstPurchase>2003-11-17Z</DateFirstPurchase><BirthDate>1971-05-05Z</BirthDate><MaritalStatus>M</MaritalStatus><YearlyIncome>75001-100000</YearlyIncome><Gender>F</Gender><TotalChildren>0</TotalChildren><NumberChildrenAtHome>0</NumberChildrenAtHome><Education>Bachelors </Education><Occupation>Professional</Occupation><HomeOwnerFlag>0</HomeOwnerFlag><NumberCarsOwned>4</NumberCarsOwned><CommuteDistance>10+ Miles</CommuteDistance></IndividualSurvey>', 
 NEWID(), GETDATE());

INSERT INTO [CompanyX].[Sales].[Customer2]
([PersonID], [StoreID], [TerritoryID], [AccountNumber], [rowguid], [ModifiedDate])
VALUES 
((SELECT MAX([BusinessEntityID]) FROM [CompanyX].[Person].[Person2]), 934, 1,
CONCAT('AW', FORMAT((SELECT MAX([BusinessEntityID]) FROM [CompanyX].[Person].[Person2]), '00000000')),
NEWID(), GETDATE());


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

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

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

MERGE INTO test.dbo.DimCustomer AS Target
USING (

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
    ) AS Source
    ON Target.CustomerID = Source.CustomerID

-- Update existing rows with any changes in name or frequency
WHEN MATCHED AND (
    Target.FirstName <> Source.FirstName OR
    Target.MiddleName <> Source.MiddleName OR
    Target.LastName <> Source.LastName OR
    Target.CurrentRecency <> Source.CurrentRecency OR
    Target.CurrentRecencyScore <> Source.CurrentRecencyScore OR
    Target.CurrentTotalFreq <> Source.CurrentTotalFreq OR
    Target.CurrentTotalFreqScore <> Source.CurrentTotalFreqScore OR
    Target.CurrentTotalSpent <> Source.CurrentTotalSpent OR
    Target.TotalSpentScore <> Source.TotalSpentScore
) THEN
    UPDATE SET
        Target.FirstName = Source.FirstName,
        Target.MiddleName = Source.MiddleName,
        Target.LastName = Source.LastName,
        Target.CurrentRecency = Source.CurrentRecency,
        Target.CurrentRecencyScore = Source.CurrentRecencyScore,
        Target.CurrentTotalFreq = Source.CurrentTotalFreq,
        Target.CurrentTotalFreqScore = Source.CurrentTotalFreqScore,
        Target.CurrentTotalSpent = Source.CurrentTotalSpent,
        Target.TotalSpentScore = Source.TotalSpentScore

-- Insert new rows if not already present
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CustomerID, FirstName, MiddleName, LastName,
            CurrentRecency, CurrentRecencyScore, CurrentTotalFreq, CurrentTotalFreqScore,
            CurrentTotalSpent, CurrentTotalSpentScore)
    VALUES (
        Source.CustomerID,
        Source.FirstName,
        Source.MiddleName,
        Source.LastName,
        Source.CurrentRecency,
        Source.CurrentRecencyScore,
        Source.CurrentTotalFreq,
        Source.CurrentTotalFreqScore,
        Source.CurrentTotalSpent,
        Source.TotalSpentScore
    );