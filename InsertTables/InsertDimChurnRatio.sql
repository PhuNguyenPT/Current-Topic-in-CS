DECLARE @NumScore DECIMAL = 4;
DECLARE @ScoreRanges DECIMAL = 10;
PRINT  (CAST((1 + 1 + 1 + 1) AS DECIMAL(10, 9)) / (@NumScore * @ScoreRanges) );
INSERT INTO test.dbo.DimChurnRatio (TotalFrequencyScore, RecencyScore, TotalSpentScore, SalesPersonFreqScore, ChurnRatio)
SELECT 
    tf.Score AS TotalFrequencyScore,
    r.Score AS RecencyScore,
    ts.Score AS TotalSpentScore,
    spf.Score AS SalesPersonFreqScore,
    (CAST((tf.Score + r.Score + ts.Score + spf.Score) AS DECIMAL(5,3)) / (@NumScore * @ScoreRanges)) AS ChurnRatio
FROM 
    test.dbo.DimTotalFreqScore tf
CROSS JOIN 
    test.dbo.DimRecencyScore r
CROSS JOIN 
    test.dbo.DimTotalSpentScore ts
CROSS JOIN
    test.dbo.DimSalesPersonFreqScore spf;