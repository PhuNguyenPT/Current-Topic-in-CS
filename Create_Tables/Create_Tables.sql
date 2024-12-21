-- Use the default schema (dbo)
USE test;

-- Drop Dim Tables
DROP TABLE IF EXISTS test.dbo.FactCustomerChurn;
DROP TABLE IF EXISTS test.dbo.DimCustomer;
DROP TABLE IF EXISTS test.dbo.DimDate;
DROP TABLE IF EXISTS test.dbo.DimSalesPerson;

-- Drop User Defined Tables
DROP TABLE IF EXISTS test.dbo.DimTotalFreqScore;
DROP TABLE IF EXISTS test.dbo.DimChurnRatio;
DROP TABLE IF EXISTS test.dbo.DimRecencyScore;
DROP TABLE IF EXISTS test.dbo.DimTotalSpentScore;
DROP TABLE IF EXISTS test.dbo.DimChurnScore;
DROP TABLE IF EXISTS test.dbo.DimSalesPersonFreqScore;

-- Drop Duplicate Data Tables
DROP TABLE IF EXISTS CompanyX.Sales.Customer2;
DROP TABLE IF EXISTS CompanyX.Person.Person2;
DROP TABLE IF EXISTS CompanyX.Sales.Store2;
DROP TABLE IF EXISTS CompanyX.Person.BusinessEntity2;
DROP TABLE IF EXISTS CompanyX.Person.BusinessEntityAddress2;
DROP TABLE IF EXISTS CompanyX.Person.Address2
DROP TABLE IF EXISTS CompanyX.Person.StateProvince2;
DROP TABLE IF EXISTS CompanyX.Sales.SalesOrderHeader2;
DROP TABLE IF EXISTS CompanyX.Person.AddressType2;
DROP TABLE IF EXISTS CompanyX.Sales.SalesTerritory2;


--------------------------------------------------------------------------------------------------

-- Create Dim and Fact Tables


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


--------------------------------------------------------------------------------------------------

-- Create User Defined Tables

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


--------------------------------------------------------------------------------------------------

-- Create Duplicate Data Tables for Dims


-- Copy Sales.Customer to Sales.Customer2
SELECT * INTO CompanyX.Sales.Customer2
FROM CompanyX.Sales.Customer;

-- Copy Person.Person to Person.Person2
SELECT * INTO CompanyX.Person.Person2
FROM CompanyX.Person.Person;

-- Copy Sales.Store to Sales.Store2
SELECT * INTO CompanyX.Sales.Store2
FROM CompanyX.Sales.Store;

-- Copy Person.BusinessEntity to Person.BusinessEntity2
SELECT * INTO CompanyX.Person.BusinessEntity2
FROM CompanyX.Person.BusinessEntity;

-- Copy Person.BusinessEntityAddress to Person.BusinessEntityAddress2
SELECT * INTO CompanyX.Person.BusinessEntityAddress2
FROM CompanyX.Person.BusinessEntityAddress;

-- Copy Person.Address to Person.Address2
SELECT * INTO CompanyX.Person.Address2
FROM CompanyX.Person.Address;

-- Copy Person.StateProvince to Person.StateProvince2
SELECT * INTO CompanyX.Person.StateProvince2
FROM CompanyX.Person.StateProvince;

-- Copy Sales.SalesOrderHeader to Sales.SalesOrderHeader2
SELECT * INTO CompanyX.Sales.SalesOrderHeader2
FROM CompanyX.Sales.SalesOrderHeader;

-- Copy Person.AddressType to Person.AddressType2
SELECT * INTO CompanyX.Person.AddressType2
FROM CompanyX.Person.AddressType;

-- Copy Sales.SalesTerritory to Sales.SalesTerritory2
SELECT * INTO CompanyX.Sales.SalesTerritory2
FROM CompanyX.Sales.SalesTerritory;
