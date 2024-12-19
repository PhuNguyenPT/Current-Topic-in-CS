-- Step 1: Get the number of distinct StoreFreqScores and set it as @NumQuantiles
DECLARE @NumQuantiles INT;

SELECT @NumQuantiles = COUNT(DISTINCT Score)
FROM Test.dbo.DimStoreFreqScore;

-- Step 2: Define the number of levels dynamically (you can change this value)
DECLARE @NumLevels INT = 5;  -- Number of levels you want to divide the data into (5 levels in this case)

WITH StoreQuantiles AS (
    -- Step 3: Divide the data in DimStoreFreqScore into quantiles (based on @NumQuantiles)
    SELECT 
        NTILE(@NumQuantiles) OVER (ORDER BY Score) AS StoreChurnScore,  -- Divide into quantiles
        Score
    FROM 
        Test.dbo.DimStoreFreqScore
),
BucketLimits AS (
    -- Step 4: Get the min and max StoreFreqScore for each quantile (StoreChurnScore)
    SELECT 
        StoreChurnScore,
        MIN(Score) AS LowerLimit,
        MAX(Score) AS UpperLimit
    FROM 
        StoreQuantiles
    GROUP BY 
        StoreChurnScore
),
ChurnLevels AS (
    -- Step 5: Dynamically assign ChurnLevels based on the quantiles (using dynamic level calculation)
    SELECT 
        StoreChurnScore,
        LowerLimit,
        UpperLimit,
        -- Dynamically calculate the level based on the number of quantiles
        CASE 
            WHEN StoreChurnScore <= (CAST(@NumQuantiles * 1 / @NumLevels AS INT)) THEN 'Very High'   -- First quantile range -> Very High
            WHEN StoreChurnScore <= (CAST(@NumQuantiles * 2 / @NumLevels AS INT)) THEN 'High'        -- Second quantile range -> High
            WHEN StoreChurnScore <= (CAST(@NumQuantiles * 3 / @NumLevels AS INT)) THEN 'Medium'      -- Third quantile range -> Medium
            WHEN StoreChurnScore <= (CAST(@NumQuantiles * 4 / @NumLevels AS INT)) THEN 'Low'         -- Fourth quantile range -> Low
            ELSE 'Very Low'   -- Remaining quantiles -> Very Low
        END AS ChurnLevel
    FROM 
        BucketLimits
)
-- Step 6: Insert the calculated score ranges with ChurnLevel into DimStoreChurnScore
INSERT INTO Test.dbo.DimStoreChurnScore (StoreFreqScore, ChurnLevel)
SELECT 
    sq.Score, -- Reference Score from StoreQuantiles
    CASE 
        WHEN sq.StoreChurnScore <= (CAST(@NumQuantiles * 1 / @NumLevels AS INT)) THEN 'Very High'
        WHEN sq.StoreChurnScore <= (CAST(@NumQuantiles * 2 / @NumLevels AS INT)) THEN 'High'
        WHEN sq.StoreChurnScore <= (CAST(@NumQuantiles * 3 / @NumLevels AS INT)) THEN 'Medium'
        WHEN sq.StoreChurnScore <= (CAST(@NumQuantiles * 4 / @NumLevels AS INT)) THEN 'Low'
        ELSE 'Very Low'
    END AS ChurnLevel
FROM 
    StoreQuantiles sq
ORDER BY 
    sq.StoreChurnScore;