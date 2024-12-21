--- Update Scores---
----------------------------------------------------------------------------

-- Update DimRecencyScore --

WITH LatestOrderDates AS (
    -- Step 1: Extract the latest OrderDate for each CustomerID
    SELECT 
        CustomerID,
        MAX(OrderDate) AS LatestOrderDate
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader2]
    GROUP BY 
        CustomerID
),

DaysSinceLastOrder AS (
    -- Step 2: Calculate days since the last order for each customer
    SELECT 
        CustomerID,
        DATEDIFF(DAY, LatestOrderDate, GETDATE()) AS DaysSinceLastOrder
    FROM 
        LatestOrderDates
),

GlobalMinMax AS (
    -- Step 3: Calculate global min and max OrderDate from the entire SalesOrderHeader2 table
    SELECT 
        MIN(OrderDate) AS GlobalMin,  -- Earliest order date (oldest)
        MAX(OrderDate) AS GlobalMax   -- Latest order date (most recent)
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader2]
),
DateDiffGlobal AS (
	SELECT
		DATEDIFF(DAY, GlobalMin, GETDATE()) AS GlobalMin,
		DATEDIFF(DAY, GlobalMax, GETDATE()) AS GlobalMax
	FROM GlobalMinMax
),
RecencyQuantileData AS (
    -- Step 4: Partition customers into 4 quantiles based on recency (DaysSinceLastOrder)
    SELECT 
        CustomerID,
        DaysSinceLastOrder,
        NTILE(4) OVER (ORDER BY DaysSinceLastOrder ASC) AS Quantile
    FROM 
        DaysSinceLastOrder
),

FilteredRecencyQuantiles AS (
    -- Step 5: Focus only on Quantiles 2 to 4
    SELECT 
        CustomerID,
        DaysSinceLastOrder
    FROM 
        RecencyQuantileData
    WHERE 
        Quantile BETWEEN 2 AND 4  -- Focus on Quantiles 2 to 4
),

RecencyQuantileLimits AS (
    -- Step 6: Calculate Min and Max for DaysSinceLastOrder in Quantiles 2 to 4
    SELECT 
        MIN(DaysSinceLastOrder) AS MinRecencyValue,
        MAX(DaysSinceLastOrder) AS MaxRecencyValue
    FROM FilteredRecencyQuantiles
),
RecencyScoreRanges AS (
    -- Step 7: Calculate the Score ranges for recency based on Quantiles 2 to 4
    SELECT 
        s.Score,
        -- For Score 10, LowerLimit is the smallest DaysSinceLastOrder (most recent)
        CASE 
            WHEN s.Score = 10 THEN (SELECT GlobalMax FROM DateDiffGlobal)
            ELSE r.MinRecencyValue + (r.MaxRecencyValue - r.MinRecencyValue) / 10.0 * (10 - s.Score)
        END AS LowerLimit,

        -- For Score 1, UpperLimit is the largest DaysSinceLastOrder (oldest)
        CASE 
            WHEN s.Score = 1 THEN (SELECT GlobalMin + 1.00 FROM DateDiffGlobal)
            ELSE r.MinRecencyValue + (r.MaxRecencyValue - r.MinRecencyValue) / 10.0 * (10 - (s.Score - 1))
        END AS UpperLimit
    FROM 
        (SELECT 10 AS Score UNION ALL 
         SELECT 9 UNION ALL 
         SELECT 8 UNION ALL 
         SELECT 7 UNION ALL 
         SELECT 6 UNION ALL 
         SELECT 5 UNION ALL 
         SELECT 4 UNION ALL 
         SELECT 3 UNION ALL 
         SELECT 2 UNION ALL 
         SELECT 1) AS s
    CROSS JOIN RecencyQuantileLimits r
),
-- Step 8: Assign unique ID to each score
FinalScoreAssignments AS (
    SELECT 
        Score,
        LowerLimit,
        UpperLimit
    FROM RecencyScoreRanges
)

-- Update the DimRecencyScore table with new calculated values
UPDATE [Test].[dbo].[DimRecencyScore]
SET 
    LowerLimit = RecencyScoreRanges.LowerLimit,
    UpperLimit = RecencyScoreRanges.UpperLimit
FROM 
    RecencyScoreRanges
WHERE 
    [Test].[dbo].[DimRecencyScore].Score = RecencyScoreRanges.Score;

----------------------------------------------------------------------------

-- Update DimSalesPersonFrequencyScore --

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

