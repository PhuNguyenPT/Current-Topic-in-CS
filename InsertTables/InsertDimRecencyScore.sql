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
        Score,
        -- For Score 1, LowerLimit is the GlobalMax (oldest date)
        CASE 
            WHEN Score = 1 THEN (SELECT DATEDIFF(DAY, GlobalMax, GETDATE()) FROM GlobalMinMax)
            ELSE MinRecencyValue + (MaxRecencyValue - MinRecencyValue) / 10.0 * (Score - 1)
        END AS LowerLimit,
        
        -- For Score 10, UpperLimit is the GlobalMin (most recent date)
        CASE 
            WHEN Score = 10 THEN (SELECT DATEDIFF(DAY, GlobalMin, GETDATE()) FROM GlobalMinMax)
            ELSE MinRecencyValue + (MaxRecencyValue - MinRecencyValue) / 10.0 * Score
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
        RecencyQuantileLimits
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
    Score;