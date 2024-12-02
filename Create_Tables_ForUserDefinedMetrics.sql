USE test;

CREATE TABLE dbo.DimTotalFreqScore (
    TotalFreqScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit INT NULL,
    UpperLimit INT NULL
);

CREATE TABLE dbo.DimChurnRatio (
    ChurnRatioID INT PRIMARY KEY,
    TotalFrequencyScore INT NOT NULL,
    RecencyScore INT NOT NULL,
    TotalSpentScore INT NOT NULL,
    ChurnRatio NUMERIC(3, 2)
);

CREATE TABLE dbo.DimRecencyScore (
    RecencyScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit INT NULL,
    UpperLimit INT NULL
);

CREATE TABLE dbo.DimTotalSpentScore (
    TotalSpentScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit INT NULL,
    UpperLimit INT NULL
);

CREATE TABLE dbo.DimChurnScore (
    ChurnScoreID INT PRIMARY KEY,
    ChurnScore INT NOT NULL,
    LowerLimit INT NULL,
    UpperLimit INT NULL
);

CREATE TABLE dbo.DimStoreFreqScore (
    StoreFreqScoreID INT PRIMARY KEY,
    Score INT NOT NULL,
    LowerLimit INT NULL,
    UpperLimit INT NULL
);

CREATE TABLE dbo.DimStoreChurnRatio (
    StoreChurnRatioID INT PRIMARY KEY,
    ChurnRatio NUMERIC(3, 2)
);

CREATE TABLE dbo.DimTotalSpent (
    TotalSpentID INT IDENTITY(1,1) PRIMARY KEY,  -- Auto-incremented primary key
    SubTotal DECIMAL(20, 2),                     -- Stores the subtotal amount
    Tax DECIMAL(20, 2),                          -- Stores the tax amount
    Freight DECIMAL(20, 2),                      -- Stores the freight/shipping cost
    TotalDue DECIMAL(20, 2),                     -- Stores the total due amount
    TotalSpent DECIMAL(20, 2)                    -- Stores the total amount spent
);