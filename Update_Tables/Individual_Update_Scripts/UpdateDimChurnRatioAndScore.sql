



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