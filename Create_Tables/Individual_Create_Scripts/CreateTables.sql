-- Use the default schema (dbo)
USE test;

DROP TABLE IF EXISTS dbo.FactCustomerChurn;
DROP TABLE IF EXISTS dbo.DimCustomer;
DROP TABLE IF EXISTS dbo.DimDate;
DROP TABLE IF EXISTS dbo.DimSalesPerson;

-- Create DimDate table in dbo schema
CREATE TABLE test.dbo.DimDate (
    DateID INT IDENTITY(1,1) PRIMARY KEY,
    Day INT NOT NULL,           -- Stores only the day of the month
    Month INT NOT NULL,
    Year INT NOT NULL,
    Quarter INT NOT NULL
);

-- Create DimCustomer table in dbo schema
CREATE TABLE test.dbo.DimCustomer (
    CustomerID INT PRIMARY KEY,
    FirstName NVARCHAR(255),
    MiddleName NVARCHAR(255),
    LastName NVARCHAR(255),
    CurrentRecency INT,
    CurrentRecencyScore INT,        -- To be populated later
    CurrentTotalFreq INT,
    CurrentTotalFreqScore INT,      -- To be populated later
    CurrentTotalSpent NUMERIC(20,2),-- To be populated later
    CurrentTotalSpentScore INT      -- To be populated later
);

CREATE TABLE test.dbo.FactCustomerChurn (
        FactID INT IDENTITY(1,1) PRIMARY KEY,        -- Unique identifier for each record
        DateID INT ,								 -- Foreign Key to DimDate table
        CustomerID INT ,							 -- Foreign Key to Customer table
        SalesOrderID INT,                            -- Identifier for a sales order
		SalesPersonID INT,
        SubTotal NUMERIC(20,2),                      -- Subtotal of a purchase
        Tax NUMERIC(20,2),                           -- Tax amount
        Freight NUMERIC(20,2),                       -- Freight cost
        TotalDue NUMERIC(20,2),                      -- Total amount due
        TotalSpent NUMERIC(20,2),                    -- Total spending by the customer
        SalesPersonFrequency INT,                    -- Total frequency of store orders
        SalesPersonFrequencyScore INT,               -- Frequency score per store
        TotalSpentScore FLOAT,                       -- Score for total spending
        TotalFrequency INT,                          -- Total frequency of customer orders
        TotalFrequencyScore INT,                     -- Total frequency score
        Recency INT,                                 -- Days since last interaction
        RecencyScore INT,                            -- Score for recency of interactions
        ChurnRatio NUMERIC(3,2),                     -- Ratio related to churn
        ChurnScore INT                               -- Score representing churn risk
    );

-- Create DimSalesPerson table in dbo schema
CREATE TABLE test.dbo.DimSalesPerson (
    PRIMARY KEY (SalesPersonID, CustomerID), -- Composite primary key
    SalesPersonID INT NOT NULL,
    FirstName NVARCHAR(255),
    MiddleName NVARCHAR(255),
    LastName NVARCHAR(255),
    CustomerID INT NOT NULL,
    CurrentSalesPersonFrequency INT,
    CurrentSalesPersonFrequencyScore INT
);