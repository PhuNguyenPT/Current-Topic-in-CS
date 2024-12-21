USE test;

DROP TABLE IF EXISTS test.dbo.DimTotalFreqScore;
DROP TABLE IF EXISTS test.dbo.DimChurnRatio;
DROP TABLE IF EXISTS test.dbo.DimRecencyScore;
DROP TABLE IF EXISTS test.dbo.DimTotalSpentScore;
DROP TABLE IF EXISTS test.dbo.DimChurnScore;
DROP TABLE IF EXISTS test.dbo.DimSalesPersonFreqScore;

CREATE TABLE test.dbo.DimTotalFreqScore (
    TotalFreqScoreID INT IDENTITY(1,1) PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE test.dbo.DimRecencyScore (
    RecencyScoreID INT IDENTITY(1,1) PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE test.dbo.DimTotalSpentScore (
    TotalSpentScoreID INT IDENTITY(1,1) PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(20, 4) NULL,
    UpperLimit DECIMAL(20, 4) NULL
);

CREATE TABLE test.dbo.DimSalesPersonFreqScore (
    SalesPersonFreqScoreID INT IDENTITY(1,1) PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE test.dbo.DimChurnRatio (
    ChurnRatioID INT IDENTITY(1,1) PRIMARY KEY,
    TotalFrequencyScore INT NOT NULL,
    RecencyScore INT NOT NULL,
    TotalSpentScore INT NOT NULL,
    SalesPersonFreqScore INT NOT NULL,
    ChurnRatio DECIMAL(4, 3) NULL-- Suitable for churn percentages
);

CREATE TABLE test.dbo.DimChurnScore (
    ChurnScoreID INT IDENTITY(1,1) PRIMARY KEY,
    ChurnScore INT NOT NULL,
    LowerLimit DECIMAL(4, 3) NULL,
    UpperLimit DECIMAL(4, 3) NULL,
    ChurnLevel VARCHAR(255) NULL
);