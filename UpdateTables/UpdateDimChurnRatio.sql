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