SalesPersonFreqData AS (
    SELECT 
		spd.CustomerID,
        spd.SalesPersonID,
		COUNT(spd.SalesPersonID) AS SalesPersonFrequency
    FROM 
        SalesOrder AS so
    LEFT JOIN
		SalesPersonData spd
	ON	so.CustomerID = spd.CustomerID AND so.SalesPersonID = spd.SalesPersonID
    GROUP BY 
        spd.SalesPersonID, spd.CustomerID
),

GlobalMinMax AS (
    -- Step 3: Calculate global min and max OrderDate from the entire SalesOrderHeader2 table
    SELECT 
        MIN(SalesPersonFrequency) AS GlobalMin,  -- Earliest order date (oldest)
        MAX(SalesPersonFrequency) AS GlobalMax   -- Latest order date (most recent)
    FROM 
    SalesPersonFreqData
),
QuantileData AS (
    -- Get the Quantile values for TotalSpent in Quantiles 1 to 4
    SELECT 
        NTILE(4) OVER (ORDER BY SalesPersonFrequency) AS Quartile,
        SalesPersonFrequency
    FROM SalesPersonFreqData
),
FilteredQuantiles AS (
    SELECT 
        SalesPersonFrequency
    FROM QuantileData
    WHERE Quartile BETWEEN 2 AND 4  -- Focus on Quantiles 2 to 4
),
QuantileLimits AS (
    SELECT 
        MIN(SalesPersonFrequency) AS MinQuantileValue,
        MAX(SalesPersonFrequency) AS MaxQuantileValue
    FROM FilteredQuantiles
),
ScoreRanges AS (
    SELECT 
        Score,
        -- For Score 1, LowerLimit is the GlobalMin
        CASE 
            WHEN Score = 1 THEN (SELECT GlobalMin FROM GlobalMinMax)
            ELSE MinQuantileValue + (MaxQuantileValue - MinQuantileValue) / 10.0 * (Score - 1)
        END AS LowerLimit,
        
        -- UpperLimit is calculated based on the next score range
        CASE 
            WHEN Score = 10 THEN (SELECT GlobalMax + 1.00 FROM GlobalMinMax)  -- For score 10, the upper limit is the MaxQuantileValue
            ELSE MinQuantileValue + (MaxQuantileValue - MinQuantileValue) / 10.0 * Score
        END AS UpperLimit
    FROM 
        (SELECT 1 AS Score UNION ALL 
         SELECT 2 UNION ALL 
         SELECT 3 UNION ALL 
         SELECT 4 UNION ALL 
         SELECT 5 UNION ALL 
         SELECT 6 UNION ALL 
         SELECT 7 UNION ALL 
         SELECT 8 UNION ALL 
         SELECT 9 UNION ALL 
         SELECT 10) AS Scores,
        QuantileLimits
)
-- Update existing records in DimSalesPersonFreqScore
UPDATE test.dbo.DimSalesPersonFreqScore
SET 
    LowerLimit = ScoreRanges.LowerLimit,
    UpperLimit = ScoreRanges.UpperLimit
FROM 
    test.dbo.DimSalesPersonFreqScore AS DimScore
INNER JOIN 
    ScoreRanges ON DimScore.Score = ScoreRanges.Score;

----------------------------------------------------------------------------

-- Update DimTotalFrequencyScore --

WITH TotalFrequencyData AS (
    SELECT 
        CustomerID,
        COUNT(SalesOrderID) AS TotalFrequency
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader2]
    GROUP BY 
        CustomerID
),
GlobalMinMax AS (
    SELECT 
        MIN(TotalFrequency) AS GlobalMin,
        MAX(TotalFrequency) AS GlobalMax
    FROM 
        TotalFrequencyData
),
TotalFreqQuantileData AS (
    SELECT 
        NTILE(4) OVER (ORDER BY TotalFrequency) AS Quartile,
        TotalFrequency
    FROM TotalFrequencyData
),
FilteredQuantiles AS (
    SELECT 
        TotalFrequency
    FROM TotalFreqQuantileData
    WHERE Quartile BETWEEN 2 AND 4
),
QuantileLimits AS (
    SELECT 
        MIN(TotalFrequency) AS MinQuantileValue,
        MAX(TotalFrequency) AS MaxQuantileValue
    FROM FilteredQuantiles
),
ScoreRanges AS (
    SELECT 
        Score,
        CASE 
            WHEN Score = 1 THEN (SELECT GlobalMin FROM GlobalMinMax)
            ELSE MinQuantileValue + (MaxQuantileValue - MinQuantileValue) / 10.0 * (Score - 1)
        END AS LowerLimit,
        CASE 
            WHEN Score = 10 THEN (SELECT GlobalMax + 1.00 FROM GlobalMinMax)
            ELSE MinQuantileValue + (MaxQuantileValue - MinQuantileValue) / 10.0 * Score
        END AS UpperLimit
    FROM 
        (SELECT 1 AS Score UNION ALL 
         SELECT 2 UNION ALL 
         SELECT 3 UNION ALL 
         SELECT 4 UNION ALL 
         SELECT 5 UNION ALL 
         SELECT 6 UNION ALL 
         SELECT 7 UNION ALL 
         SELECT 8 UNION ALL 
         SELECT 9 UNION ALL 
         SELECT 10) AS Scores,
        QuantileLimits
)
-- Update existing records in DimTotalFreqScore
UPDATE test.dbo.DimTotalFreqScore
SET 
    LowerLimit = ScoreRanges.LowerLimit,
    UpperLimit = ScoreRanges.UpperLimit
