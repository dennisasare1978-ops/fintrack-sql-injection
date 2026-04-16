CREATE TABLE CustomerTransactions (
    TransactionID    INT           IDENTITY(1,1) PRIMARY KEY,
    CustomerName     NVARCHAR(100) NOT NULL,
    CreditCardNumber NVARCHAR(20)  NOT NULL,
    CVV              INT           NOT NULL,
    SSN              NVARCHAR(11)  NULL,
    Balance          MONEY         NOT NULL,
    TransactionDate  DATETIME      NOT NULL DEFAULT GETDATE(),
    TransactionType  NVARCHAR(20)  NOT NULL DEFAULT 'PURCHASE'
);
GO

CREATE TABLE AuditLog (
    LogID     INT           IDENTITY(1,1) PRIMARY KEY,
    EventTime DATETIME      NOT NULL DEFAULT GETDATE(),
    Username  NVARCHAR(128) NOT NULL,
    Action    NVARCHAR(50)  NOT NULL,
    TableName NVARCHAR(128) NULL,
    OldValues NVARCHAR(MAX) NULL,
    NewValues NVARCHAR(MAX) NULL
);
GO
