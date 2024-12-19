USE test;

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
    ChurnRatio DECIMAL(5, 2) -- Suitable for churn percentages
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
    UpperLimit DECIMAL(10, 2) NULL
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
    ChurnLevel VARCHAR(255)            -- Stores the churn ratio
);