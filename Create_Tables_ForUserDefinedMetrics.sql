USE test;

CREATE TABLE dbo.DimTotalFreqScore (
    TotalFreqScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE dbo.DimChurnRatio (
    ChurnRatioID INT PRIMARY KEY,
    CustomerID INT NOT NULL, -- Foreign Key to a customer table
    TotalFrequencyScore INT NOT NULL,
    RecencyScore INT NOT NULL,
    TotalSpentScore INT NOT NULL,
    ChurnRatio DECIMAL(5, 2) -- Suitable for churn percentages
);

CREATE TABLE dbo.DimRecencyScore (
    RecencyScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE dbo.DimTotalSpentScore (
    TotalSpentScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE dbo.DimChurnScore (
    ChurnScoreID INT PRIMARY KEY,
    ChurnScore INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);

CREATE TABLE dbo.DimStoreFreqScore (
    StoreFreqScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit DECIMAL(10, 2) NULL,
    UpperLimit DECIMAL(10, 2) NULL
);


CREATE TABLE dbo.DimStoreChurnRatio (
    StoreChurnRatioID INT PRIMARY KEY,   -- Unique identifier for each record
    CustomerID INT NOT NULL,            -- Foreign Key to the customer table
    StoreID INT NOT NULL,               -- Foreign Key to the store table
    ChurnRatio DECIMAL(5, 2)            -- Stores the churn ratio
);