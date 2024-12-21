DELETE FROM test.dbo.DimRecencyScore;

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