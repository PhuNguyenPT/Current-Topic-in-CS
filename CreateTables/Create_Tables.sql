-- Use the default schema (dbo)
USE test;

DROP TABLE IF EXISTS dbo.FactCustomerChurn;
DROP TABLE IF EXISTS dbo.DimCustomer;
DROP TABLE IF EXISTS dbo.DimDate;
DROP TABLE IF EXISTS dbo.DimStore;

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
    CurrentRecencyScore INT,        -- To be populated later
    CurrentTotalFreqScore INT,      -- To be populated later
    CurrentTotalSpent DECIMAL(18,2),-- To be populated later
    CurrentTotalSpentScore INT      -- To be populated later
);

-- Create DimStore table in dbo schema
CREATE TABLE test.dbo.DimStore (
    StoreID INT IDENTITY(1,1) PRIMARY KEY,              -- From Sales.Store.BusinessEntityID
	BusinessEntityID INT,
	SalesPersonID INT,
    StoreName NVARCHAR(255),              -- From Sales.Store.Name
    AddressLine1 NVARCHAR(255),            -- From Person.Address.AddressLine1
    AddressLine2 NVARCHAR(255),            -- From Person.Address.AddressLine2
    PostalCode NVARCHAR(20),              -- From Person.Address.PostalCode
    CountryRegionCode NVARCHAR(2),       -- From Person.StateProvince.CountryRegionCode
    StateName NVARCHAR(255),               -- From Person.StateProvince.Name
    CurrentStoreFrequencyScore INT        -- To be populated later (left empty for now)
);

--CREATE TABLE dbo.DimTotalSpent (
--    TotalSpentID INT IDENTITY(1,1) PRIMARY KEY,  -- Auto-incremented primary key
--    SubTotal DECIMAL(20, 2),                     -- Stores the subtotal amount
--   Tax DECIMAL(20, 2),                          -- Stores the tax amount
--    Freight DECIMAL(20, 2),                      -- Stores the freight/shipping cost
--    TotalDue DECIMAL(20, 2),                     -- Stores the total due amount
--    TotalSpent DECIMAL(20, 2)                    -- Stores the total amount spent
--);

CREATE TABLE test.dbo.FactCustomerChurn (
        FactID INT IDENTITY(1,1) PRIMARY KEY,        -- Unique identifier for each record
        DateID INT ,								 -- Foreign Key to DimDate table
        ChurnScore INT,                              -- Score representing churn risk
        ChurnRatio NUMERIC(3,2),                     -- Ratio related to churn
        TotalFrequencyScore INT,                     -- Total frequency score
        RecencyScore INT,                            -- Score for recency of interactions
        TotalSpentScore FLOAT,                       -- Score for total spending
        CustomerID INT ,							 -- Foreign Key to Customer table
        StoreID INT ,								 -- Foreign Key to Store table
        Recency INT,                                 -- Days since last interaction
        SalesOrderID INT,                            -- Identifier for a sales order
		SalesPersonID INT,
        TotalFrequency INT,                          -- Total frequency of customer orders
        TotalStoreFrequency INT,                     -- Total frequency of store orders
        StoreFrequencyScore INT,                     -- Frequency score per store
        StoreChurnRatio NUMERIC(3,2),                -- Store-specific churn ratio
        ProductID INT,                               -- Foreign Key to Product table
        SpecialOfferID INT,                          -- Foreign Key to Special Offer table
        SubTotal NUMERIC(20,2),                      -- Subtotal of a purchase
        Tax NUMERIC(20,2),                           -- Tax amount
        Freight NUMERIC(20,2),                       -- Freight cost
        TotalDue NUMERIC(20,2),                      -- Total amount due
        TotalSpent NUMERIC(20,2)                     -- Total spending by the customer
    );