-- 26 Apr 2022 / Main

--Create DB Script
/*
;PRINT 'Create DB - OLD'
;CREATE DATABASE [TKCar_Old] ON PRIMARY
  ( NAME = 'TKOld_Data', FILENAME=N'E:\_MSSQL\data\TKCar_Old_0427.mdf' )
 LOG ON
  ( NAME = 'TKOld_Log', FILENAME=N'E:\_MSSQL\data\TKCar_Old_0427.ldf' )
 COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
GO
*/

;PRINT 'Starting migration process'
------------------------------------------------------------
--;DROP TABLE IF EXISTS [dbo].[SystemConfig]
--;DROP TABLE IF EXISTS [dbo].[Leave]
--;DROP TABLE IF EXISTS [dbo].[Employee]
--;DROP TABLE IF EXISTS [dbo].[EmployeeContract]
--;DROP TABLE IF EXISTS [dbo].[Invoice]
--;DROP TABLE IF EXISTS [dbo].[BillArchive]
--;DROP TABLE IF EXISTS [dbo].[Bill]
--;DROP TABLE IF EXISTS [dbo].[UnitService]
--;DROP TABLE IF EXISTS [dbo].[TKOrder]
--;DROP TABLE IF EXISTS [dbo].[TKOrderItem]
--;DROP TABLE IF EXISTS [dbo].[ServicePlan]
--;DROP TABLE IF EXISTS [dbo].[VehicleService]
--;DROP TABLE IF EXISTS [dbo].[Vehicle]
--;DROP TABLE IF EXISTS [dbo].[WorkerLocation]
--;DROP TABLE IF EXISTS [dbo].[ServiceLocation]
--;DROP TABLE IF EXISTS [dbo].[SuspendedService]
--;DROP TABLE IF EXISTS [dbo].[Contact]
--;DROP TABLE IF EXISTS [dbo].[Customer]
--;DROP TABLE IF EXISTS [dbo].[Worker]
--;DROP TABLE IF EXISTS [dbo].[TKUser]
--;DROP TABLE IF EXISTS [dbo].[AuditTrail]
--;DROP TABLE IF EXISTS [dbo].[AuditError]
------------------------------------------------------------

-- INSERT INTO SystemConfig(dict_key, grp_key, c_value1, c_value2, c_order)
-- SELECT '_', 'RECOVER', 3, 2, 1

-- construct information from old database

;USE [TKCar_Old]
GO

;PRINT 'Dropping old DB index'
;DECLARE curIX CURSOR FORWARD_ONLY STATIC READ_ONLY
  FOR
    SELECT
      sqle = 'DROP INDEX ['+ix.name+'] ON [TKCar_Old].[dbo].['+tb.TABLE_NAME+']'
    FROM SYS.INDEXES AS ix
    JOIN INFORMATION_SCHEMA.TABLES AS tb
    ON (ix.object_id = Object_ID(tb.TABLE_NAME))
    WHERE type <> 0
      AND TABLE_NAME NOT LIKE '[_]%'
    ORDER BY tb.TABLE_NAME

;DECLARE @sql varchar(max)
OPEN curIX
  FETCH NEXT FROM curIX INTO @sql
  WHILE (@@FETCH_STATUS = 0)
  BEGIN
    EXEC (@sql)
    FETCH NEXT FROM curIX INTO @sql
  END
CLOSE curIX
DEALLOCATE curIX
GO

-- convert column collation
;PRINT 'Ensuring DB collations'
;ALTER DATABASE TKCar_Old
 COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
GO

;DECLARE curCol CURSOR FORWARD_ONLY STATIC READ_ONLY
  FOR
    SELECT
      sqle = 'ALTER TABLE ['+TABLE_CATALOG+'].['+TABLE_SCHEMA+'].['+TABLE_NAME+'] ALTER COLUMN ['+COLUMN_NAME+'] '
           + DATA_TYPE+'('+
             (CASE WHEN CHARACTER_MAXIMUM_LENGTH > 8000
                THEN 'max'
                ELSE CAST(CHARACTER_MAXIMUM_LENGTH AS varchar)
              END)+') COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8'
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE DATA_TYPE IN ('varchar', 'nvarchar', 'text', 'ntext')
      AND TABLE_NAME NOT LIKE '[_]%'

;DECLARE @sql varchar(max)
OPEN curCol
  FETCH NEXT FROM curCol INTO @sql
  WHILE (@@FETCH_STATUS = 0)
  BEGIN
    EXEC (@sql)
    FETCH NEXT FROM curCol INTO @sql
  END
CLOSE curCol
DEALLOCATE curCol

