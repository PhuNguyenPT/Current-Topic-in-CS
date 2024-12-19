USE test;

DROP TABLE IF EXISTS test.dbo.DimTotalFreqScore;
DROP TABLE IF EXISTS test.dbo.DimChurnRatio;
DROP TABLE IF EXISTS test.dbo.DimRecencyScore;
DROP TABLE IF EXISTS test.dbo.DimTotalSpentScore;
DROP TABLE IF EXISTS test.dbo.DimChurnScore;
DROP TABLE IF EXISTS test.dbo.DimStoreFreqScore;
DROP TABLE IF EXISTS test.dbo.DimStoreChurnScore;


CREATE TABLE test.dbo.DimTotalFreqScore (
    TotalFreqScoreID INT IDENTITY(1,1) PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE test.dbo.DimChurnRatio (
    ChurnRatioID INT IDENTITY(1,1) PRIMARY KEY,
    TotalFrequencyScore INT NOT NULL,
    RecencyScore INT NOT NULL,
    TotalSpentScore INT NOT NULL,
    ChurnRatio DECIMAL(5, 2) NULL-- Suitable for churn percentages
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
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE test.dbo.DimChurnScore (
    ChurnScoreID INT IDENTITY(1,1) PRIMARY KEY,
    ChurnScore INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL,
    ChurnLevel VARCHAR(255) NULL
);

CREATE TABLE test.dbo.DimStoreFreqScore (
    StoreFreqScoreID INT IDENTITY(1,1) PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);


CREATE TABLE test.dbo.DimStoreChurnScore (
    StoreChurnRatioID INT IDENTITY(1,1) PRIMARY KEY,   -- Unique identifier for each record
    StoreFreqScore INT NOT NULL,
    ChurnLevel VARCHAR(255) NULL           -- Stores the churn ratio
);