FROM 
    test.dbo.DimTotalFreqScore AS DimScore
INNER JOIN 
    ScoreRanges ON DimScore.Score = ScoreRanges.Score;

----------------------------------------------------------------------------

-- Update DimTotalSpentScore --

WITH TotalSpentData AS (
    -- Get the total spent per customer
    SELECT 
        CustomerID,
        SUM(TotalDue) AS TotalSpent
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader2]
    GROUP BY 
        CustomerID
),
GlobalMinMax AS (
    -- calculate global min and max 
    SELECT 
        MIN(TotalSpent) AS GlobalMin,  
        MAX(TotalSpent) AS GlobalMax  
    FROM 
        TotalSpentData
),
QuantileData AS (
    -- Get the Quantile values for TotalSpent in Quantiles 2 to 4
    SELECT 
        NTILE(4) OVER (ORDER BY TotalSpent) AS Quartile,
        TotalSpent
    FROM TotalSpentData
),
QuantileLimits AS (
    -- Get the minimum and maximum values for Quantiles 2 to 4
    SELECT 
        MIN(TotalSpent) AS MinQuantileValue,
        MAX(TotalSpent) AS MaxQuantileValue
    FROM QuantileData
    WHERE Quartile BETWEEN 2 AND 4
),
ScoreRanges AS (
    -- Generate score ranges based on Quantile and min/max values
    SELECT 
        Score,
        -- For Score 1, LowerLimit is the MinTotalSpent
        CASE 
            WHEN Score = 1 THEN (SELECT GlobalMin FROM GlobalMinMax)
            ELSE (SELECT MinQuantileValue FROM QuantileLimits) + ((SELECT MaxQuantileValue FROM QuantileLimits) - (SELECT MinQuantileValue FROM QuantileLimits)) / 10.0 * (Score - 1)
        END AS LowerLimit,
        
        -- For Score 10, UpperLimit is the MaxTotalSpent
        CASE 
            WHEN Score = 10 THEN (SELECT GlobalMax + 1.000 FROM GlobalMinMax)
            ELSE (SELECT MinQuantileValue FROM QuantileLimits) + ((SELECT MaxQuantileValue FROM QuantileLimits) - (SELECT MinQuantileValue FROM QuantileLimits)) / 10.0 * Score
        END AS UpperLimit
    FROM 
        (SELECT 1 AS Score UNION ALL 
         SELECT 2 UNION ALL 
         SELECT 3 UNION ALL 
         SELECT 4 UNION ALL 
         SELECT 5 UNION ALL 
         SELECT 6 UNION ALL 
         SELECT 7 UNION ALL 
         SELECT 8 UNION ALL 
         SELECT 9 UNION ALL 
         SELECT 10) AS Scores
)
-- Update existing records in DimTotalSpentScore
UPDATE test.dbo.DimTotalSpentScore
SET 
    LowerLimit = ScoreRanges.LowerLimit,
    UpperLimit = ScoreRanges.UpperLimit
FROM 
    test.dbo.DimTotalSpentScore AS DimScore
INNER JOIN 
    ScoreRanges ON DimScore.Score = ScoreRanges.Score;

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

--- Update DimChurns ---

----------------------------------------------------------------------------

-- Update DimChurnRatio --

WITH ScoreData AS (
    SELECT 
        tf.Score AS TotalFrequencyScore,
        r.Score AS RecencyScore,
        ts.Score AS TotalSpentScore,
        spf.Score AS SalesPersonFreqScore,
        CAST(( (tf.Score + r.Score + ts.Score + spf.Score) / 40.000 ) AS DECIMAL(4, 3)) AS ChurnRatio
    FROM 
        test.dbo.DimTotalFreqScore tf
    CROSS JOIN 
        test.dbo.DimRecencyScore r
    CROSS JOIN 
        test.dbo.DimTotalSpentScore ts
    CROSS JOIN
        test.dbo.DimSalesPersonFreqScore spf
),
MaxScoreData AS (
    SELECT
        MAX(ChurnRatio) AS MaxChurnRatio
    FROM ScoreData
)

