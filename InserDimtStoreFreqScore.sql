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
MinStore AS (
    -- Get the minimum total spent across all customers
    SELECT 
        MIN(TotalFrequency) AS MinTotalStoreFreq
    FROM TotalStoreFreqData
),
MaxStore AS (
    -- Get the maximum total spent across all customers
    SELECT 
        MAX(TotalFrequency) AS MaxTotalStoreFreq
    FROM TotalStoreFreqData
),
StoreQuantileData AS (
    -- Get the Quantile values for TotalSpent in Quantiles 1 to 4
    SELECT 
        NTILE(4) OVER (ORDER BY TotalFrequency) AS Quartile,
        TotalFrequency
    FROM TotalStoreFreqData
),
FilteredQuantiles AS (
    SELECT 
        TotalFrequency
    FROM StoreQuantileData
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
            WHEN Score = 1 THEN (SELECT MinTotalStoreFreq FROM MinStore)
            ELSE MinQuantileValue + (MaxQuantileValue - MinQuantileValue) / 10.0 * (Score - 1)
        END AS LowerLimit,
        
        -- UpperLimit is calculated based on the next score range
        CASE 
            WHEN Score = 10 THEN (SELECT MaxTotalStoreFreq FROM MaxStore)  -- For score 10, the upper limit is the MaxQuantileValue
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
INSERT INTO Star_schema.dbo.DimStoreFreqScore (Score, LowerLimit, UpperLimit)
SELECT 
    Score,
    LowerLimit,
    UpperLimit
FROM ScoreRanges
ORDER BY Score;