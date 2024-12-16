USE CompanyX;

-- Copy Sales.Customer to Sales.Customer2
SELECT * INTO Sales.Customer2
FROM Sales.Customer;

-- Copy Person.Person to Person.Person2
SELECT * INTO Person.Person2
FROM Person.Person;

-- Copy Sales.Store to Sales.Store2
SELECT * INTO Sales.Store2
FROM Sales.Store;

-- Copy Person.BusinessEntity to Person.BusinessEntity2
SELECT * INTO Person.BusinessEntity2
FROM Person.BusinessEntity;

-- Copy Person.BusinessEntityAddress to Person.BusinessEntityAddress2
SELECT * INTO Person.BusinessEntityAddress2
FROM Person.BusinessEntityAddress;

-- Copy Person.Address to Person.Address2
SELECT * INTO Person.Address2
FROM Person.Address;

-- Copy Person.StateProvince to Person.StateProvince2
SELECT * INTO Person.StateProvince2
FROM Person.StateProvince;

-- Copy Sales.SalesOrderHeader to Sales.SalesOrderHeader2
SELECT * INTO Sales.SalesOrderHeader2
FROM Sales.SalesOrderHeader;

-- Copy Person.AddressType to Person.AddressType2
SELECT * INTO Person.AddressType2
FROM Person.AddressType;

-- Copy Sales.SalesTerritory to Sales.SalesTerritory2
SELECT * INTO Sales.SalesTerritory2
FROM Sales.SalesTerritory;