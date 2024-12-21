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
