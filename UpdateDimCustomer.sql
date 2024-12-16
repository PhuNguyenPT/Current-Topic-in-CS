INSERT INTO [CompanyX].[Person].[Person2]
([BusinessEntityID], [PersonType], [NameStyle], [Title], [FirstName], [MiddleName], 
 [LastName], [Suffix], [EmailPromotion], [AdditionalContactInfo], [Demographics], 
 [rowguid], [ModifiedDate])
VALUES 
((SELECT MAX([BusinessEntityID]) + 1 FROM [CompanyX].[Person].[Person2]), 'EM', 0, 'Mr.', 'John', 'A.', 'Doe', NULL, 1, NULL, '<IndividualSurvey xmlns="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"><TotalPurchaseYTD>-19.5</TotalPurchaseYTD><DateFirstPurchase>2003-11-17Z</DateFirstPurchase><BirthDate>1971-05-05Z</BirthDate><MaritalStatus>M</MaritalStatus><YearlyIncome>75001-100000</YearlyIncome><Gender>F</Gender><TotalChildren>0</TotalChildren><NumberChildrenAtHome>0</NumberChildrenAtHome><Education>Bachelors </Education><Occupation>Professional</Occupation><HomeOwnerFlag>0</HomeOwnerFlag><NumberCarsOwned>4</NumberCarsOwned><CommuteDistance>10+ Miles</CommuteDistance></IndividualSurvey>', 
 NEWID(), GETDATE());

 