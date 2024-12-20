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
-- Update existing records in DimTotalSpentScore
UPDATE test.dbo.DimTotalSpentScore
SET 
    LowerLimit = ScoreRanges.LowerLimit,
    UpperLimit = ScoreRanges.UpperLimit
FROM 
    test.dbo.DimTotalSpentScore AS DimScore
INNER JOIN 
    ScoreRanges ON DimScore.Score = ScoreRanges.Score;
