-- 2022 Jan 13, ver 1.2

SET STATISTICS IO OFF
SET STATISTICS TIME OFF

SET NOCOUNT ON

USE TKCar_MGT

--------------------------------------------------------------------------------------------------------------------------
;PRINT 'Reset temp sp'
;DROP PROCEDURE IF EXISTS sp_tmp_VS_ins
GO
;CREATE PROCEDURE sp_tmp_VS_ins
  @p_owner_id    int          ,@p_license     varchar(max) ,@p_company     varchar(max) ,@p_cd          varchar(max)
 ,@p_srv_dis     varchar(max) ,@p_srv_loc     int          ,@p_floor       varchar(max) ,@p_psn         varchar(max)
 ,@p_start_dtm   date         ,@p_ch_fm_dtm   date         ,@p_ch_to_dtm   date
 ,@p_stop_reason varchar(max) ,@p_plan        varchar(max) ,@p_vh_type     int
 ,@p_srv_day1    varchar(max) ,@p_srv_day2    varchar(max) ,@p_srv_day3    varchar(max) ,@p_fee         decimal
 ,@p_worker_id   int          ,@p_alt_license varchar(max) ,@p_alt_specFee decimal      ,@p_remarks     nvarchar(max)
 ,@p_mod_dtm     datetime2    ,@p_mod_by      varchar(max)
