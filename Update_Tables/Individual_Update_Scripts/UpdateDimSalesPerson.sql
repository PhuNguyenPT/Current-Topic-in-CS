-- Merge script to update or insert data in DimSalesPerson

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
)

MERGE INTO test.dbo.DimSalesPerson AS Target
USING (
    SELECT DISTINCT
        spd.SalesPersonID,
        spd.CustomerID,
        CASE 
            WHEN p.FirstName IS NULL THEN 'Unknown'
            ELSE p.FirstName
        END AS FirstName,
        CASE 
            WHEN p.MiddleName IS NULL THEN 'Unknown'
            ELSE p.MiddleName
        END AS MiddleName,
        CASE 
            WHEN p.LastName IS NULL THEN 'Unknown'
            ELSE p.LastName
        END AS LastName,
        spf.SalesPersonFrequency AS CurrentSalesPersonFrequency,
        spfs.Score AS CurrentSalesPersonFrequencyScore
        FROM 
            SalesPersonData spd

        LEFT JOIN 
            [CompanyX].[Person].[Person] AS p 
        ON spd.SalesPersonID = p.BusinessEntityID

        LEFT JOIN
                SalesPersonFrequencyData spf
        ON spd.CustomerID = spf.CustomerID AND
                spd.SalesPersonID = spf.SalesPersonID

        LEFT JOIN test.dbo.DimSalesPersonFreqScore spfs
        ON spfs.LowerLimit <= spf.SalesPersonFrequency AND spf.SalesPersonFrequency < spfs.UpperLimit
    ) AS Source
    ON Target.SalesPersonID = Source.SalesPersonID
   AND Target.CustomerID = Source.CustomerID

-- Update existing rows with any changes in name or frequency
WHEN MATCHED AND (
    Target.FirstName <> Source.FirstName OR
    Target.MiddleName <> Source.MiddleName OR
    Target.LastName <> Source.LastName OR
    Target.CurrentSalesPersonFrequency <> Source.CurrentSalesPersonFrequency OR
    Target.CurrentSalesPersonFrequencyScore <> Source.CurrentSalesPersonFrequencyScore
) THEN
    UPDATE SET
        Target.FirstName = Source.FirstName,
        Target.MiddleName = Source.MiddleName,
        Target.LastName = Source.LastName,
        Target.CurrentSalesPersonFrequency = Source.CurrentSalesPersonFrequency,
        Target.CurrentSalesPersonFrequencyScore = Source.CurrentSalesPersonFrequencyScore

-- Insert new rows if not already present
WHEN NOT MATCHED BY TARGET THEN
    INSERT (SalesPersonID, CustomerID, FirstName, MiddleName, LastName, CurrentSalesPersonFrequency, CurrentSalesPersonFrequencyScore)
    VALUES (
        Source.SalesPersonID,
        Source.CustomerID,
        Source.FirstName,
        Source.MiddleName,
        Source.LastName,
        Source.CurrentSalesPersonFrequency,
        Source.CurrentSalesPersonFrequencyScore
    );