------------------------------------------------------------

-- Update DimChurnRatio

UPDATE test.dbo.DimChurnRatio
SET ChurnRatio = CASE
    WHEN sd.ChurnRatio = (SELECT MaxChurnRatio FROM MaxScoreData) THEN sd.ChurnRatio + 1
    ELSE sd.ChurnRatio
END
FROM test.dbo.DimChurnRatio dcr
JOIN ScoreData sd
    ON dcr.TotalFrequencyScore = sd.TotalFrequencyScore
    AND dcr.RecencyScore = sd.RecencyScore
    AND dcr.TotalSpentScore = sd.TotalSpentScore
    AND dcr.SalesPersonFreqScore = sd.SalesPersonFreqScore;


------------------------------------------------------------
-- Update DimChurnScore

-- Step 1: Define the number of levels dynamically (you can change this value)
DECLARE @NumLevels INT = 5;  -- Number of levels you want to divide the data into (5 levels in this case)

-- Step 2: Calculate the number of quantiles for the given levels
DECLARE @NumQuantiles INT = 10;  -- Number of quantiles (scores) to create

WITH ChurnQuantiles AS (
    -- Divide the data in DimChurnRatio into 10 quantiles (changeable based on @NumQuantiles)
    SELECT 
        NTILE(@NumQuantiles) OVER (ORDER BY ChurnRatio) AS ChurnScore, -- Divide into quantiles
        ChurnRatio
    FROM 
        test.dbo.DimChurnRatio
),
BucketLimits AS (
    -- Get the min and max churn ratio for each quantile (ChurnScore)
    SELECT 
        ChurnScore,
        CASE 
            WHEN ChurnScore = 1 THEN 0  -- Set the LowerLimit of score 1 to 0
            ELSE MIN(ChurnRatio)
        END AS LowerLimit,
        MAX(ChurnRatio) AS UpperLimit
    FROM 
        ChurnQuantiles
    GROUP BY 
        ChurnScore
),
ChurnLevels AS (
    -- Dynamically assign ChurnLevels based on the quantiles
    SELECT 
        ChurnScore,
        LowerLimit,
        UpperLimit,
        -- Dynamically calculate the level based on the number of quantiles
        CASE 
            WHEN ChurnScore <= (CAST(@NumQuantiles * 1 / @NumLevels AS INT)) THEN 'Very High'   -- First quantile range -> Very High
            WHEN ChurnScore <= (CAST(@NumQuantiles * 2 / @NumLevels AS INT)) THEN 'High'        -- Second quantile range -> High
            WHEN ChurnScore <= (CAST(@NumQuantiles * 3 / @NumLevels AS INT)) THEN 'Medium'      -- Third quantile range -> Medium
            WHEN ChurnScore <= (CAST(@NumQuantiles * 4 / @NumLevels AS INT)) THEN 'Low'         -- Fourth quantile range -> Low
            ELSE 'Very Low'   -- Remaining quantiles -> Very Low
        END AS ChurnLevel
    FROM 
        BucketLimits
)
-- Update the DimChurnScore table with the calculated values
UPDATE target
SET 
    target.LowerLimit = source.LowerLimit,
    target.UpperLimit = CASE
                           WHEN source.ChurnScore = @NumQuantiles THEN source.UpperLimit + 1
                           ELSE source.UpperLimit
                        END,
    target.ChurnLevel = source.ChurnLevel
FROM 
    test.dbo.DimChurnScore AS target
INNER JOIN 
    ChurnLevels AS source
ON 
    target.ChurnScore = source.ChurnScore;

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

--- Update DimTables ---

----------------------------------------------------------------------------

-- Update DimDate --

-- Step 1: Find the latest year from SalesOrderHeader2
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

----------------------------------------------------------------------------

-- Update DimCustomer --

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
		[CompanyX].[Sales].[SalesOrderHeader2] AS soh
),

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
        tss.Score AS CurrentTotalSpentScore
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
        ON tss.LowerLimit <= CAST(md.TotalSpent AS DECIMAL(20, 4)) AND CAST(md.TotalSpent AS DECIMAL(20, 4)) < tss.UpperLimit
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
    Target.CurrentTotalSpentScore <> Source.CurrentTotalSpentScore
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
        Target.CurrentTotalSpentScore = Source.CurrentTotalSpentScore

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
        Source.CurrentTotalSpentScore
    );
    
----------------------------------------------------------------------------

-- Update DimSalesPerson --

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

----------------------------------------------------------------------------

-- Update Fact Table --

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


-- Update existing records in FactCustomerChurn if there are changes in SalesOrderHeader2
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