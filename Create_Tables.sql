-- Use the default schema (dbo)
USE test;

-- Create DimDate table in dbo schema
CREATE TABLE dbo.DimDate (
    DateID INT PRIMARY KEY,
    Day INT NOT NULL,           -- Stores only the day of the month
    Month INT NOT NULL,
    Year INT NOT NULL,
    Quarter INT NOT NULL
);

-- Create DimCustomer table in dbo schema
CREATE TABLE dbo.DimCustomer (
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
CREATE TABLE dbo.DimStore (
    StoreID INT IDENTITY(1,1) PRIMARY KEY,              -- From Sales.Store.BusinessEntityID
	BusinessEntityID INT,
    StoreName NVARCHAR(255),              -- From Sales.Store.Name
    AddressLine1 NVARCHAR(255),            -- From Person.Address.AddressLine1
    AddressLine2 NVARCHAR(255),            -- From Person.Address.AddressLine2
    PostalCode NVARCHAR(20),              -- From Person.Address.PostalCode
    CountryRegionCode NVARCHAR(2),       -- From Person.StateProvince.CountryRegionCode
    StateName NVARCHAR(255),               -- From Person.StateProvince.Name
    CurrentStoreFrequencyScore INT        -- To be populated later (left empty for now)
);