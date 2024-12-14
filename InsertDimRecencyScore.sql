DECLARE @TotalDays INT;

-- Dynamically calculate TotalDays using the earliest and latest order dates
SELECT @TotalDays = DATEDIFF(DAY, 
                              (SELECT MIN(OrderDate) FROM [CompanyX].[Sales].[SalesOrderHeader]),  -- Earliest Order Date
                              (SELECT MAX(OrderDate) FROM [CompanyX].[Sales].[SalesOrderHeader]))  -- Latest Order Date

DECLARE @ScoreRange INT = @TotalDays / 10;

-- Insert into DimRecencyScore table with dynamically calculated ranges
INSERT INTO test.dbo.DimRecencyScore (Score, LowerLimit, UpperLimit)
VALUES
(1, @TotalDays - @ScoreRange * 1.00, @TotalDays - @ScoreRange * 0.00),  -- Score 1 = oldest
(2, @TotalDays - @ScoreRange * 2.00, @TotalDays - @ScoreRange * 1.00),
(3, @TotalDays - @ScoreRange * 3.00, @TotalDays - @ScoreRange * 2.00),
(4, @TotalDays - @ScoreRange * 4.00, @TotalDays - @ScoreRange * 3.00),
(5, @TotalDays - @ScoreRange * 5.00, @TotalDays - @ScoreRange * 4.00),
(6, @TotalDays - @ScoreRange * 6.00, @TotalDays - @ScoreRange * 5.00),
(7, @TotalDays - @ScoreRange * 7.00, @TotalDays - @ScoreRange * 6.00),
(8, @TotalDays - @ScoreRange * 8.00, @TotalDays - @ScoreRange * 7.00),
(9, @TotalDays - @ScoreRange * 9.00, @TotalDays - @ScoreRange * 8.00),
(10, 0, @ScoreRange);  -- Score 10 = most recent, with 0 as lower limit