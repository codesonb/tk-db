-- VERSION 2024 Apr 30

USE TKCar_UnitTest

DROP TABLE eInvoiceAudit;

;CREATE TABLE eInvoiceAudit(
  id         int           NOT NULL
, company    char(2)       NOT NULL
, cd_license varchar(30)   NOT NULL
, sent_type  varchar(16)   NOT NULL /* invoice or receipt */
, media_type varchar(16)   NOT NULL /* Email or WhatsApp */
, create_dtm datetime2     NOT NULL DEFAULT GETDATE()
, sent_by    varchar(64)   NOT NULL
, succeed    bit           NOT NULL DEFAULT 0
)

;ALTER TABLE eInvoiceAudit ADD PRIMARY KEY NONCLUSTERED(cd_license, id)
;CREATE CLUSTERED INDEX IX_einvAudit ON eInvoiceAudit (create_dtm)

;IF EXISTS (SELECT [name] FROM sys.database_principals WHERE type = N'S' AND [name] = 'tkuat')
  GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.eInvoiceAudit TO tkuat
 ELSE
  GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.eInvoiceAudit TO tkweb
GO