AS
BEGIN
  ;DECLARE @owner_id    int           = @p_owner_id
  ;DECLARE @license     varchar(max)  = @p_license
  ;DECLARE @company     varchar(max)  = @p_company
  ;DECLARE @cd          varchar(max)  = @p_cd
  ;DECLARE @srv_dis     varchar(max)  = @p_srv_dis
  ;DECLARE @srv_loc     int           = @p_srv_loc
  ;DECLARE @floor       varchar(max)  = @p_floor
  ;DECLARE @psn         varchar(max)  = @p_psn
  ;DECLARE @start_dtm   date          = @p_start_dtm
  ;DECLARE @ch_fm_dtm   date          = @p_ch_fm_dtm
  ;DECLARE @ch_to_dtm   date          = @p_ch_to_dtm
  ;DECLARE @stop_reason varchar(max)  = @p_stop_reason
  ;DECLARE @plan        varchar(max)  = @p_plan
  ;DECLARE @vh_type     int           = @p_vh_type
  ;DECLARE @srv_day1    varchar(max)  = @p_srv_day1
  ;DECLARE @srv_day2    varchar(max)  = @p_srv_day2
  ;DECLARE @srv_day3    varchar(max)  = @p_srv_day3
  ;DECLARE @fee         decimal       = @p_fee
  ;DECLARE @worker_id   int           = @p_worker_id
  ;DECLARE @alt_license varchar(max)  = @p_alt_license
  ;DECLARE @alt_specFee decimal       = @p_alt_specFee
  ;DECLARE @remarks     nvarchar(max) = @p_remarks
  ;DECLARE @mod_dtm     datetime2     = @p_mod_dtm
  ;DECLARE @mod_by      varchar(max)  = @p_mod_by

  ;WITH prev_scr AS (
    SELECT
       SCR_HouseCode,SCR_HouseFloor,SCR_CarLocation,SCR_CarColor
      ,SCR_StartDate,SCR_StopReason,SCR_ChangeItemDate
      ,SCR_PlanCode,SCR_CarType,SCR_Servicedate1,SCR_Servicedate2,SCR_Servicedate3
      ,SCR_ServicePrice,SCR_WorkerCode,SCR_AltCARNumber,SCR_AltSpecCharge,SCR_ChangeFmDate
    FROM TKCar_Old.dbo.TX_ServiceChangeRecord
    WHERE SCR_CarNumber   = @license
      AND SCR_CompanyCode = @company
      AND SCR_ChangeFmDate <= @ch_fm_dtm
  ), prev_car AS (
    SELECT
      CAR_HouseCode,CAR_HouseFloor,CAR_CarLocation,CAR_CarColor
      ,CAR_StartDate,CAR_StopReason,CAR_ChangeItemDate
      ,CAR_PlanCode,CAR_CarType,CAR_Servicedate1,CAR_Servicedate2,CAR_Servicedate3
      ,CAR_ServicePrice,CAR_WorkerCode,CAR_AltCARNumber,CAR_AltSpecCharge,CAR_UpdateDate
    FROM TKCar_Old.dbo.MR_Car
    WHERE CAR_CompanyCode = @company
      AND CAR_CarNumber   = @license
  ), o AS (
    SELECT TOP 1 * FROM (
      SELECT TOP 1
          _loc         = (SELECT TOP 1 SCR_HouseCode      FROM prev_scr WHERE SCR_HouseCode      IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _floor       = (SELECT TOP 1 SCR_HouseFloor     FROM prev_scr WHERE SCR_HouseFloor     IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _psn         = (SELECT TOP 1 SCR_CarLocation    FROM prev_scr WHERE SCR_CarLocation    IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _color       = (SELECT TOP 1 SCR_CarColor       FROM prev_scr WHERE SCR_CarColor       IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _start_dtm   = (SELECT TOP 1 SCR_StartDate      FROM prev_scr WHERE SCR_StartDate      IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _stop_reason = (SELECT TOP 1 SCR_StopReason     FROM prev_scr WHERE SCR_StopReason     IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _ch_itm_dtm  = (SELECT TOP 1 SCR_ChangeItemDate FROM prev_scr WHERE SCR_ChangeItemDate IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _plan        = (SELECT TOP 1 SCR_PlanCode       FROM prev_scr WHERE SCR_PlanCode       IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _vh_type     = (SELECT TOP 1 SCR_CarType        FROM prev_scr WHERE SCR_CarType        IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _weekday1    = (SELECT TOP 1 SCR_Servicedate1   FROM prev_scr
            WHERE SCR_Servicedate1 IS NOT NULL
              AND SCR_Servicedate1 <> ''
            ORDER BY SCR_ChangeFmDate)
        , _weekday2    = (SELECT TOP 1 SCR_Servicedate2   FROM prev_scr
            WHERE SCR_Servicedate2 IS NOT NULL
              AND SCR_Servicedate2 <> ''
            ORDER BY SCR_ChangeFmDate)
        , _weekday3    = (SELECT TOP 1 SCR_Servicedate3   FROM prev_scr
            WHERE SCR_Servicedate3 IS NOT NULL
              AND SCR_Servicedate3 <> ''
            ORDER BY SCR_ChangeFmDate)
        , _fee         = (SELECT TOP 1 SCR_ServicePrice   FROM prev_scr WHERE SCR_ServicePrice   IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _worker_code = (SELECT TOP 1 SCR_WorkerCode     FROM prev_scr WHERE SCR_WorkerCode     IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _rotation    = (SELECT TOP 1 SCR_AltCARNumber   FROM prev_scr WHERE SCR_AltCARNumber   IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
        , _extra_fee   = (SELECT TOP 1 SCR_AltSpecCharge  FROM prev_scr WHERE SCR_AltSpecCharge  IS NOT NULL ORDER BY SCR_ChangeFmDate DESC)
      FROM prev_scr
      UNION ALL
      SELECT TOP 1
          _loc         = (SELECT TOP 1 CAR_HouseCode      FROM prev_car WHERE CAR_HouseCode      IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _floor       = (SELECT TOP 1 CAR_HouseFloor     FROM prev_car WHERE CAR_HouseFloor     IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _psn         = (SELECT TOP 1 CAR_CarLocation    FROM prev_car WHERE CAR_CarLocation    IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _color       = (SELECT TOP 1 CAR_CarColor       FROM prev_car WHERE CAR_CarColor       IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _start_dtm   = (SELECT TOP 1 CAR_StartDate      FROM prev_car WHERE CAR_StartDate      IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _stop_reason = (SELECT TOP 1 CAR_StopReason     FROM prev_car WHERE CAR_StopReason     IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _ch_itm_dtm  = (SELECT TOP 1 CAR_ChangeItemDate FROM prev_car WHERE CAR_ChangeItemDate IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _plan        = (SELECT TOP 1 CAR_PlanCode       FROM prev_car WHERE CAR_PlanCode       IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _vh_type     = (SELECT TOP 1 CAR_CarType        FROM prev_car WHERE CAR_CarType        IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _weekday1    = (SELECT TOP 1 CAR_Servicedate1   FROM prev_car
              WHERE CAR_Servicedate1 IS NOT NULL
                AND CAR_Servicedate1 <> ''
              ORDER BY CAR_UpdateDate)
        , _weekday2    = (SELECT TOP 1 CAR_Servicedate2   FROM prev_car
              WHERE CAR_Servicedate2 IS NOT NULL
                AND CAR_Servicedate2 <> ''
              ORDER BY CAR_UpdateDate)
        , _weekday3    = (SELECT TOP 1 CAR_Servicedate3   FROM prev_car
              WHERE CAR_Servicedate3 IS NOT NULL
                AND CAR_Servicedate3 <> ''
              ORDER BY CAR_UpdateDate)
        , _fee         = (SELECT TOP 1 CAR_ServicePrice   FROM prev_car WHERE CAR_ServicePrice   IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _worker_code = (SELECT TOP 1 CAR_WorkerCode     FROM prev_car WHERE CAR_WorkerCode     IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _rotation    = (SELECT TOP 1 CAR_AltCARNumber   FROM prev_car WHERE CAR_AltCARNumber   IS NOT NULL ORDER BY CAR_UpdateDate DESC)
        , _extra_fee   = (SELECT TOP 1 CAR_AltSpecCharge  FROM prev_car WHERE CAR_AltSpecCharge  IS NOT NULL ORDER BY CAR_UpdateDate DESC)
      FROM prev_car
    ) AS _
  )
  INSERT INTO VehicleService(
    company, cd_license, owner_id, vh_type, srv_plan,
    reg_dtm, start_dtm, end_dtm, fee,
    srv_dis, srv_loc, srv_floor, srv_psn,
    weekday1, weekday2, weekday3, rotation, extra_fee, waxing,
    worker, create_dtm, create_by
  )
  SELECT
      @company, @license, @owner_id
    , IsNull(@vh_type, _vh_type)
    , IsNull(@plan, _plan)
    , reg_dtm   = IsNull(@start_dtm, _start_dtm)
    , start_dtm = IsNull(@ch_fm_dtm, _start_dtm)
    , end_dtm   = (NULL)
    , IsNull(@fee, _fee)
    , @srv_dis, @srv_loc
    , IsNull(IsNull(@floor, _floor), '')
    , IsNull(IsNull(@psn, _psn), '')
    , IsNull(IsNull(@srv_day1, _weekday1), 0)
    , IsNull(IsNull(@srv_day2, _weekday2), 0)
    , IsNull(IsNull(@srv_day3, _weekday3), 0)
    , IsNull(IsNull(@alt_license, _rotation), '')
    , IsNull(IsNull(@alt_specFee, _extra_fee), 0)
    , waxing=(CASE IsNull(@plan, _plan) WHEN 'A' THEN 1 WHEN 'B' THEN 1 ELSE 0 END)
    , @worker_id, @mod_dtm, @mod_by
  FROM o
   v
END
GO


--------------------------------------------------------------------------------------------------------------------------
PRINT Concat( 'Processed started @ ', CONVERT(TIME, SYSDATETIME()) )

;DELETE FROM VehicleService
;DELETE FROM SuspendedService
;DBCC SHRINKDATABASE (TKCar_MGT, 10)

 ;DECLARE @license     varchar(max)
 ;DECLARE @company     varchar(max)
 ;DECLARE @cd          varchar(max)
 ;DECLARE @loc         varchar(max)
 ;DECLARE @floor       varchar(max)
 ;DECLARE @psn         varchar(max)
 ;DECLARE @start_dtm   date
 ;DECLARE @ch_fm_dtm   date
 ;DECLARE @ch_to_dtm   date
 ;DECLARE @stop_reason varchar(max)
 ;DECLARE @plan        varchar(max)
 ;DECLARE @vh_type     int
 ;DECLARE @srv_day1    varchar(max)
 ;DECLARE @srv_day2    varchar(max)
 ;DECLARE @srv_day3    varchar(max)
 ;DECLARE @fee         decimal
 ;DECLARE @worker      varchar(max)
 ;DECLARE @alt_license varchar(max)
 ;DECLARE @alt_specFee decimal
 ;DECLARE @remarks     nvarchar(max)
 ;DECLARE @mod_dtm     datetime2
 ;DECLARE @mod_by      varchar(max)

 ;DECLARE @proc_row int = 1
 ;DROP TABLE IF EXISTS #t_stat
 ;CREATE TABLE #t_stat (cd char(2), cnt int, cnt_batch int, ellapsed float)
 ;INSERT INTO #t_stat (cd, cnt, cnt_batch, ellapsed) VALUES
  ('00', 0,0,0),('01', 0,0,0),('02', 0,0,0),('03', 0,0,0),('04', 0,0,0),
  ('05', 0,0,0),('06', 0,0,0),('07', 0,0,0),('08', 0,0,0),('09', 0,0,0)

--------------------------------------------------------------------------------------------------------------------------
  ;DECLARE @def_worker int
  ;SELECT @def_worker = uid FROM Worker WHERE worker_code = 'C0000'

;DECLARE cur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
  SELECT
    SCR_CarNumber, SCR_CompanyCode, SCR_ChangeItem,
    SCR_HouseCode, SCR_HouseFloor, SCR_CarLocation,
    SCR_StartDate, SCR_ChangeFmDate, SCR_ChangeToDate, SCR_StopReason,
    SCR_PlanCode, SCR_CarType,
    SCR_Servicedate1, SCR_Servicedate2, SCR_Servicedate3,
    SCR_ServicePrice, SCR_WorkerCode,
    SCR_AltCARNumber, SCR_AltSpecCharge, SCR_Remark, SCR_UpdateDate, SCR_UserID
  FROM TKCar_Old.dbo.TX_ServiceChangeRecord
--WHERE SCR_CarNumber = '9188'
  ORDER BY SCR_CarNumber, SCR_CompanyCode, SCR_UpdateDate -- match index

;OPEN cur
;FETCH NEXT FROM cur INTO
    @license, @company, @cd, @loc, @floor, @psn
  , @start_dtm, @ch_fm_dtm, @ch_to_dtm, @stop_reason, @plan, @vh_type
  , @srv_day1, @srv_day2, @srv_day3, @fee
  , @worker
  , @alt_license, @alt_specFee, @remarks, @mod_dtm, @mod_by

;DECLARE @batch_time datetime2 = SYSDATETIME()
WHILE @@FETCH_STATUS = 0
BEGIN


--PRINT @cd

  ;DECLARE @systime    datetime2 = SYSDATETIME()
  ;DECLARE @cnt        int

  IF NOT EXISTS(SELECT 1 FROM Vehicle WHERE cd_license = @license)
    PRINT Concat('inexists licenes: ', @license)

  ;DECLARE @owner_id  int
  ;DECLARE @worker_id int
  ;DECLARE @srv_dis   varchar(3)
  ;DECLARE @srv_loc   int

  ;SELECT @owner_id  = IsNull(Min(owner_id), 1) FROM Vehicle WHERE cd_license = @license
  ;SELECT @worker_id = IsNull(Min(uid), @def_worker) FROM Worker WHERE worker_code = @worker

  BEGIN TRY
  ;SELECT
      @srv_dis = (CASE
        WHEN @loc IS NULL        THEN 'X'
        WHEN @loc = '999'        THEN 'X'
        WHEN LEFT(@loc, 1) = '1' THEN 'K'
        ELSE LEFT(@loc, 1)
      END)
    ,@srv_loc = Convert(int, CASE
        WHEN @loc IS NULL       THEN 0
        WHEN @loc = '999'       THEN 1
        WHEN LEFT(@loc,1) = '1' THEN @loc
        ELSE RIGHT(@loc, 2)
      END)
    ,@srv_day1 = (CASE WHEN @srv_day1 IS NULL OR @srv_day1 IN ('1', '2', '3', '4', '5', '6', '7') THEN @srv_day1 ELSE '0' END)
    ,@srv_day2 = (CASE WHEN @srv_day2 IS NULL OR @srv_day2 IN ('1', '2', '3', '4', '5', '6', '7') THEN @srv_day2 ELSE '0' END)
    ,@srv_day3 = (CASE WHEN @srv_day3 IS NULL OR @srv_day3 IN ('1', '2', '3', '4', '5', '6', '7') THEN @srv_day3 ELSE '0' END)

  ;IF @cd NOT IN ('01', '03') AND NOT EXISTS(SELECT 1 FROM VehicleService WHERE company = @company AND cd_license = @license)
  BEGIN
    -- not exists then create from old records
    EXEC sp_tmp_VS_ins
        @owner_id, @license, @company, @cd, @srv_dis, @srv_loc, @floor, @psn, @start_dtm
      , @ch_fm_dtm, @ch_to_dtm, @stop_reason, @plan, @vh_type
      , @srv_day1, @srv_day2, @srv_day3, @fee, @worker_id
      , @alt_license, @alt_specFee, @remarks, @mod_dtm, @mod_by

    SET @cnt = @@ROWCOUNT
    IF @cnt = 0
      PRINT Concat('Failed to first attemp insert: ', @license)

  END

-- //-- regular update
  ;IF @cd = '01' -- new customer
  BEGIN
    IF EXISTS(SELECT 1 FROM VehicleService WHERE company = @company AND cd_license = @license AND end_dtm IS NULL)
      PRINT Concat('Invalid data 01: new customer for active customers: ', @license)
    ELSE
    BEGIN
      EXEC sp_tmp_VS_ins
        @owner_id, @license, @company, @cd, @srv_dis, @srv_loc, @floor, @psn, @start_dtm
      , @ch_fm_dtm, @ch_to_dtm, @stop_reason, @plan, @vh_type
      , @srv_day1, @srv_day2, @srv_day3, @fee, @worker_id
      , @alt_license, @alt_specFee, @remarks, @mod_dtm, @mod_by
    END
  END
  ELSE IF @cd = '03' -- restart service // only when old record exists, otherwise above should apply
  BEGIN

    IF NOT EXISTS(SELECT 1 FROM VehicleService WHERE company = @company AND cd_license = @license AND end_dtm IS NULL)
    BEGIN
      EXEC sp_tmp_VS_ins
        @owner_id, @license, @company, @cd, @srv_dis, @srv_loc, @floor, @psn, @start_dtm
      , @ch_fm_dtm, @ch_to_dtm, @stop_reason, @plan, @vh_type
      , @srv_day1, @srv_day2, @srv_day3, @fee, @worker_id
      , @alt_license, @alt_specFee, @remarks, @mod_dtm, @mod_by

    END -- if not exists active record
  END
  ELSE IF @cd = '02' -- terminate service
  BEGIN
    DELETE FROM VehicleService
    WHERE company    = @company
      AND cd_license = @license
      AND start_dtm  >= @ch_fm_dtm

    UPDATE VehicleService
    SET end_dtm = DateAdd(DAY, -1, @ch_fm_dtm)
    WHERE company    = @company
      AND cd_license = @license
      AND start_dtm  < @ch_fm_dtm
      AND (end_dtm IS NULL OR end_dtm > @ch_fm_dtm)

    ;SET @cnt = @@ROWCOUNT
    IF @cnt > 1
      PRINT CONCAT(' ', @cd, ' ', @license, ' ', 'update VS => ', @cnt);

    UPDATE SuspendedService
    SET remarks = Concat(@stop_reason, ' / ', @remarks)
       ,is_terminate = 1
    WHERE company    = @company
      AND cd_license = @license
      AND end_dtm    = @ch_fm_dtm

    IF @@ROWCOUNT = 0
      INSERT INTO SuspendedService(
        company, cd_license, owner_id, srv_plan,
        reg_dtm, end_dtm, fee, extra_fee,
        worker, worker_name, reason_id, is_terminate, remarks,
        create_dtm, create_by
      )
      SELECT
        company, cd_license, @owner_id, srv_plan,
        reg_dtm, end_dtm=(@ch_fm_dtm), fee, extra_fee,
        @worker_id, IsNull(@worker, ''),
        reason_id=(CASE WHEN @stop_reason = '公司停' THEN 4 ELSE 0 END),
        is_terminate=(1),
        Concat(@stop_reason, ' / ', @remarks),
        @mod_dtm, @mod_by
      FROM (
        SELECT TOP 1 *, rid = ROW_NUMBER() OVER (ORDER BY start_dtm DESC)
        FROM VehicleService
        WHERE company = @company AND cd_license = @license
      ) AS vs
      WHERE vs.rid = 1

  END
  ELSE IF @cd = '04' -- suspend service
  BEGIN

    -- INSERT INTO _LogVS SELECT @cd, @mod_dtm, * FROM VehicleService
    -- WHERE company    = @company
    --   AND cd_license = @license
    --   AND end_dtm IS NULL

    DELETE FROM VehicleService
    WHERE company    = @company
      AND cd_license = @license
      AND start_dtm  >= @ch_fm_dtm

    ;SET @cnt = @@ROWCOUNT -- check if NOT deleted anything
    IF @cnt = 0
      UPDATE VehicleService
      SET end_dtm = DateAdd(DAY, -1, @ch_fm_dtm)
      WHERE company    = @company
        AND cd_license = @license
        AND end_dtm IS NULL

    -- create a the termination log
    UPDATE SuspendedService
    SET remarks = Concat('[', @mod_dtm, ']:', @stop_reason, ' / ', @remarks, Char(13), remarks)
    WHERE company    = @company
      AND cd_license = @license
      AND end_dtm    = @ch_fm_dtm

    IF @@ROWCOUNT = 0
      INSERT INTO SuspendedService(
        company, cd_license, owner_id, srv_plan,
        reg_dtm, end_dtm, fee, extra_fee,
        worker, worker_name,reason_id, is_terminate, remarks,
        create_dtm, create_by
      )
      SELECT
        company, cd_license, @owner_id, srv_plan,
        reg_dtm, end_dtm=(@ch_fm_dtm), fee, extra_fee,
        @worker_id, IsNull(@worker, ''),
        reason_id=(CASE WHEN @stop_reason = '公司停' THEN 4 ELSE 0 END),
        is_terminate=(0),
        Concat('[', @mod_dtm, ']:', @stop_reason, ' / ', @remarks),
        @mod_dtm, @mod_by
      FROM (
        SELECT TOP 1 *, rid = ROW_NUMBER() OVER (ORDER BY start_dtm DESC)
        FROM VehicleService
        WHERE company = @company AND cd_license = @license
      ) AS vs
      WHERE vs.rid = 1

    IF @ch_to_dtm IS NOT NULL -- consider without `To_Date` as termination instead of suspension
      INSERT INTO VehicleService(
        company, cd_license, owner_id, vh_type, srv_plan,
        reg_dtm, start_dtm, end_dtm, fee,
        srv_dis, srv_loc, srv_floor, srv_psn,
        weekday1, weekday2, weekday3, rotation, extra_fee, waxing,
        worker, create_dtm, create_by
      )
      SELECT
        @company, @license, @owner_id, vh_type, srv_plan,
        reg_dtm, start_dtm=(@ch_to_dtm), end_dtm=(NULL), IsNull(@fee, fee),
        @srv_dis, @srv_loc, IsNull(@floor, srv_floor), IsNull(@psn, srv_psn),
        IsNull(@srv_day1, weekday1), IsNull(@srv_day2, weekday2), IsNull(@srv_day3, weekday3),
        IsNull(@alt_license, rotation), IsNull(@alt_specFee, extra_fee), waxing=(CASE IsNull(@plan, srv_plan) WHEN 'A' THEN 1 WHEN 'B' THEN 1 ELSE 0 END),
        @worker_id, @mod_dtm, @mod_by
      FROM (
        SELECT TOP 1 * FROM VehicleService WHERE company = @company AND cd_license = @license ORDER BY start_dtm DESC
      ) AS vs

  END
  ELSE IF @cd IN ('00', '06', '07', '08', '09') -- change customer information
  BEGIN

    --INSERT INTO _LogVS SELECT @cd, @mod_dtm, * FROM VehicleService
    --WHERE company    = @company
    --  AND cd_license = @license
    --  AND start_dtm  >= @ch_fm_dtm

    UPDATE VehicleService
    SET vh_type    = IsNull(@vh_type, vh_type)
      , srv_plan   = IsNull(@plan, srv_plan)
      , srv_dis    = @srv_dis
      , srv_loc    = @srv_loc
      , srv_floor  = IsNull(@floor, srv_floor)
      , srv_psn    = IsNull(@psn, srv_psn)
      , weekday1   = IsNull(@srv_day1, weekday1)
      , weekday2   = IsNull(@srv_day2, weekday2)
      , weekday3   = IsNull(@srv_day3, weekday3)
      , fee        = (CASE WHEN @cd = '07' THEN fee ELSE @fee END)
      , extra_fee  = IsNull(@alt_specFee, extra_fee)
      , rotation   = IsNull(@alt_license, rotation)
      , waxing     = (CASE @plan WHEN 'A' THEN 1 WHEN 'B' THEN 1 ELSE 0 END)
      , worker     = IsNull(@worker_id, worker)
      , create_dtm = @mod_dtm
      , create_by  = @mod_by
    WHERE company    = @company
      AND cd_license = @license
      AND start_dtm  >= @ch_fm_dtm

    IF 0 = @@ROWCOUNT
    BEGIN

      --INSERT INTO _LogVS SELECT @cd, @mod_dtm, * FROM VehicleService
      --WHERE company    = @company
      --  AND cd_license = @license
      --  AND end_dtm IS NULL

      UPDATE VehicleService
      SET end_dtm = DateAdd(DAY, -1, @ch_fm_dtm)
      WHERE company    = @company
        AND cd_license = @license
        AND end_dtm IS NULL

      ;SET @cnt = @@ROWCOUNT
      IF @cnt > 1
        PRINT CONCAT(' ', @cd,' update VS => ', @cnt);

      INSERT INTO VehicleService(
        company, cd_license, owner_id, vh_type, srv_plan,
        reg_dtm, start_dtm, end_dtm, fee,
        srv_dis, srv_loc, srv_floor, srv_psn,
        weekday1, weekday2, weekday3, rotation, extra_fee, waxing,
        worker, create_dtm, create_by
      )
      SELECT
        @company, @license, @owner_id, IsNull(@vh_type, vh_type), IsNull(@plan, srv_plan),
        reg_dtm, start_dtm=(@ch_fm_dtm), end_dtm=(NULL), (CASE WHEN @cd = '07' THEN fee ELSE @fee END),
        @srv_dis, @srv_loc, IsNull(@floor, srv_floor), IsNull(@psn, srv_psn),
        IsNull(@srv_day1, weekday1), IsNull(@srv_day2, weekday2), IsNull(@srv_day3, weekday3),
        IsNull(@alt_license, rotation), IsNull(@alt_specFee, extra_fee), waxing=(CASE @plan WHEN 'A' THEN 1 WHEN 'B' THEN 1 ELSE 0 END),
        @worker_id, @mod_dtm, @mod_by
      FROM (
        SELECT TOP 1 * FROM VehicleService WHERE company = @company AND cd_license = @license ORDER BY start_dtm DESC
      ) AS vs
    END
  END
  END TRY
  BEGIN CATCH
    PRINT Concat( @license, ':', @cd, ' failure: ', ERROR_MESSAGE())
    PRINT '--DEBUG--'
  END CATCH
  FETCH NEXT FROM cur INTO
      @license, @company, @cd, @loc, @floor, @psn
    , @start_dtm, @ch_fm_dtm, @ch_to_dtm, @stop_reason, @plan, @vh_type
    , @srv_day1, @srv_day2, @srv_day3, @fee
    , @worker
    , @alt_license, @alt_specFee, @remarks, @mod_dtm, @mod_by

  ;UPDATE #t_stat
   SET cnt       = 1+cnt
    , cnt_batch = 1+cnt_batch
    , ellapsed  = ellapsed + DateDiff(MILLISECOND, @systime, SYSDATETIME())
   WHERE cd = @cd

  SET @proc_row = @proc_row + 1
  IF 0 = @proc_row % 1000
  BEGIN
    PRINT Concat(CAST(@proc_row / 1000 AS varchar), 'k rows processed in ', DateDiff(MILLISECOND, @batch_time, SYSDATETIME()) / 1000.0, 's @ ', CONVERT(TIME, SYSDATETIME()) )
    SET @batch_time = SYSDATETIME()

    DECLARE @_logmsg varchar(max)
    SELECT @_logmsg = STRING_AGG(RIGHT(CONCAT('       ', Cast(cnt_batch AS varchar)), 6), ', ') WITHIN GROUP (ORDER BY cd)
    FROM #t_stat
    PRINT '    00,     01,     02,     03,     04,     05,     06,     07,     08,     09'
    PRINT @_logmsg

    -- reset batch stat
    ;UPDATE #t_stat SET cnt_batch = 0

  END

END

CLOSE cur
DEALLOCATE cur

PRINT 'completed, cleaning up'

;DROP PROCEDURE IF EXISTS sp_tmp_VS_ins


PRINT Concat( 'done @ ', CONVERT(TIME, SYSDATETIME()) )
SELECT cd, cnt, ellapsed
 , avgtime = (CASE WHEN cnt > 0 THEN ellapsed / cnt ELSE 0 END)
FROM #t_stat


SET NOCOUNT OFF


/*
;SELECT * FROM VehicleService
;SELECT * FROM SuspendedService


--  ;SELECT @cd       = Translate(UPPER(@cd), '０１２３４５６７８９', '0123456789')
--  ;SELECT @license  = Translate(UPPER(@license), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
--  ;SELECT @loc      = Translate(UPPER(@loc), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
--  ;SELECT @vh_type  = Translate(UPPER(@vh_type), '０１２３４５６７８９', '0123456789')
--  ;SELECT @srv_day1 = Translate(UPPER(@srv_day1), '０１２３４５６７８９', '0123456789')
--  ;SELECT @srv_day2 = Translate(UPPER(@srv_day2), '０１２３４５６７８９', '0123456789')
--  ;SELECT @srv_day3 = Translate(UPPER(@srv_day3), '０１２３４５６７８９', '0123456789')

SET STATISTICS IO ON
SET STATISTICS IO OFF

*/

