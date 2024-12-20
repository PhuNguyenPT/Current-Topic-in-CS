DELETE FROM test.dbo.DimChurnRatio;

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
INSERT INTO test.dbo.DimChurnRatio (TotalFrequencyScore, RecencyScore, TotalSpentScore, SalesPersonFreqScore, ChurnRatio)
-- Selecting the ChurnRatio equal to MaxChurnRatio and adding 1
SELECT 
    sd.TotalFrequencyScore,
    sd.RecencyScore,
    sd.TotalSpentScore,
    sd.SalesPersonFreqScore,
    CASE
        WHEN sd.ChurnRatio = (SELECT MaxChurnRatio FROM MaxScoreData) THEN sd.ChurnRatio + 1
        ELSE sd.ChurnRatio
    END AS AdjustedChurnRatio
FROM ScoreData sd
ORDER BY sd.TotalFrequencyScore, sd.RecencyScore, sd.TotalSpentScore, sd.SalesPersonFreqScore ASC;