GO
;PRINT 'Removing FULL-font license plate numbers'
;UPDATE TKCar_Old.dbo.MR_Car
  SET CAR_CarNumber    = REPLACE(Translate(UPPER(CAR_CarNumber), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'), ' ', '')
     ,CAR_CarType      = Translate(UPPER(CAR_CarType), '０１２３４５６７８９', '0123456789')
     ,CAR_HouseCode    = Translate(UPPER(CAR_HouseCode), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
     ,CAR_WorkerCode   = Translate(UPPER(CAR_WorkerCode), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
     ,CAR_Servicedate1 = Translate(UPPER(CAR_Servicedate1), '０１２３４５６７８９', '0123456789')
     ,CAR_Servicedate2 = Translate(UPPER(CAR_Servicedate2), '０１２３４５６７８９', '0123456789')
     ,CAR_Servicedate3 = Translate(UPPER(CAR_Servicedate3), '０１２３４５６７８９', '0123456789')
;UPDATE TKCar_Old.dbo.TX_ServiceChangeRecord
  SET SCR_CarNumber    = REPLACE(Translate(UPPER(SCR_CarNumber), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'), ' ', '')
     ,SCR_ChangeItem   = Translate(UPPER(SCR_ChangeItem), '０１２３４５６７８９', '0123456789')
     ,SCR_CarType      = Translate(UPPER(SCR_CarType), '０１２３４５６７８９', '0123456789')
     ,SCR_HouseCode    = Translate(UPPER(SCR_HouseCode), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
     ,SCR_WorkerCode   = Translate(UPPER(SCR_WorkerCode), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
     ,SCR_Servicedate1 = Translate(UPPER(SCR_Servicedate1), '０１２３４５６７８９', '0123456789')
     ,SCR_Servicedate2 = Translate(UPPER(SCR_Servicedate2), '０１２３４５６７８９', '0123456789')
     ,SCR_Servicedate3 = Translate(UPPER(SCR_Servicedate3), '０１２３４５６７８９', '0123456789')
;UPDATE TKCar_Old.dbo.TX_PaymentReceipt
  SET PAY_CarNumber    = REPLACE(Translate(UPPER(PAY_CarNumber), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'), ' ', '')

-- Move old data on or before 2017-Dec-31
IF NOT EXISTS(SELECT TOP 1 1 FROM TKCar_Old.dbo.TX_PaymentReceipt WHERE PAY_Year <= 2015)
  INSERT INTO TKCar_Old.dbo.TX_PaymentReceipt
  SELECT * FROM TKOld_May.dbo.TX_PaymentReceipt
  WHERE PAY_Date < '2018-01-01'
GO

;PRINT 'Rebuilding old DB index'
;CREATE CLUSTERED INDEX CIX_MRCAR ON TKCar_Old.dbo.MR_Car (CAR_CarNumber, CAR_CompanyCode)
;CREATE CLUSTERED INDEX CIX_TXPAY ON TKCar_Old.dbo.TX_PaymentReceipt (PAY_CarNumber)
;CREATE CLUSTERED INDEX CIX_TXSCR ON TKCar_Old.dbo.TX_ServiceChangeRecord (SCR_CarNumber, SCR_CompanyCode, SCR_UpdateDate DESC)

GO

;PRINT 'Remove wrong record'
;DELETE TKCar_Old.dbo.TX_ServiceChangeRecord WHERE SCR_CarNumber IS NULL OR SCR_CarNumber = ''

GO

--====================================================
--== Build new Database                             ==
--====================================================

;PRINT 'Making new Databases'
;USE [master]
GO
;DROP DATABASE IF EXISTS [TKCar_MGT]
GO

;CREATE DATABASE [TKCar_MGT] ON PRIMARY
  ( NAME = 'TKCar_Data', FILENAME=N'E:\_MSSQL\data\TKCar_MGT.mdf' )
 LOG ON
  ( NAME = 'TKCar_Log', FILENAME=N'E:\_MSSQL\data\TKCar_MGT.ldf' )
 COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
GO

;USE [TKCar_MGT]
;PRINT 'Recreated Database'
GO

;PRINT 'Granting application user right'
;CREATE USER tkweb FROM LOGIN tkweb
;ALTER USER tkweb WITH DEFAULT_SCHEMA = TKCar_MGT
;ALTER ROLE db_datareader ADD MEMBER tkweb
;ALTER ROLE db_datawriter ADD MEMBER tkweb
;ALTER ROLE db_backupoperator ADD MEMBER tkweb

-- CREATE TABLES
;PRINT 'creating SystemConfig table'
;CREATE TABLE SystemConfig (
   dict_key  varchar(30)    NOT NULL
  ,grp_key   varchar(30)    NOT NULL
  ,c_value1  nvarchar(120)  NOT NULL
  ,c_value2  nvarchar(512)
  ,c_order   int            NOT NULL
  ,CONSTRAINT PK_syscfg PRIMARY KEY (dict_key, grp_key, c_value1)
)

;PRINT 'creating AuditTrail table'
;CREATE TABLE AuditTrail (
   req_dtm      datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,req_ip       varchar(30)   NOT NULL
  ,http_method  varchar(10)   NOT NULL
  ,req_url      varchar(max)  NOT NULL
  ,login_name   varchar(24)   NOT NULL
)

;PRINT 'creating AuditError table'
;CREATE TABLE AuditError (
	create_dtm    datetime2(7) NULL,
  caller_class  varchar(max) NULL,
  caller_member varchar(max) NULL,
	msg           varchar(max) NULL
)

;PRINT 'creating ServiceLocation table'
;CREATE TABLE ServiceLocation (
   srv_dis   varchar(3)     NOT NULL -- District
  ,srv_loc   smallint       NOT NULL -- Code
  ,mgt_dis   varchar(5)     NOT NULL
  ,cd_fleet  varchar(8)     NOT NULL
  ,lhs_cmr   bit            NOT NULL DEFAULT 0 -- Leisure Home Service commission rate
  ,name_zh   nvarchar(50)   NOT NULL
  ,name_en   nvarchar(80)
  ,srv_addr  nvarchar(1000)
  ,lat       float
  ,lng       float
  ,mpf       bit            NOT NULL DEFAULT 0
--,payac     varchar(20)   -- reserved for FPS receive account ID
--,rmwac     varchar(20)   -- reserved for sending bill reminder: Whatsapp
  ,CONSTRAINT PK_srvloc PRIMARY KEY(srv_dis, srv_loc)
)

;PRINT 'creating ServicePlan table'
;CREATE TABLE ServicePlan (
   srv_dis    varchar(3)    NOT NULL -- District
  ,srv_loc    smallint      NOT NULL -- Code
  ,company    char(2)       NOT NULL
  ,cd_plan    char(1)       NOT NULL
  ,vh_type    tinyint       NOT NULL
  ,price      decimal(15,2) NOT NULL
  ,salary     decimal(15,2) NOT NULL
  ,effect     date          NOT NULL
  ,create_dtm datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,create_by  nvarchar(50)  NOT NULL DEFAULT '#sa'
  ,CONSTRAINT PK_srvPlan PRIMARY KEY (srv_dis, srv_loc, cd_plan, vh_type, effect DESC, company)
  ,CONSTRAINT FX_plan_loc FOREIGN KEY (srv_dis, srv_loc)
      REFERENCES ServiceLocation (srv_dis, srv_loc)
      ON UPDATE CASCADE
      ON DELETE CASCADE
)

;PRINT 'creating TKUser table'
;CREATE TABLE TKUser (
   id           int IDENTITY(1,1) NOT NULL
  ,login_name   varchar(24)
  ,login_pswd   binary(96)
  ,display_name nvarchar(max) NOT NULL
  ,role         varchar(8)    NOT NULL
  ,active       bit           NOT NULL DEFAULT 1
  ,create_dtm   datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_dtm      datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by       nvarchar(50)  NOT NULL DEFAULT '#sa'
  ,remarks      nvarchar(max) SPARSE
  ,CONSTRAINT PK_User PRIMARY KEY CLUSTERED(id)
  ,INDEX UX_usr UNIQUE NONCLUSTERED (login_name) WHERE login_name IS NOT NULL
)

;PRINT 'creating Contact table'
;CREATE TABLE Contact (
   uid      int           NOT NULL
  ,c_type   tinyint       NOT NULL --     BillWhatsApp = 1, BillEmail = 2, BillAddress = 3, Tel = 10, Mobile = 11, Fax = 12, EMail = 13, Address = 20
  ,c_sal    nvarchar(50)  NOT NULL
  ,c_name   nvarchar(50)  NOT NULL
  ,c_num    varchar(120)  NOT NULL DEFAULT ''
  ,c_addr   nvarchar(max) SPARSE
  ,mod_dtm  datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,CONSTRAINT FX_contact_usr FOREIGN KEY (uid)
      REFERENCES TKUser(id)
  ,INDEX IX_Contact_num CLUSTERED (c_num)
  ,INDEX IX_Contact_usr NONCLUSTERED (uid)
)

;PRINT 'creating Customer table'
;CREATE TABLE Customer (
   id              int           NOT NULL
  ,whatsapp        varchar(50)
  ,email           varchar(120)
  ,last_reunion    datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,last_payment    datetime2
  ,balance         decimal(15,2) NOT NULL DEFAULT 0.0
  ,is_mobill       bit           NOT NULL DEFAULT 0
  ,is_rtn_envelope bit           NOT NULL DEFAULT 0
  ,is_print_bill   bit           NOT NULL DEFAULT 0
  ,mod_dtm         datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by          nvarchar(50)  NOT NULL
  ,CONSTRAINT PK_Customer PRIMARY KEY (id)
  ,CONSTRAINT FK_Customer FOREIGN KEY (id)
    REFERENCES TKUser (id)
)

;PRINT 'creating Employee table'
;CREATE TABLE Employee (
   uid        int           NOT NULL
  ,hkid       varchar(10)      NULL
  ,employ_dtm date          NOT NULL
  ,resign_dtm date
  ,supervisor int
  ,is_manager bit           NOT NULL DEFAULT 0
  ,create_dtm datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_dtm    datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by     nvarchar(50)  NOT NULL
  ,CONSTRAINT PK_Employee PRIMARY KEY (uid)
  ,CONSTRAINT FK_ey_usr FOREIGN KEY (uid)
      REFERENCES TKUser(id)
  ,CONSTRAINT FK_ey_ey FOREIGN KEY (supervisor)
      REFERENCES Employee(uid)
)

;PRINT 'creating EmployeeContract table'
;CREATE TABLE EmployeeContract (
   uid        int           NOT NULL
  ,start_dtm  date          NOT NULL
  ,end_dtm    date
  ,title      varchar(100)  NOT NULL
  ,c_rank     varchar(10)
  ,salary     decimal(15,2) NOT NULL DEFAULT 0.00
  ,al_count   int           NOT NULL DEFAULT 7
  ,create_dtm datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_dtm    datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by     nvarchar(50)  NOT NULL
  ,CONSTRAINT PK_EmployeeContract PRIMARY KEY (uid, start_dtm)
  ,CONSTRAINT FK_ec_usr FOREIGN KEY (uid)
      REFERENCES TKUser(id)
)

;PRINT 'creating Worker table'
;CREATE TABLE Worker (
   uid          int          NOT NULL
  ,worker_code  varchar(20)  NOT NULL
  ,work_type    char(1)      NOT NULL DEFAULT ''
  ,salary_A     int              NULL
  ,salary_B     int              NULL
  ,salary_C     int              NULL
  ,bonus_A      int          NOT NULL
  ,bonus_B      int          NOT NULL
  ,bonus_C      int          NOT NULL
  ,bonus_extra  int          NOT NULL
  ,allowance    int          NOT NULL DEFAULT 0
  ,calc_wax_sal bit          NOT NULL DEFAULT 1
  ,calc_rot_sal bit          NOT NULL DEFAULT 1
  ,CONSTRAINT PK_wkr PRIMARY KEY (uid)
  ,CONSTRAINT FK_wkr_usr FOREIGN KEY (uid)
      REFERENCES TKUser(id)
)

;PRINT 'creating WorkerLocation table'
;CREATE TABLE WorkerLocation (
   uid        int           NOT NULL
  ,srv_dis    varchar(3)    NOT NULL
  ,srv_loc    smallint      NOT NULL
  ,srv_floor  nvarchar(50)
  ,work_type  tinyint       NOT NULL DEFAULT 0
  ,create_dtm datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_dtm    datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by     nvarchar(50)  NOT NULL
  ,CONSTRAINT PK_wkrloc PRIMARY KEY (uid, srv_dis, srv_loc)
  ,CONSTRAINT FK_wkrloc_usr FOREIGN KEY (uid)
      REFERENCES TKUser(id)
  ,CONSTRAINT FK_wkrloc_loc FOREIGN KEY (srv_dis, srv_loc)
      REFERENCES ServiceLocation(srv_dis, srv_loc)
      ON UPDATE CASCADE
)

;PRINT 'creating Leave table'
;CREATE TABLE Leave (
   uid        int           NOT NULL
  ,leave_type tinyint       NOT NULL DEFAULT 0
  ,pay_ratio  decimal(5, 4) NOT NULL DEFAULT 0
  ,leave_dtm  date          NOT NULL
  ,mod_dtm    datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by     nvarchar(50)  NOT NULL
  ,CONSTRAINT PK_leave PRIMARY KEY (leave_dtm DESC, uid)
  ,CONSTRAINT FK_leave_usr FOREIGN KEY (uid)
      REFERENCES TKUser(id)
)

;PRINT 'creating Vehicle table'
;CREATE TABLE Vehicle (
   cd_license varchar(30)  NOT NULL
  ,owner_id   int          NOT NULL
  ,vh_type    tinyint      NOT NULL
  ,source     tinyint      NOT NULL DEFAULT 0
  ,color      nvarchar(10)
  ,brand      nvarchar(50)
  ,model      nvarchar(30)
  ,create_dtm datetime2    NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_dtm    datetime2    NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by     nvarchar(50) NOT NULL
  ,deleted    bit          NOT NULL DEFAULT 0
  ,remarks    nvarchar(max) SPARSE
  ,CONSTRAINT PK_Vehicle PRIMARY KEY (cd_license, owner_id)
  ,CONSTRAINT FK_vh_usr FOREIGN KEY (owner_id)
      REFERENCES TKUser(id)
)

;PRINT 'creating VehicleService table'
;CREATE TABLE VehicleService (
   company     char(2)       NOT NULL
  ,cd_license  varchar(30)   NOT NULL
  ,owner_id    int           NOT NULL
  ,vh_type     tinyint       NOT NULL
  ,srv_plan    char(1)       NOT NULL
  ,reg_dtm     date          NOT NULL
  ,start_dtm   date          NOT NULL
  ,end_dtm     date
  ,fee         decimal(15,2) NOT NULL DEFAULT 0
  ,srv_dis     varchar(3)    NOT NULL
  ,srv_loc     smallint      NOT NULL
  ,srv_floor   nvarchar(12)  NOT NULL
  ,srv_psn     nvarchar(50)  NOT NULL -- Parking Space Number
  ,weekday1    tinyint       NOT NULL
  ,weekday2    tinyint       NOT NULL
  ,weekday3    tinyint       NOT NULL
  ,rotation    varchar(160)
  ,extra_fee   decimal(15,2) NOT NULL DEFAULT 0
  ,waxing      bit           NOT NULL DEFAULT 0
  ,worker      int           NOT NULL
  ,create_dtm  datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,create_by   nvarchar(50)  NOT NULL
  ,CONSTRAINT FK_vhsrv_vh FOREIGN KEY (cd_license, owner_id)
      REFERENCES Vehicle(cd_license, owner_id)
  ,CONSTRAINT FK_vhsrv_srvloc FOREIGN KEY (srv_dis, srv_loc)
      REFERENCES ServiceLocation(srv_dis, srv_loc)
      ON UPDATE CASCADE
  ,CONSTRAINT FK_vhsrv_wkr FOREIGN KEY (worker)
      REFERENCES TKUser(id)
  -- unique constraint
  ,INDEX UX_vhsrv_vh UNIQUE NONCLUSTERED (cd_license, company) WHERE end_dtm IS NULL
  -- quick license search for daily operation, also possible index join
  ,INDEX IX_vhsrv_vh CLUSTERED (cd_license, start_dtm)
)

-- quick schedule search for workers
;CREATE NONCLUSTERED INDEX IX_vhsrv_wk ON VehicleService(worker, srv_plan) INCLUDE (cd_license)

;PRINT 'creating unit service group table'
;CREATE TABLE UnitServiceGroup (
   id          int IDENTITY(1,1)
  ,grp_name    varchar(200)    NOT NULL
  ,parent_id   int
  ,CONSTRAINT FK_srvGrp_srvGrp FOREIGN KEY (parent_id)
     REFERENCES UnitServiceGroup (id)
  ,CONSTRAINT PK_srvGrp PRIMARY KEY (id)
)

;PRINT 'creating unit services table'
;CREATE TABLE UnitService (
   id          int IDENTITY(1,1)
  ,srv_grp     int               NOT NULL
  ,srv_name    nvarchar(200)     NOT NULL
  ,srv_desc    nvarchar(max)     NOT NULL
  ,srv_img     varchar(max)
  ,price       decimal(15, 2)    NOT NULL
  ,create_dtm  datetime2         NOT NULL   DEFAULT CURRENT_TIMESTAMP
  ,mod_dtm     datetime2         NOT NULL   DEFAULT CURRENT_TIMESTAMP
  ,mod_by      varchar(200)
  ,CONSTRAINT FK_usrv_srvGrp FOREIGN KEY (srv_grp)
     REFERENCES UnitServiceGroup (id)
  ,CONSTRAINT PK_usrv PRIMARY KEY(id)
)

;PRINT 'creating order table'
;CREATE TABLE TKOrder (
   id             int IDENTITY(1,1)
  ,company        char(2)           NOT NULL
  ,ix_yrmo        AS Year(order_dtm)*100 + Month(order_dtm) PERSISTED NOT NULL
  ,cust_id        int               NOT NULL
  ,cd_license     varchar(30)
  ,o_status       tinyint           NOT NULL   DEFAULT 0 -- Ordered = 0, Cancelled = 1, Rejected = 2, Holdup = 8, Followup = 9, Processing = 10, Delivering = 11, Delivered = 12
  ,payment_type   char(1)           NOT NULL   -- A: Adjustment, C:Cash, T:Transfer, Q:cheQue, F:Fps, P:Payme, X:bad debt, Z:compensation
  ,payment_ref    nvarchar(max)
  ,payment_amount decimal(15, 2)    NOT NULL   DEFAULT 0
  ,order_dtm      datetime2         NOT NULL   DEFAULT CURRENT_TIMESTAMP
  ,create_dtm     datetime2         NOT NULL   DEFAULT CURRENT_TIMESTAMP
  ,mod_dtm        datetime2         NOT NULL   DEFAULT CURRENT_TIMESTAMP
  ,mod_by         varchar(200)
  ,srv_addr       varchar(max)      SPARSE
  ,remarks        varchar(max)      SPARSE
  ,CONSTRAINT FK_odr_cust FOREIGN KEY (cust_id)
     REFERENCES Customer(id)
  ,CONSTRAINT PK_odr PRIMARY KEY(ix_yrmo DESC, id)
  ,CONSTRAINT UQ_id UNIQUE (id)
)
;CREATE NONCLUSTERED INDEX IX_odr ON TKOrder (cust_id, order_dtm DESC) INCLUDE (ix_yrmo, id)

;PRINT 'creating order item table'
;CREATE TABLE TKOrderItem (
   oid          int
  ,item_id      int
  ,qty          int
  ,unit_price   decimal(15, 2)  -- price on order date
  ,discount     decimal(15, 2)
  ,delivery_dtm datetime2
  ,CONSTRAINT FK_oitm_odr FOREIGN KEY (oid)
     REFERENCES TKOrder (id)
  ,CONSTRAINT FK_oitm_srv FOREIGN KEY (item_id)
     REFERENCES UnitService (id)
  ,INDEX IX_oitm_oid CLUSTERED (oid ASC)
)

;PRINT 'creating SuspendedService table'
;CREATE TABLE SuspendedService (
   ix_yrmo      AS Year(end_dtm)*100 + Month(end_dtm)
  ,company      char(2)       NOT NULL
  ,cd_license   varchar(30)   NOT NULL
  ,owner_id     int           NOT NULL
  ,srv_plan     char(1)       NOT NULL
  ,reg_dtm      date          NOT NULL
  ,end_dtm      date          NOT NULL
  ,fee          decimal(15,2) NOT NULL DEFAULT 0
  ,extra_fee    decimal(15,2) NOT NULL DEFAULT 0
  ,worker       int           NOT NULL
  ,worker_name  nvarchar(50)  NOT NULL
  ,reason_id    tinyint       NOT NULL
  ,is_terminate bit           NOT NULL
  ,remarks      nvarchar(max) SPARSE
  ,create_dtm   datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,create_by    nvarchar(50)  NOT NULL
  ,cix_yrmo     AS Convert(int, Year(create_dtm)*100+Month(create_dtm)) PERSISTED NOT NULL
  ,CONSTRAINT PK_SuspendedService PRIMARY KEY NONCLUSTERED (cd_license, company, end_dtm)
  ,INDEX IX_spsrv_ixyrmo CLUSTERED (ix_yrmo DESC)
)

;CREATE NONCLUSTERED INDEX IX_spsrv_create ON SuspendedService(cix_yrmo) INCLUDE (ix_yrmo, create_dtm)

;PRINT 'creating Bill table'
;CREATE TABLE Bill (
   company    char(2)       NOT NULL
  ,ix_yrmo    int           NOT NULL DEFAULT YEAR(CURRENT_TIMESTAMP)*100+MONTH(CURRENT_TIMESTAMP)
  ,uid        int           NOT NULL
  ,cd_license varchar(30)   NOT NULL
  ,bill_type  tinyint       NOT NULL
  ,create_dtm datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,amount     decimal(15,2) NOT NULL
  ,discount   decimal(15,2) NOT NULL
  ,bill_start date          NOT NULL
  ,bill_end   date          NOT NULL
  ,due_dtm    datetime2     NOT NULL
  ,remarks    nvarchar(max) SPARSE
  ,CONSTRAINT FX_bill_usr FOREIGN KEY (uid)
        REFERENCES TKUser (id)
  ,INDEX IX_Bill CLUSTERED ( uid, ix_yrmo DESC, bill_type, cd_license )
)

;PRINT 'creating BillArchive table'
;CREATE TABLE BillArchive (
   company    char(2)       NOT NULL
  ,ix_yrmo    int           NOT NULL
  ,uid        int           NOT NULL
  ,cd_license varchar(30)   NOT NULL
  ,bill_type  tinyint       NOT NULL
  ,create_dtm datetime2     NOT NULL
  ,amount     decimal(15,2) NOT NULL
  ,discount   decimal(15,2) NOT NULL
  ,bill_start date          NOT NULL
  ,bill_end   date          NOT NULL
  ,due_dtm    datetime2     NOT NULL
  ,iv_ix      int
  ,iv_seq     tinyint
  ,remarks    nvarchar(max) SPARSE
  ,INDEX IX_BillArchive CLUSTERED ( ix_yrmo DESC, uid )
)

;CREATE NONCLUSTERED INDEX IX_BAIV
  ON BillArchive ( uid, iv_ix DESC, iv_seq )
  INCLUDE (cd_license, ix_yrmo)
  WHERE iv_ix IS NOT NULL

;PRINT 'creating Payment table'
;CREATE TABLE Payment (
   company       char(2)       NOT NULL
  ,ix_yrmo       int           NOT NULL
  ,uid           int           NOT NULL
  ,useq          tinyint       NOT NULL
  ,cd_license    varchar(max)  NOT NULL
  ,cust_name     nvarchar(50)  NOT NULL
  ,amount        decimal(15,2) NOT NULL
  ,payment_type  char(1)       NOT NULL -- A: Adjustment, C:Cash, T:Transfer, Q:cheQue, F:Fps, P:Payme, X:bad debt, Z:compensation
  ,ref_code      nvarchar(120)
  ,transfer_dtm  datetime2
  ,create_dtm    datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,create_by     nvarchar(max) NOT NULL
  ,mod_dtm       datetime2     NOT NULL DEFAULT CURRENT_TIMESTAMP
  ,mod_by        nvarchar(max) NOT NULL
  ,remarks       nvarchar(max) SPARSE
  ,ix_chq AS (CASE WHEN payment_type ='Q' THEN Right(ref_code, 7) ELSE NULL END)
  ,CONSTRAINT PK_Invoice PRIMARY KEY (ix_yrmo DESC, uid, useq)
)
GO

CREATE NONCLUSTERED INDEX IX_CHEQUEREF ON Payment( ix_chq ASC ) WHERE payment_type = 'Q'


GO

;PRINT '-------------------------'
;PRINT '---Created data tables---'
;PRINT '-------------------------'

--===========================================================================
--
--  Database Migration
--
--===========================================================================

-- stage 1
;PRINT 'making system config data'
;INSERT INTO SystemConfig(dict_key, grp_key, c_value1, c_value2, c_order)
VALUES
('CORS', 'DOMAIN', '127.0.0.1', NULL, 1),
('CORS', 'DOMAIN', 'localhost', NULL, 1),
('DATA', 'COMPANY', 'TK', N'天記', 1),
('DATA', 'COMPANY', 'KY', N'專業', 2),
('DATA', 'COMPANY', 'PF', N'優質', 3),
('DATA', 'DISTRICT', 'V', N'UAT Zone',0),
('DATA', 'DISTRICT', 'D', N'將軍澳',1),
('DATA', 'DISTRICT', 'H', N'香港',2),
('DATA', 'DISTRICT', 'KA', N'九龍 A',3),
('DATA', 'DISTRICT', 'KB', N'九龍 B',4),
('DATA', 'DISTRICT', 'M', N'屯門',5),
('DATA', 'DISTRICT', 'N', N'元朗',6),
('DATA', 'DISTRICT', 'T', N'沙田',7),
('DATA', 'DISTRICT', 'W', N'葵青區',8),
('DATA', 'DISTRICT', 'Y', N'大埔',9),
('DATA', 'DISTRICT', 'X', N'其他',9999),
('DATA', 'PLAN', 'A', NULL, 1),
('DATA', 'PLAN', 'B', NULL, 2),
('DATA', 'PLAN', 'C', NULL, 3),
('DATA', 'PLAN', 'D', NULL, 4),
('DATA', 'VHTYPE', '1', '1800cc以下車輛', 1),
('DATA', 'VHTYPE', '2', '1800cc以上及電動車', 2),
('DATA', 'VHTYPE', '3', '七人車及客貨車', 3),
('DATA', 'PRICE', 'A1', '440', 1),
('DATA', 'PRICE', 'A2', '470', 1),
('DATA', 'PRICE', 'A3', '500', 1),
('DATA', 'PRICE', 'B1', '370', 1),
('DATA', 'PRICE', 'B2', '400', 1),
('DATA', 'PRICE', 'B3', '430', 1),
('DATA', 'PRICE', 'C1', '290', 1),
('DATA', 'PRICE', 'C2', '310', 1),
('DATA', 'PRICE', 'C3', '330', 1),
('DATA', 'SALARY', 'A1', '195', 1),
('DATA', 'SALARY', 'A2', '195', 1),
('DATA', 'SALARY', 'A3', '195', 1),
('DATA', 'SALARY', 'B1', '155', 1),
('DATA', 'SALARY', 'B2', '155', 1),
('DATA', 'SALARY', 'B3', '155', 1),
('DATA', 'SALARY', 'C1', '105', 1),
('DATA', 'SALARY', 'C2', '105', 1),
('DATA', 'SALARY', 'C3', '105', 1),
('DATA', 'BONUS', 'A', '400', 1),
('DATA', 'BONUS', 'B', '300', 1),
('DATA', 'BONUS', 'C', '200', 1),
('DATA', 'BONUS', 'EXTRA', '100', 1),
('DATA', 'SALARY_EX', 'ROTATION', '50', 1),
('DATA', 'SALARY_EX', 'WAXING', '15', 1)

;INSERT INTO SystemConfig(dict_key, grp_key, c_value1, c_value2, c_order)
VALUES
('DATA', 'BRAND', 'Alfa Romeo', '愛快·羅密歐', 1),
('DATA', 'BRAND', 'Alpine', '阿爾派', 2),
('DATA', 'BRAND', 'Aston Martin', '雅士頓·馬田', 3),
('DATA', 'BRAND', 'Audi', '奧迪', 4),
('DATA', 'BRAND', 'Bentley', '賓利', 5),
('DATA', 'BRAND', 'BMW', '寶馬', 6),
('DATA', 'BRAND', 'Dongfeng', '東風', 7),
('DATA', 'BRAND', 'Ferrari', '法拉利', 8),
('DATA', 'BRAND', 'Fiat', '快意', 9),
('DATA', 'BRAND', 'Ford', '福特', 10),
('DATA', 'BRAND', 'Honda', '本田', 11),
('DATA', 'BRAND', 'Hyundai', '現代', 12),
('DATA', 'BRAND', 'Infiniti', 'Infiniti', 13),
('DATA', 'BRAND', 'Isuzu', '五十鈴', 14),
('DATA', 'BRAND', 'Jaguar', '捷豹', 15),
('DATA', 'BRAND', 'Jeep', '吉普', 16),
('DATA', 'BRAND', 'Kia', '起亞', 17),
('DATA', 'BRAND', 'Lamborghini', '林寶堅尼', 18),
('DATA', 'BRAND', 'Land Rover', '越野路華', 19),
('DATA', 'BRAND', 'Lexus', '凌志', 20),
('DATA', 'BRAND', 'Lotus', '蓮花', 21),
('DATA', 'BRAND', 'Maserati', '瑪莎拉蒂', 22),
('DATA', 'BRAND', 'Maxus', '上汽大通', 23),
('DATA', 'BRAND', 'Mazda', '萬事得', 24),
('DATA', 'BRAND', 'McLaren', '麥拿倫', 25),
('DATA', 'BRAND', 'Mercedes-Benz', '奔馳', 26),
('DATA', 'BRAND', 'Mini', '迷你', 27),
('DATA', 'BRAND', 'Mitsubishi', '三菱', 28),
('DATA', 'BRAND', 'Nissan', '日產', 29),
('DATA', 'BRAND', 'Peugeot', '寶獅', 30),
('DATA', 'BRAND', 'Porsche', '保時捷', 31),
('DATA', 'BRAND', 'Renault', '雷諾', 32),
('DATA', 'BRAND', 'Rolls-Royce', '勞斯萊斯', 33),
('DATA', 'BRAND', 'Smart', 'Smart', 34),
('DATA', 'BRAND', 'SsangYong', '雙龍', 35),
('DATA', 'BRAND', 'Subaru', 'SUBARU', 36),
('DATA', 'BRAND', 'Suzuki', '鈴木', 37),
('DATA', 'BRAND', 'Tesla', '特斯拉', 38),
('DATA', 'BRAND', 'Toyota', '豐田', 39),
('DATA', 'BRAND', 'Volkswagen', '福士', 40),
('DATA', 'BRAND', 'Volvo', '富豪', 41)


;INSERT INTO ServiceLocation(srv_dis, srv_loc, name_zh, name_en, mgt_dis, cd_fleet) VALUES
('X', 0, N'不明', 'Unknown', 'X', 'NA'),
('V', 1, N'測試用屋苑(1)', 'Testing Location 1', 'V', 'NA'),
('V', 2, N'測試用屋苑(2)', 'Testing Location 2', 'V', 'NA')

-- SELECT * FROM UnitServiceGroup
-- DELETE FROM UnitServiceGroup
-- ;DBCC CHECKIDENT(UnitServiceGroup, RESEED, 0)
;INSERT INTO UnitServiceGroup(grp_name, parent_id) VALUES
('產品', NULL), ('服務', NULL), ('額外報價', NULL),
('一般服務', 2), ('三重水晶蠟', 2), ('鑽石鍍膜', 2),
('消毒', 2), ('去污', 2), ('翻新', 2)

-- SELECT * FROM UnitService
-- DELETE FROM UnitService
-- ;DBCC CHECKIDENT(UnitService, RESEED, 0)
;INSERT INTO UnitService(srv_grp, srv_name, srv_desc, price) VALUES
(3, N'額外報價', '', 0),
(3, N'折扣', '', 0),
(4, N'打蠟', '', 50),
(5, N'三重水晶蠟保養 (私家車)', N'保養水晶蠟 (有效期 3個月)', 488),
(5, N'三重水晶蠟保養 (七人車 / SUV)', N'保養水晶蠟 (有效期 3個月)', 588),
(5, N'三重水晶蠟保養 (客貨Van)', N'保養水晶蠟 (有效期 3個月)', 688),
(5, N'三重水晶蠟 (私家車)', N'三重水晶蠟 (有效期 6個月)', 888),
(5, N'三重水晶蠟 (七人車 / SUV)', N'三重水晶蠟 (有效期 6個月)', 988),
(5, N'三重水晶蠟 (客貨Van)', N'三重水晶蠟 (有效期 6個月)', 1088),
(6, N'鑽石鍍膜9H (私家車)', N'鑽石鍍膜9H (有效期 12個月)', 2388),
(6, N'鑽石鍍膜9H (七人車 / SUV)', N'鑽石鍍膜9H (有效期 12個月)', 2588),
(6, N'鑽石鍍膜9H (客貨Van)', N'鑽石鍍膜9H (有效期 12個月)', 2788),
(7, N'蒸氣車廂消毒 (私家車)', N'蒸氣車廂消毒', 480),
(7, N'蒸氣車廂消毒 (七人車 / SUV)', N'蒸氣車廂消毒', 680),
(7, N'蒸氣車廂消毒 (客貨Van)', N'蒸氣車廂消毒', 780),
(8, N'英泥漬', N'大面積需另外報價', 600),
(8, N'柏油漬', N'大面積需另外報價', 300),
(8, N'鹹水漬', N'大面積需另外報價', 500),
(8, N'雨水印 (車漆)', N'大面積需另外報價', 700),
(8, N'雨水印 (玻璃)', N'大面積需另外報價', 800),
(8, N'飛漆油點 (車漆)', N'大面積需另外報價', 400),
(8, N'飛漆油點 (玻璃)', N'大面積需另外報價', 300),
(9, N'膠邊/膠件發白', N'大面積需另外報價', 400),
(9, N'車窗電鍍連翻新', N'七人車另加 $300', 1800),
(9, N'車盤外殼翻新 (一對)', N'尾燈另加 $400', 800),
(9, N'門邊/夾鐵/字去舊漬', N'大面積需另外報價', 680)

-- stage 2 create System user and Staff Users
;PRINT 'creating system users'
--;DELETE FROM BillArchive
--;DELETE FROM Bill
--;DELETE FROM Invoice
--;DELETE FROM VehicleService
--;DELETE FROM Vehicle
--;DELETE FROM Contact
--;DELETE FROM Customer
--;DELETE FROM Worker
--;DELETE FROM ServicePlan
--;DELETE FROM WorkerLocation
--;DELETE FROM ServiceLocation
--;DELETE FROM TKUser

--;DBCC CHECKIDENT('TKUser', RESEED, 0)
--GO
;INSERT INTO TKUser(login_name, display_name, role, active, create_dtm, mod_dtm, mod_by, remarks)
SELECT NULL,     N'公司',     'SYSTEM',    1, GETDATE(), GETDATE(), 'SYSTEM', NULL UNION ALL
SELECT 'admin',  N'管理員',   'ADMIN',     1, GETDATE(), GETDATE(), 'SYSTEM', NULL UNION ALL
SELECT 'dev',    N'開發者',   'ADMIN',     1, GETDATE(), GETDATE(), 'SYSTEM', NULL UNION ALL
SELECT 'test1',  N'測試員 1', 'ADMIN',     1, GETDATE(), GETDATE(), 'SYSTEM', NULL UNION ALL
SELECT 'test2',  N'測試員 2', 'ADMIN',     1, GETDATE(), GETDATE(), 'SYSTEM', NULL UNION ALL
SELECT 'test3',  N'測試員 3', 'ADMIN',     1, GETDATE(), GETDATE(), 'SYSTEM', NULL UNION ALL
SELECT 'test4',  N'唯讀',     'VIEWER',    1, GETDATE(), GETDATE(), 'SYSTEM', NULL

;UPDATE TKUser
SET login_pswd = 0x839C3988E65EA3C85694B66B386EDCBBF287E0373B21DFEAB987A19343266116B9758D271612857A38FF423C5CA48A06096EA14DEB75031E82ED4C24851AE0A75F367DECF271B5FD0935897A51A4AE46551022C3AD159CBD79990E326360C6A5
WHERE login_name IN ('admin', 'dev')

;PRINT 'copying office staff'
;INSERT INTO TKUser(login_name, display_name, role, active, create_dtm, mod_dtm, mod_by, remarks)
SELECT
   login_name = LOWER(USR_Userid)
  ,display_name = (CASE WHEN USR_UserName = '' THEN USR_Userid ELSE USR_UserName END)
  ,role = (CASE USR_Authorization WHEN 1 THEN 'VIEWER' WHEN 2 THEN 'OPERATOR' WHEN 3 THEN 'ADMIN' ELSE 'OTHER' END)
  ,active = 1
  ,create_dtm  = '2021-01-01'
  ,mod_dtm = '2021-01-01'
  ,mod_by = 'SYSMIG'
  ,remarks = NULL
FROM TKCar_old.dbo.SY_UserID
WHERE USR_StatusCode = '00'

-- stag 3 create worker users
;PRINT 'copying workers'
;INSERT INTO TKUser(login_name, display_name, role, active, create_dtm, mod_dtm, mod_by, remarks)
SELECT
   login_name   = Lower(LTrim(RTrim(cd)))
  ,display_name = IsNull( WKR_WorkerName, 'no-record')
  ,role         = 'WORKER'
  ,active       = (CASE WHEN WKR_StatusCode = '00' THEN 1 ELSE 0 END)
  ,create_dtm   = '1970-01-01'
  ,mod_dtm      = IsNULL(WKR_UpdateDate, '1970-01-01')
  ,mod_by       = IsNull(WKR_UserID, 'SYSMIG')
  ,remarks      = WKR_WorkerDept
FROM (
  SELECT cd = IsNull(w.WKR_WorkerCode, scr.SCR_WorkerCode), w.* FROM TKCar_Old.dbo.MR_Worker AS w
  FULL JOIN (SELECT DISTINCT SCR_WorkerCode FROM TKCar_Old.dbo.TX_ServiceChangeRecord) AS scr
  ON (scr.SCR_WorkerCode = w.WKR_WorkerCode)
  WHERE IsNull(w.WKR_WorkerCode, scr.SCR_WorkerCode) IS NOT NULL
    AND IsNull(w.WKR_WorkerCode, scr.SCR_WorkerCode) <> ''
) AS w
ORDER BY cd

GO

;INSERT INTO Worker(uid, worker_code, bonus_A, bonus_B, bonus_C, bonus_extra)
SELECT id, Upper(login_name), 400,300,200,100 FROM TKUser WHERE role = 'WORKER'

;UPDATE Worker
SET work_type = 'A'
WHERE uid IN (
  SELECT u.id
  FROM TKUser AS u
  JOIN TKCar_old.dbo.MR_Worker AS w
  ON (w.WKR_WorkerCode = u.login_name)
  WHERE w.WKR_Type = 'A'
)

;INSERT INTO Employee (uid, employ_dtm, create_dtm, mod_dtm, mod_by, hkid)
SELECT id, create_dtm, create_dtm, mod_dtm, mod_by, 'A1234567' FROM TKUser
WHERE [role] NOT IN ('ADMIN', 'SYSTEM', 'CUSTOMER')

GO

-- stage 4 obtain worker contacts
;PRINT 'extracting worker contact'
;WITH d AS (
  SELECT
     worker_code = WKR_WorkerCode
    ,c_name      = LTrim(RTrim(WKR_WorkerName))
    ,c_num       = WKR_Phone
  FROM TKCar_Old.dbo.MR_Worker
  WHERE WKR_Phone <> ''
), p AS (
  SELECT worker_code, c_name
  ,c_num = SubString(c_num, PatIndex('%[0-9]%', c_num), 8)
  ,RP    = Replace(c_num, SubString(c_num, PatIndex('%[0-9]%', c_num), 8), '')
  FROM d
  UNION ALL
  SELECT worker_code, c_name
  ,c_num = SubString(RP, PatIndex('%[0-9]%', RP), 8)
  ,RP    = Replace(RP, SubString(RP, PatIndex('%[0-9]%', RP), 8), '')
  FROM p
  WHERE PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', RP) > 0
)
INSERT INTO Contact(uid, c_type, c_sal, c_name, c_num)
SELECT
  uid = id, c_type = 10, c_sal = '', c_name, c_num
FROM p
JOIN TKUser AS u
ON (u.login_name = p.worker_code)
ORDER BY id, c_num

-- stage 5 create temporary customer contact list
;PRINT 'extracting customer contacts'
;DROP TABLE IF Exists #temp_contact

;CREATE TABLE #temp_contact(
   uid        int
  ,login_name varchar(50)   COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
  ,cd_license varchar(30)   COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
  ,c_name     nvarchar(max) COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
  ,c_num      varchar(30)   COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
)

;WITH a AS (
  SELECT DISTINCT
    cd_license = SCR_CarNumber
    ,c_name = Trim(IsNull(SCR_CustomerName, ''))
    ,c_num  = IsNull(SCR_CustomerPhone, '')
  FROM TKCar_Old.dbo.TX_ServiceChangeRecord
  WHERE SCR_CarNumber <> ''
), d AS (
  SELECT cd_license, c_name, c_num = Concat(Convert(varchar(max), c_num), '#') FROM a
  UNION ALL
  SELECT DISTINCT CAR_CarNumber, IsNull(CAR_CustomerName, ''), Concat(IsNull(Convert(varchar, CAR_CustomerPhone), ''), '#')
  FROM TKCar_Old.dbo.MR_Car
  WHERE CAR_CarNumber NOT IN (SELECT DISTINCT cd_license FROM a)
), p AS (
  SELECT cd_license=LTrim(RTrim(cd_license)), c_name
    ,c_num = Convert(varchar, SubString(c_num
              ,PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', c_num)
              ,PatIndex('%[^0-9 ]%', Right(c_num, Len(c_num) - PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', c_num))) ))
    ,RP    = Replace(c_num, SubString(c_num
               ,PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', c_num)
               ,PatIndex('%[^0-9 ]%', Right(c_num, Len(c_num) - PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', c_num)))
             ), '')
  FROM d
  UNION ALL
  SELECT cd_license=LTrim(RTrim(cd_license)), c_name
    ,c_num = Convert(varchar, SubString(RP
              ,PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', RP)
              ,PatIndex('%[^0-9 ]%', Right(RP, Len(RP) - PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', RP))) ))
    ,RP    = Replace(RP, SubString(RP
               ,PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', RP)
               ,PatIndex('%[^0-9 ]%', Right(RP, Len(RP) - PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', RP)))
             ), '')
  FROM p
  WHERE PatIndex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%', RP) > 0
)
INSERT INTO #temp_contact(cd_license, c_name, c_num)
SELECT DISTINCT
  cd_license, c_name, c_num = Replace(c_num, ' ', '')
FROM p
--OPTION (MAXRECURSION 100)
GO

-- remove empty contact number of who has other phone numbers
;PRINT 'remove empty '
DELETE FROM #temp_contact
WHERE cd_license IN (SELECT DISTINCT cd_license FROM #temp_contact WHERE c_num <> '')
  AND c_num = ''
GO

-- find distinct customer
;PRINT 'gathering individual customer'
-- Create direct link from phone numbers
;DROP TABLE IF EXISTS #DLinks
;DROP TABLE IF EXISTS #ILinks
;CREATE TABLE #DLinks ( major varchar(30), minor varchar(30) )
;CREATE TABLE #ILinks ( major varchar(30), minor varchar(30) )
;CREATE CLUSTERED INDEX IX_TMP_1 ON #DLinks (minor)
;CREATE CLUSTERED INDEX IX_TMP_2 ON #ILinks (major)

;INSERT INTO #DLinks
  SELECT DISTINCT
    major = t1.cd_license, minor = t2.cd_license
  FROM #temp_contact AS t1
  JOIN #temp_contact AS t2
  ON (t1.c_num = t2.c_num)
  WHERE t1.cd_license < t2.cd_license
    AND t1.c_num <> ''
    AND t1.c_name NOT LIKE N'%管理處%'  -- do not merge customers if the vehicle is managed by a property company
    AND t2.c_name NOT LIKE N'%管理處%'

-- Create indirect link from direct link
;PRINT '-- creating indirect links --'
;SET NOCOUNT ON
;INSERT INTO #ILinks (major, minor)
SELECT major, minor FROM #DLinks

;DECLARE @link_rc    int = 0;
;DECLARE @link_lpCnt int = 0;
;WHILE 1=1
BEGIN

  ;INSERT INTO #ILinks (major, minor)
  SELECT DISTINCT d.major, e.minor
  FROM #DLinks AS d
  JOIN #ILinks AS e
  ON (d.minor = e.major)
  WHERE d.major < e.minor
  EXCEPT
  SELECT major, minor FROM #ILinks

  ;SET @link_rc = @@ROWCOUNT
  IF @link_rc = 0
  BEGIN
    PRINT Concat('Customer linkage exit at level = ', @link_lpCnt)
    BREAK
  END

  ;SET @link_lpCnt = @link_lpCnt + 1
  IF @link_lpCnt > 100 BREAK
END
;SET NOCOUNT OFF
;PRINT '-- creation success --'

;PRINT 'linking multiple vehicles by contacts number'
;WITH Ranks AS (
  -- Count children and form as rank, since major always < minor, count of major must be largest
  -- rank is unique for all items, overriding the rank by parent's will group the networks
  SELECT major, [rank] = ROW_NUMBER() OVER (ORDER BY COUNT(1), major)
  FROM #ILinks
  GROUP BY major
)
UPDATE #temp_contact
SET uid = [rank]
FROM (
  SELECT item, [rank] = Max([rank])
  FROM (
    -- Get parent rank
    SELECT DISTINCT item = major, [rank]
    FROM Ranks
    UNION ALL
    -- Get child rank (use parent's rank)
    SELECT item = rel.minor, Ranks.[rank]
    FROM #ILinks AS rel
    LEFT JOIN Ranks
    ON (Ranks.major = rel.major)
  ) AS _
  GROUP BY item
) AS _
WHERE cd_license = item COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8

;PRINT 'filling individual owners with multiple contacts'
;DECLARE @maxId int
;SELECT @maxId = Max(uid) FROM #temp_contact
;UPDATE #temp_contact
SET uid = rid
FROM (
  SELECT cd_license, rid = @maxId + ROW_NUMBER() OVER (ORDER BY cd_license)
  FROM #temp_contact
  WHERE uid IS NULL
    AND c_num <> ''
  GROUP BY cd_license
) AS r
WHERE #temp_contact.cd_license = r.cd_license

;PRINT 'assigning customer login_name as unique ID'
;UPDATE #temp_contact
SET login_name = uq_name
FROM ( SELECT uid, uq_name = Min(c_num) FROM #temp_contact WHERE uid IS NOT NULL AND c_num <> '' AND c_name NOT LIKE '%管理處%' GROUP BY uid ) AS r
WHERE #temp_contact.uid = r.uid


;PRINT 'assigning customers without contacts'
;UPDATE #temp_contact
SET login_name = 'CU' + RIGHT('000000' + CAST(rid AS varchar), 6)
FROM (
  SELECT cd_license, rid = ROW_NUMBER() OVER(ORDER BY cd_license)
  FROM #temp_contact
  WHERE login_name IS NULL
  GROUP BY cd_license
) AS t
WHERE #temp_contact.cd_license = t.cd_license
GO

-- stage 6 create customer accounts
-- `login_name` is now unique identifier for all customers, but user ID is not assigned
-- by inserting all "login_name" to the `User` table, AUTO_IDENT will create new `uid` for ALL users
-- then update the temp table from this result
-- ;TRUNCATE TABLE Bill
-- ;DELETE FROM Contact WHERE [uid] IN (SELECT id FROM Customer)
-- ;TRUNCATE TABLE Customer
-- ;TRUNCATE TABLE VehicleService
-- ;DELETE FROM Vehicle
-- ;DELETE FROM TKUser WHERE [role] = 'CUSTOMER'
-- ;DECLARE @maxId int
-- ;SELECT @maxId = Max(id) FROM TKUser
-- ;DBCC CHECKIDENT('TKUser', RESEED, @maxId)
-- ;DBCC CHECKIDENT('TKUser', NORESEED)
---------------------------------------------------------------------

;PRINT 'creating customer accounts'
;WITH d AS (
  SELECT
      m.*
     ,ct.login_name
     ,did = ROW_NUMBER() OVER (PARTITION BY ct.login_name ORDER BY IsNull(CAR_ChangeItemDate, CAR_StartDate) DESC)
  FROM (SELECT DISTINCT cd_license, login_name FROM #temp_contact) AS ct
  JOIN (
    SELECT
      CAR_CarNumber, CAR_StartDate, CAR_ChangeItemDate, CAR_UpdateDate, CAR_UserID
    FROM TKCar_Old.dbo.MR_Car
    UNION ALL
    SELECT
      SCR_CarNumber, SCR_StartDate, SCR_ChangeItemDate, SCR_UpdateDate, SCR_UserID
    FROM TKCar_Old.dbo.TX_ServiceChangeRecord
    WHERE SCR_CarNumber NOT IN (SELECT DISTINCT CAR_CarNumber FROM TKCar_Old.dbo.MR_Car)
  ) AS m
  ON (ct.cd_license = m.CAR_CarNumber)
)
INSERT INTO TKUser(login_name, display_name, role, active, create_dtm, mod_dtm, mod_by, remarks)
SELECT
   login_name   = lnk.login_name
  ,display_name = (CASE WHEN c_name IS NULL OR c_name = '' THEN cd_license ELSE c_name END)
  ,role         = 'CUSTOMER'
  ,active       = 1
  ,create_dtm
  ,mod_dtm
  ,mod_by       = CAR_UserID
  ,remarks      = NULL
FROM ( SELECT login_name, c_name = Min(c_name), cd_license = Min(cd_license) FROM #temp_contact GROUP BY login_name) AS lnk
JOIN (
  SELECT
    login_name, create_dtm = Min(CAR_StartDate), mod_dtm = Max(IsNull(CAR_ChangeItemDate, CAR_StartDate))
  FROM d
  GROUP BY login_name
) AS d1
ON (lnk.login_name = d1.login_name)
JOIN (
  SELECT login_name, CAR_UserID FROM d WHERE did = 1
) AS d2
ON (lnk.login_name = d2.login_name)
GO

-- back update contact list // must update before creating Customer info
UPDATE #temp_contact
SET uid = id
FROM (
  SELECT id, login_name FROM TKUser WHERE role = 'CUSTOMER'
) AS r
WHERE #temp_contact.login_name = r.login_name COLLATE Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8
GO

-- create customer info
;WITH d AS (
  SELECT
      CAR_UserID, CAR_Remark, CAR_MonthEndYN, CAR_ReminderYN, CAR_TransferYN
     ,ct.uid
     ,did = ROW_NUMBER() OVER (PARTITION BY ct.uid ORDER BY IsNull(CAR_ChangeItemDate, CAR_StartDate) DESC)
  FROM TKCar_Old.dbo.MR_Car AS m
  JOIN (SELECT DISTINCT cd_license, uid FROM #temp_contact) AS ct
  ON (ct.cd_license = m.CAR_CarNumber)
)
INSERT INTO Customer (id, last_reunion, last_payment, balance, is_mobill, is_print_bill, is_rtn_envelope, mod_dtm, mod_by)
SELECT
   id
  ,create_dtm
  ,last_payment=(NULL), balance=(0)
  ,IsNull(CAR_MonthEndYN, 0), IsNull(CAR_ReminderYN, 0), IsNull(CAR_TransferYN, 0)
  ,mod_dtm, mod_by
FROM TKUser AS u
LEFT JOIN (
  SELECT uid, CAR_UserID, CAR_Remark, CAR_MonthEndYN, CAR_ReminderYN, CAR_TransferYN
  FROM d WHERE did = 1
) AS d2
ON (u.id= d2.uid)
WHERE role = 'CUSTOMER'
GO

-- stage 7 obtain customer contacts
;PRINT 'assigning contacts to customer accounts'
;INSERT INTO Contact(uid, c_type, c_sal, c_name, c_num)
SELECT
  uid ,c_type = 10 ,c_sal  = ''
  ,c_name = IsNull(Max(LTrim(RTrim(c_name))), N'車主')
  ,c_num
FROM #temp_contact AS ct
WHERE c_num <> ''
GROUP BY uid, c_num

-- stage 8 service locations
;PRINT 'migrating service locations'
;INSERT INTO ServiceLocation(srv_dis, srv_loc, name_zh, name_en, mgt_dis, cd_fleet)
SELECT srv_dis, srv_loc, Max(name_zh), Max(name_en), mgt_dis=srv_dis, IsNull(Max(cd_fleet), '')
FROM (
  SELECT
     srv_dis  = (CASE WHEN HNP_HouseCode = '999' THEN 'X' ELSE HNP_LocationCode END)
    ,srv_loc  = Convert(int, CASE WHEN LEFT(HNP_HouseCode,1) = '1' THEN HNP_HouseCode
                                 WHEN LEFT(HNP_HouseCode,1) = '9' THEN 1
                                 ELSE RIGHT(HNP_HouseCode, 2) END)
    ,name_zh  = IsNull(HNP_HouseNameCHN, '')
    ,name_en  = IsNull(HNP_HouseNameENG, '')
    ,cd_fleet = LTrim(RTrim(HNP_CarTeam))
  FROM TKCar_Old.dbo.MR_HousePark
) AS t
GROUP BY srv_dis, srv_loc
ORDER BY srv_dis, srv_loc

-- Complete missing values for old data FK
;PRINT 'filling missing values of service locations'
;WITH m AS (
  SELECT srv_dis = srv_dis, srv_loc = Max(srv_loc) FROM ServiceLocation GROUP BY srv_dis
), r AS (
  SELECT srv_dis, 1 AS srv_loc FROM m
  UNION ALL
  SELECT srv_dis, srv_loc + 1 FROM r
  WHERE srv_loc < (SELECT srv_loc FROM m AS a WHERE a.srv_dis = r.srv_dis)
), d AS (
  SELECT srv_dis, srv_loc FROM r
  EXCEPT
  SELECT srv_dis, srv_loc FROM ServiceLocation
)
INSERT INTO ServiceLocation(srv_dis, srv_loc, name_zh, name_en, mgt_dis, cd_fleet)
SELECT srv_dis, srv_loc, '', '', mgt_dis=srv_dis, '' FROM d
ORDER BY 1,2
OPTION (MAXRECURSION 1000)

-- stage 9 worker locations
-- manual list is provided
GO

--=====================================================
-- Service Change Record type
--=====================================================
-- 00 Others
-- 01 New client
-- 02 Terminate Service
-- 03 Renew Service
-- 04 Suspend Service
-- 05 Add/Reduce Service
-- 06 Change plan
-- 07 Change service days
-- 08 Change vehicle info
-- 09 Change worker
-- 10 Triple-Waxing

-- stage 10 vehicle
;PRINT 'extracting vehicles and assign to customers'
;WITH a AS (
  SELECT
    CAR_CarNumber, CAR_StartDate, CAR_ChangeItemDate, CAR_CarType, CAR_CustomerSource, CAR_CarColor, CAR_UserID, CAR_Remark
  FROM TKCar_Old.dbo.MR_Car AS m
  UNION ALL
  SELECT DISTINCT
      SCR_CarNumber
    , SCR_ChangeFmDate
    , SCR_StartDate      = FIRST_VALUE(SCR_StartDate     ) OVER (PARTITION BY SCR_CarNumber ORDER BY CASE WHEN SCR_StartDate      IS NULL THEN 2 ELSE 1 END, SCR_ChangeFmDate DESC)
    , SCR_CarType        = FIRST_VALUE(SCR_CarType       ) OVER (PARTITION BY SCR_CarNumber ORDER BY CASE WHEN SCR_CarType        IS NULL THEN 2 ELSE 1 END, SCR_ChangeFmDate DESC)
    , SCR_CustomerSource = FIRST_VALUE(SCR_CustomerSource) OVER (PARTITION BY SCR_CarNumber ORDER BY CASE WHEN SCR_CustomerSource IS NULL THEN 2 ELSE 1 END, SCR_ChangeFmDate DESC)
    , SCR_CarColor       = FIRST_VALUE(SCR_CarColor      ) OVER (PARTITION BY SCR_CarNumber ORDER BY CASE WHEN SCR_CarColor       IS NULL THEN 2 ELSE 1 END, SCR_ChangeFmDate DESC)
    , SCR_UserID         = FIRST_VALUE(SCR_UserID        ) OVER (PARTITION BY SCR_CarNumber ORDER BY CASE WHEN SCR_UserID         IS NULL THEN 2 ELSE 1 END, SCR_ChangeFmDate DESC)
    , SCR_Remark         = FIRST_VALUE(SCR_Remark        ) OVER (PARTITION BY SCR_CarNumber ORDER BY CASE WHEN SCR_Remark         IS NULL THEN 2 ELSE 1 END, SCR_ChangeFmDate DESC)
  FROM TKCar_Old.dbo.TX_ServiceChangeRecord
  WHERE SCR_CarNumber NOT IN (SELECT DISTINCT CAR_CarNumber FROM TKCar_Old.dbo.MR_Car)
), d AS (
  SELECT
     a.*, did = ROW_NUMBER() OVER (PARTITION BY CAR_CarNumber ORDER BY IsNull(CAR_ChangeItemDate, CAR_StartDate) DESC)
  FROM a
)
INSERT INTO Vehicle(cd_license, owner_id, vh_type, source, color, brand, model, create_dtm, mod_dtm, mod_by, remarks)
SELECT
   cd_license
  ,owner_id   = c.uid
  ,vh_type    = CAR_CarType
  ,source
  ,color      = NULL
  ,brand      = CASE WHEN LTRIM(RTRIM(CAR_CarColor)) = '' THEN NULL ELSE LTRIM(RTRIM(CAR_CarColor)) END
  ,model      = NULL
  ,create_dtm
  ,mod_dtm
  ,mod_by     = d2.CAR_UserID
  ,remarks    = d2.CAR_Remark
FROM (
  SELECT DISTINCT uid, cd_license FROM #temp_contact
) AS c
LEFT JOIN (
  SELECT
    CAR_CarNumber, create_dtm = IsNull(Min(CAR_StartDate), '1970-01-01'), mod_dtm = Max(IsNull(CAR_ChangeItemDate, CAR_StartDate))
  FROM d
  GROUP BY CAR_CarNumber
) AS d1
ON (c.cd_license = d1.CAR_CarNumber)
JOIN (
  SELECT
     CAR_CarNumber, CAR_CarType, CAR_CarColor, CAR_UserID, CAR_Remark
    ,source = (CASE Trim(CAR_CustomerSource)
        WHEN '新' THEN 1
        WHEN '工' THEN 2
        WHEN '優' THEN 3
        ELSE 0
      END)
  FROM d
  WHERE did = 1
) AS d2
ON (c.cd_license = d2.CAR_CarNumber)
ORDER BY cd_license

GO


-- stage 11 service plan
;PRINT 'extracting service plans price and salary'
;INSERT INTO ServicePlan(srv_dis, srv_loc, company, cd_plan, vh_type, price, salary, effect, create_dtm, create_by)
SELECT
  srv_dis    = (CASE WHEN LEFT(SRV_HouseCode, 1) = '1' THEN 'K'
                     WHEN LEFT(SRV_HouseCode, 1) = '9' THEN 'X'
                     ELSE LEFT(SRV_HouseCode, 1) END)
 ,srv_loc    = Convert(int, CASE WHEN LEFT(SRV_HouseCode, 1) = '1' THEN SRV_HouseCode
                                 WHEN LEFT(SRV_HouseCode, 1) = '9' THEN 1
                                 ELSE RIGHT(SRV_HouseCode,2) END)
 ,company    = SRV_CompanyCode
 ,cd_plan    = SRV_PlanCode
 ,vh_type    = SRV_CarType
 ,price      = Convert(decimal(15, 2), SRV_ServicePrice)
 ,salary     = (CASE WHEN WKR_ServicePrice = 0
                     THEN (CASE SRV_PlanCode WHEN 'A' THEN 180 WHEN 'B' THEN 140 WHEN 'C' THEN 90 END)
                     ELSE WKR_ServicePrice
                END)
 ,effect     = SRV_Updatedate
 ,create_dtm = SRV_Updatedate
 ,create_by  = SRV_UserID
FROM TKCar_Old.dbo.MR_ServicePlan
WHERE SRV_StatusCode = '00'
  AND SRV_HouseCode <> ''
  AND SRV_CarType IN ('1', '2', '3')
  AND SRV_PlanCode IN ('A', 'B', 'C')

-- stage 12 copy bills
;PRINT 'extracting old bills'
;WITH pr AS (
  SELECT PAY_CompanyCode, PAY_CarNumber
    , PAY_Year = Cast(PAY_Year AS int), PAY_Month = Cast(PAY_Month AS int)
    , PAY_Date, PAY_Discount, PAY_Amount, PAY_RecAmount
    , pid = ROW_NUMBER() OVER (PARTITION BY PAY_CompanyCode, owner_id, (Year(PAY_Date)*100 + Month(PAY_Date)) ORDER BY PAY_CarNumber, PAY_Date)
    , uid = owner_id
  FROM (
    SELECT PAY_CarNumber, PAY_CompanyCode, PAY_Year, PAY_Month
      , PAY_Amount = MAX(PAY_Amount)
      , PAY_RecAmount = SUM(PAY_RecAmount), PAY_Discount = SUM(PAY_Discount), PAY_Date = MAX(PAY_Date)
    FROM TKCar_Old.dbo.TX_PaymentReceipt AS d
    WHERE PAY_Type IS NOT NULL AND PAY_Year IS NOT NULL AND PAY_Month IS NOT NULL
      AND PAY_RecAmount IS NOT NULL
      AND NOT (PAY_RecAmount = 0 AND PAY_Discount = 0)
    GROUP BY PAY_CarNumber, PAY_CompanyCode, PAY_Year, PAY_Month
  ) AS t
  JOIN Vehicle AS v
  ON (t.PAY_CarNumber = v.cd_license)
)
INSERT INTO BillArchive(company, ix_yrmo, uid, cd_license, bill_type, create_dtm, amount, discount, bill_start, bill_end, due_dtm, iv_ix, iv_seq)
SELECT
   company    = LTrim(RTrim(PAY_CompanyCode))
  ,ix_yrmo    = Cast(PAY_Year AS int)*100 + Cast(PAY_Month AS int)
  ,uid        = uid
  ,cd_license = PAY_CarNumber 
  ,bill_type  = 1 /* 1 = monthly services */
  ,create_dtm = PAY_Date
--,mofee      = Cast(PAY_Amount AS decimal(15, 2))
  ,paid       = Cast(PAY_RecAmount AS decimal(15, 2)) + Cast(PAY_Discount AS decimal(15, 2))
  ,discount   = Cast(PAY_Discount AS decimal(15, 2))
  ,bill_start = Cast( DateFromParts( PAY_Year, PAY_Month, 1 ) AS date )
  ,bill_end   = EOMonth(DateFromParts( PAY_Year, PAY_Month, 1 ))
  ,due_dtm    = EOMonth(DateFromParts( PAY_Year, PAY_Month, 1 ))
  ,iv_ix      = Year(PAY_Date)*100 + Month(PAY_Date)
  ,iv_seq     = pid
FROM pr
GO

-- stage 13 copy invoice
;PRINT 'extracting invoice'
;WITH d AS (
  SELECT
     PAY_CarNumber
    ,PAY_CompanyCode
    ,PAY_Date       = MAX(PAY_Date)
    ,PAY_UpdateDate = MAX(PAY_UpdateDate)
    ,PAY_Type       = MAX(PAY_Type)
    ,PAY_TypeDetail
    ,PAY_UserID     = MAX(IsNull(PAY_UserID, ''))
    ,PAY_RecAmount  = SUM(PAY_RecAmount)
    ,remarks        = MAX(PAY_Remark)
  FROM TKCar_Old.dbo.TX_PaymentReceipt
  WHERE PAY_RecAmount > 0 AND PAY_NO IS NOT NULL
  GROUP BY PAY_CarNumber, PAY_TypeDetail, PAY_CompanyCode, PAY_NO
), e AS (
  SELECT
     company       = PAY_CompanyCode
    ,cd_license    = PAY_CarNumber
    ,ix_yrmo       = Year(PAY_Date)*100 + Month(PAY_Date)
    ,uid           = owner_id
    ,cust_name     = display_name
    ,payment_type  = PAY_Type
    ,amount        = PAY_RecAmount
    ,transfer_dtm  = PAY_Date
    ,create_dtm    = PAY_UpdateDate
    ,create_by     = PAY_UserID
    ,ref_code      = PAY_TypeDetail
    ,remarks       = d.remarks
  FROM d
  JOIN Vehicle AS v
  ON (d.PAY_Carnumber = v.cd_license)
  JOIN TKUser AS u
  ON (v.owner_id = u.id)
)
INSERT INTO Payment(company, ix_yrmo, uid, useq, cd_license, cust_name, amount, payment_type, ref_code, transfer_dtm, create_dtm, create_by, mod_dtm, mod_by, remarks)
SELECT
   company, ix_yrmo, uid
  ,useq = ROW_NUMBER() OVER (PARTITION BY ix_yrmo, uid ORDER BY create_dtm, cd_license)
  ,cd_license
  ,cust_name
  ,amount = SUM(amount)
  ,payment_type  = (CASE payment_type -- A:Adjustment, C:Cash, T:Transfer, Q:cheQue, F:Fps, B:Bad debt
      WHEN 'A' /* Adjustment    */ THEN 'A'
      WHEN 'B' /* Bank Transfer */ THEN 'T'
      WHEN 'C' /* Cheque        */ THEN 'Q'
      WHEN 'D' /* Cash          */ THEN 'C'
      ELSE '0'
    END)
  ,ref_code
  ,transfer_dtm
  ,create_dtm
  ,create_by
  ,mod_dtm       = create_dtm
  ,mod_by        = 'SYSMIG'
  ,remarks
FROM e
GROUP BY company, cd_license, ix_yrmo, uid, cust_name, payment_type, ref_code, transfer_dtm, create_dtm, create_by, remarks
--ORDER BY uid, ix_yrmo, useq
GO

-- Remove temp resource
;DROP TABLE IF EXISTS #temp_contact
;DROP TABLE IF EXISTS #DLinks
;DROP TABLE IF EXISTS #LLinks
GO

-- stage 14, copy 3M services
;PRINT 'copying 3M services'
;INSERT INTO TKOrder(company, cust_id, cd_license, o_status, payment_type, payment_ref, payment_amount, order_dtm, create_dtm, mod_dtm, mod_by)
SELECT company    = Trim(SCR_CompanyCode)
     , cust_id    = v.owner_id
     , cd_license = v.cd_license
     , o_status   = 12
     , pay_type   = 'C'
     , pay_ref    = NULL
     , pay_amt    = SCR_ServicePrice
     , order_dtm  = SCR_ChangeFmDate
     , create_dtm = SCR_UpdateDate
     , mod_dtm    = SCR_UpdateDate
     , mod_by     = SCR_UserID
FROM TKCar_Old.dbo.TX_ServiceChangeRecord AS scr
JOIN Vehicle AS v ON (scr.SCR_CarNumber = v.cd_license)
WHERE SCR_PlanCode = 'X'
GO

;INSERT INTO TKOrderItem(oid, item_id, qty, unit_price, discount)
SELECT o.id, 7, 1, o.payment_amount, 0 FROM TKOrder AS o
GO

-- Data Massage
;print '----------------------------------------------'
;print 'start cleaning up data'
;print '----------------------------------------------'
--------------------------------------------------------------------------------
;print 'updating worker locations'
;DROP TABLE IF EXISTS #t
;DROP TABLE IF EXISTS #b
;CREATE TABLE #t( id int, cd varchar(max) collate Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8, nm varchar(max) collate Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8 );
;CREATE TABLE #b( id int, cd varchar(max) collate Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8, dis varchar(10) collate Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8, loc int, flr varchar(max) collate Chinese_Hong_Kong_Stroke_90_CI_AS_SC_UTF8 );

;INSERT INTO #t(cd, nm) VALUES
('W0050', 'SOME WORKER NAMES'); -- list of workers

;INSERT INTO #b( cd, dis, loc, flr ) VALUES
('W0050', 'K', 84, NULL);

;UPDATE t SET id = w.uid FROM #t AS t JOIN Worker AS w ON (t.cd = w.worker_code);
;UPDATE b SET id = w.uid FROM #b AS b JOIN Worker AS w ON (b.cd = w.worker_code);
;UPDATE u SET display_name = nm FROM #t AS t JOIN TKUser AS u ON (t.id = u.id);

;INSERT INTO WorkerLocation( uid, srv_dis, srv_loc, srv_floor, work_type, create_dtm, mod_dtm, mod_by )
SELECT id, dis, loc, flr, 0, '2022-01-01', GETDATE(), 'SYSMIG' FROM #b;

;DROP TABLE IF EXISTS #t
;DROP TABLE IF EXISTS #b

--------------------------------------------------------------------------------
-- Apply Leisure Home Service commission rate
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'H' AND srv_loc = 1
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'H' AND srv_loc = 15
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 5
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 12
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 13
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 21
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 22
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 25
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 26
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 29
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 36
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 39
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 41
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 53
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'K' AND srv_loc = 97
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'N' AND srv_loc = 17
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'N' AND srv_loc = 18
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'N' AND srv_loc = 20
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'N' AND srv_loc = 26
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'T' AND srv_loc = 1
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'T' AND srv_loc = 7
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'T' AND srv_loc = 10
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'W' AND srv_loc = 6
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'Y' AND srv_loc = 5
;UPDATE ServiceLocation SET lhs_cmr = 1 WHERE srv_dis = 'Y' AND srv_loc = 6
GO

;USE [master]
GO
