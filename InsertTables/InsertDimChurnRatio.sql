INSERT INTO test.dbo.DimChurnRatio (TotalFrequencyScore, RecencyScore, TotalSpentScore, ChurnRatio)
SELECT 
    tf.Score AS TotalFrequencyScore,
    r.Score AS RecencyScore,
    ts.Score AS TotalSpentScore,
    CAST((tf.Score + r.Score + ts.Score) / 30.0 AS DECIMAL(5, 2)) AS ChurnRatio
FROM 
    test.dbo.DimTotalFreqScore tf
CROSS JOIN 
    test.dbo.DimRecencyScore r
CROSS JOIN 
    test.dbo.DimTotalSpentScore ts;