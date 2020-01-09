-- Step 1: Enable hadoop connectivity to Azure Blob Storage and ingestion into HDFS
-- STOP: SQL Server must be restarted for this to take effect
USE [master]
GO
sp_configure @configname = 'hadoop connectivity', @configvalue = 7;
GO
sp_configure 'allow polybase export', 1
GO
RECONFIGURE
GO

-- Step 2: Create master key if not done already in database
USE [WideWorldImporters]
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<password>'
GO

-- Step 3: Create a database scoped credential for access to Azure Blob Storage
-- IDENTITY: any string (this is not used for authentication to Azure storage).  
-- SECRET: your Azure storage account key.  
CREATE DATABASE SCOPED CREDENTIAL AzureStorageCredentials
WITH IDENTITY = 'user', Secret = '<storage account key>'
GO

-- Step 4: Create a datasource referencing the Azure Blog Storage container
-- TYPE: HADOOP
-- LOCATION:  Azure account storage account name and blob container name.  
-- CREDENTIAL: The database scoped credential created above.  
CREATE EXTERNAL DATA SOURCE bwdatalake with (  
      TYPE = HADOOP,
      LOCATION ='wasbs://wwi@<storage account>.blob.core.windows.net',  
      CREDENTIAL = AzureStorageCredentials 
)
GO

-- Step 5: Creae a format specification for the HDFS data
-- FORMAT TYPE: Type of format in Hadoop (DELIMITEDTEXT,  RCFILE, ORC, PARQUET).
CREATE EXTERNAL FILE FORMAT TextFileFormat WITH (  
      FORMAT_TYPE = DELIMITEDTEXT,
      FORMAT_OPTIONS (FIELD_TERMINATOR ='|',
            USE_TYPE_DEFAULT = TRUE))
GO

-- Step 6: Create a schema for external tabes for hdfs
CREATE SCHEMA hdfs
GO

-- Step 7: Create the external table
-- LOCATION: path to file or directory that contains the data (relative to HDFS root).
CREATE EXTERNAL TABLE [hdfs].[WWI_Order_Reviews] (  
      [OrderID] int NOT NULL,
      [CustomerID] int NOT NULL,
      [Rating] int NULL,
      [Review_Comments] nvarchar(1000) NOT NULL
)  
WITH (LOCATION='/WWI/',
      DATA_SOURCE = bwdatalake,  
      FILE_FORMAT = TextFileFormat  
)
GO

-- Step 8: Ingest some data lined up with a valid OrderID and CustomerID in the database
INSERT INTO [hdfs].[WWI_Order_Reviews] VALUES (1, 832, 10, 'I had a great experience with my order')
GO

-- Step 9: SQL Server allows you to store local statistics about specific columns from the remote table. This can help the query processing to make more efficient plan decisions.
CREATE STATISTICS StatsforReviews on [hdfs].[WWI_Order_Reviews](OrderID, CustomerID)
GO

-- Step 10: Now query the external table by scanning it
SELECT * FROM [hdfs].[WWI_Order_Reviews]
GO

-- Step 11: Let's do a filter to enable pushdown
SELECT * FROM [hdfs].[WWI_Order_Reviews]
WHERE OrderID = 1
GO

-- Step 12: Let's join the review with our order and customer data
SELECT o.OrderDate, c.CustomerName, p.FullName as SalesPerson, wor.Rating, wor.Review_Comments
FROM [Sales].[Orders] o
JOIN [hdfs].[WWI_Order_Reviews] wor
ON o.OrderID = wor.OrderID
JOIN [Application].[People] p
ON p.PersonID = o.SalespersonPersonID
JOIN [Sales].[Customers] c
ON c.CustomerID = wor.CustomerID
GO