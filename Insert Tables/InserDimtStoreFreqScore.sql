WITH TotalStoreFreqData AS (
    SELECT 
		soh.CustomerID,
        s.BusinessEntityID AS StoreID,
		COUNT(soh.SalesOrderID) AS TotalFrequency
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader] soh
    LEFT JOIN 
        [CompanyX].[Sales].[Store] s 
    ON 
        soh.SalesPersonID = s.SalesPersonID
    GROUP BY 
        s.BusinessEntityID, soh.CustomerID
),
TotalFrequencyData AS (
    SELECT 
        CustomerID,
        COUNT(SalesOrderID) AS TotalFrequency
    FROM 
        [CompanyX].[Sales].[SalesOrderHeader]
    GROUP BY 
        CustomerID
),
StoreRatio AS (
    SELECT 
    CAST((tsf.TotalFrequency * 1.0 / tf.TotalFrequency) AS NUMERIC(10, 2)) AS Ratio, -- Cast Ratio
    tsf.StoreID, 
    tsf.CustomerID
    FROM TotalStoreFreqData tsf
    LEFT JOIN TotalFrequencyData tf
    ON tsf.CustomerID = tf.CustomerID
),
GlobalMinMax AS (
    -- Step 3: Calculate global min and max OrderDate from the entire SalesOrderHeader table
    SELECT 
        MIN(Ratio) AS GlobalMin,  -- Earliest order date (oldest)
        MAX(Ratio) AS GlobalMax   -- Latest order date (most recent)
    FROM 
        StoreRatio
),
StoreQuantileData AS (
    -- Get the Quantile values for TotalSpent in Quantiles 1 to 4
    SELECT 
        NTILE(4) OVER (ORDER BY Ratio) AS Quartile,
        Ratio
    FROM StoreRatio
),
FilteredQuantiles AS (
    SELECT 
        Ratio
    FROM StoreQuantileData
    WHERE Quartile BETWEEN 2 AND 4  -- Focus on Quantiles 2 to 4
),
QuantileLimits AS (
    SELECT 
        MIN(Ratio) AS MinQuantileValue,
        MAX(Ratio) AS MaxQuantileValue
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
            WHEN Score = 10 THEN (SELECT GlobalMax FROM GlobalMinMax)  -- For score 10, the upper limit is the MaxQuantileValue
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
INSERT INTO test.dbo.DimStoreFreqScore (Score, LowerLimit, UpperLimit)
SELECT 
    Score,
    LowerLimit,
    UpperLimit
FROM ScoreRanges
ORDER BY Score;