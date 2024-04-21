USE TKCar_MGT

;CREATE TABLE PrintConfig(
  company    char(2)       NOT NULL
, print_id   varchar(64)   NOT NULL
, print_grp  varchar(64)   NOT NULL
, split      int           NOT NULL
, background binary        NULL
, fields     nvarchar(max) NOT NULL
)

;ALTER TABLE PrintConfig ADD PRIMARY KEY(company, print_id, print_grp)
