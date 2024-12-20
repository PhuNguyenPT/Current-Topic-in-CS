DELETE FROM test.dbo.DimTotalFreqScore;


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
