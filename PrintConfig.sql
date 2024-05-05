USE TKCar_UnitTest

-- DROP TABLE PrintConfig;

;CREATE TABLE PrintConfig(
  company    char(2)        NOT NULL
, print_id   varchar(64)    NOT NULL
, split      int            NOT NULL
, background varbinary(max) NULL
, fields     nvarchar(max)  NOT NULL
)

;ALTER TABLE PrintConfig ADD PRIMARY KEY(company, print_id)
