
-- Drop 4 Metric Tables
DELETE FROM test.dbo.DimTotalFreqScore;
DELETE FROM test.dbo.DimSalesPersonFreqScore;
DELETE FROM test.dbo.DimRecencyScore;
DELETE FROM test.dbo.DimTotalSpentScore;

-- Drop 2 DimChurn Tables
DELETE FROM test.dbo.DimChurnRatio;
DELETE FROM test.dbo.DimChurnScore;

-- Drop 3 Dims and Fact
DELETE FROM dbo.DimDate;
DELETE FROM dbo.DimCustomer;
DELETE FROM dbo.DimSalesPerson;
DELETE FROM dbo.FactCustomerChurn;


--------------------------------------------------------------------------------------------------

-- Insert into DimTotalFreqScore

WITH TotalFrequencyData AS (
    SELECT 
        CustomerID,
        COUNT(SalesOrderID) AS TotalFrequency
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader]
    GROUP BY 
        CustomerID
),
GlobalMinMax AS (
    -- Step 3: Calculate global min and max OrderDate from the entire SalesOrderHeader table
    SELECT 
        MIN(TotalFrequency) AS GlobalMin,  -- Earliest order date (oldest)
        MAX(TotalFrequency) AS GlobalMax   -- Latest order date (most recent)
    FROM 
        TotalFrequencyData
),
TotalFreqQuantileData AS (
    -- Get the Quantile values for TotalSpent in Quantiles 1 to 4
    SELECT 
        NTILE(4) OVER (ORDER BY TotalFrequency) AS Quartile,
        TotalFrequency
    FROM TotalFrequencyData
),
FilteredQuantiles AS (
    SELECT 
        TotalFrequency
    FROM TotalFreqQuantileData
    WHERE Quartile BETWEEN 2 AND 4  -- Focus on Quantiles 2 to 4
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
        -- For Score 1, LowerLimit is the MinQuantileValue
        CASE 
            WHEN Score = 1 THEN (SELECT GlobalMin FROM GlobalMinMax)
            ELSE MinQuantileValue + (MaxQuantileValue - MinQuantileValue) / 10.0 * (Score - 1)
        END AS LowerLimit,
        
        -- UpperLimit is calculated based on the next score range
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
-- Insert the calculated scores into DimTotalFreqScore
INSERT INTO test.dbo.DimTotalFreqScore (Score, LowerLimit, UpperLimit)
SELECT 
    Score,
    LowerLimit,
    UpperLimit
FROM ScoreRanges
ORDER BY Score;


--------------------------------------------------------------------------------------------------

-- Insert into DimSalesPersonFreqScore

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
		[CompanyX].[Sales].[SalesOrderHeader] AS soh
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
    -- Step 3: Calculate global min and max OrderDate from the entire SalesOrderHeader table
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
-- Insert the calculated scores into DimSalesPersonFreqScore
INSERT INTO test.dbo.DimSalesPersonFreqScore (Score, LowerLimit, UpperLimit)
SELECT 
    Score,
    LowerLimit,
    UpperLimit
FROM ScoreRanges
ORDER BY Score;


--------------------------------------------------------------------------------------------------

-- Insert into DimRecencyScore

WITH LatestOrderDates AS (
    -- Step 1: Extract the latest OrderDate for each CustomerID
    SELECT 
        CustomerID,
        MAX(OrderDate) AS LatestOrderDate
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader]
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
    -- Step 3: Calculate global min and max OrderDate from the entire SalesOrderHeader table
    SELECT 
        MIN(OrderDate) AS GlobalMin,  -- Earliest order date (oldest)
        MAX(OrderDate) AS GlobalMax   -- Latest order date (most recent)
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader]
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

-- Step 9: Insert the calculated recency scores into DimRecencyScore
INSERT INTO [Test].[dbo].[DimRecencyScore] (Score, LowerLimit, UpperLimit)
SELECT 
    Score,
    LowerLimit,
    UpperLimit
FROM 
    FinalScoreAssignments
ORDER BY 
    Score DESC;


--------------------------------------------------------------------------------------------------

-- Insert into DimTotalSpentScore

WITH TotalSpentData AS (
    -- Get the total spent per customer
    SELECT 
        CustomerID,
        SUM(TotalDue) AS TotalSpent
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader]
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
-- Insert the calculated scores into the DimTotalSpentScore table
INSERT INTO test.dbo.DimTotalSpentScore (Score, LowerLimit, UpperLimit)
SELECT 
    Score,
    LowerLimit,
    UpperLimit
FROM ScoreRanges
ORDER BY Score;


--------------------------------------------------------------------------------------------------

-- Insert into DimChurnRatio and DimChurnScore

---------------------------DimChurnRatio---------------------------

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
INSERT INTO test.dbo.DimChurnRatio (TotalFrequencyScore, RecencyScore, TotalSpentScore, SalesPersonFreqScore, ChurnRatio)
-- Selecting the ChurnRatio equal to MaxChurnRatio and adding 1
SELECT 
    sd.TotalFrequencyScore,
    sd.RecencyScore,
    sd.TotalSpentScore,
    sd.SalesPersonFreqScore,
    CASE
        WHEN sd.ChurnRatio = (SELECT MaxChurnRatio FROM MaxScoreData) THEN sd.ChurnRatio + 1
        ELSE sd.ChurnRatio
    END AS AdjustedChurnRatio
FROM ScoreData sd
ORDER BY sd.TotalFrequencyScore, sd.RecencyScore, sd.TotalSpentScore, sd.SalesPersonFreqScore ASC;


---------------------------DimChurnScore---------------------------

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
-- Insert the calculated score ranges with ChurnLevel into DimChurnScore
INSERT INTO test.dbo.DimChurnScore (ChurnScore, LowerLimit, UpperLimit, ChurnLevel)
SELECT 
    ChurnScore,
    LowerLimit,
    CASE
		WHEN ChurnScore = 10 THEN UpperLimit + 1
		ELSE UpperLimit
	END AS UpperLimit,
    ChurnLevel
FROM 
    ChurnLevels
ORDER BY 
    ChurnScore;


--------------------------------------------------------------------------------------------------

-- Insert into DimDate, DimCustomer, DimSalesPerson, DimFactCustomerChurn

---------------------------DimDate---------------------------

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

---------------------------DimCustomer---------------------------

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

---------------------------DimSalesPerson---------------------------

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
		[CompanyX].[Sales].[SalesOrderHeader] AS soh
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
ON spfs.LowerLimit <= spf.SalesPersonFrequency AND spf.SalesPersonFrequency < spfs.UpperLimit;

---------------------------FactCustomerChurn---------------------------

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
		[CompanyX].[Sales].[SalesOrderHeader] AS soh
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