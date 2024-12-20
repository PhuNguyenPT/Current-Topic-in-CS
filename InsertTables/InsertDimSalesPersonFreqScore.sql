WITH SalesPersonFreqData AS (
    SELECT 
		soh.CustomerID,
        soh.SalesPersonID,
		COUNT(soh.SalesOrderID) AS SalesPersonFrequency
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] soh
    GROUP BY 
        soh.SalesPersonID, soh.CustomerID
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
-- Insert the calculated scores into DimTotalFreqScore
INSERT INTO test.dbo.DimSalesPersonFreqScore (Score, LowerLimit, UpperLimit)
SELECT 
    Score,
    LowerLimit,
    UpperLimit
FROM ScoreRanges
ORDER BY Score;