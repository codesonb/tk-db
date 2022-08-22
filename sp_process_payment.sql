--VER JUL 28

;DROP PROCEDURE IF EXISTS sp_process_payment
GO

;CREATE PROCEDURE sp_process_payment
   @p_uid          int
  ,@p_company      char(2)
  ,@p_license      varchar(max)
  ,@p_amount       decimal(15,2)
  ,@p_payment_type char(1)
  ,@p_ref_code     varchar(max)
  ,@p_transfer_dtm datetime2
  ,@p_remarks      varchar(max)
  ,@p_create_by    varchar(max)
  ,@p_dryrun       bit = 0
AS
BEGIN TRANSACTION
BEGIN TRY
  ;SET NOCOUNT ON

  ;DECLARE @now  datetime2 = GETDATE()
  ;DECLARE @ix   int       = Year(@now)*100+Month(@now)

  ;DECLARE @settled_amount decimal(15, 2) = 0

  -- find next sequence number
  ;DECLARE @mx_useq int
  ;SELECT @mx_useq = 1+IsNull(Max(useq), 0) FROM Payment WHERE ix_yrmo = @ix AND uid = @p_uid

  -- find user balance
  ;DECLARE @qualified_balance decimal(15, 2)
  ;SELECT @qualified_balance = balance + @p_amount
   FROM Customer AS c
   WHERE c.id = @p_uid

  -- find reference monthly fee
  BEGIN
    ;DECLARE @ref_fee int = @qualified_balance

    ;DECLARE @tmp_ix  int
    ;DECLARE @cur_mo date

    ;SELECT @tmp_ix = Max(ix) FROM (
      SELECT ix = Min(ix_yrmo)
      FROM Bill
      WHERE uid = @p_uid AND (@p_license IS NULL OR cd_license = @p_license)
      UNION ALL
      SELECT ix = Year(ixd)*100+Month(ixd)
      FROM (
        SELECT ixd = (CASE WHEN Max(ix_yrmo) IS NOT NULL THEN DateAdd(Month, 1, Cast(Concat(Max(ix_yrmo), '01') AS date)) END)
        FROM BillArchive
        WHERE uid = @p_uid AND (@p_license IS NULL OR cd_license = @p_license)
      ) AS _
      UNION ALL
      SELECT Year(Max(start_dtm))*100+Month(Max(start_dtm))
      FROM VehicleService
      WHERE owner_id = @p_uid
        AND (@p_license IS NULL OR cd_license = @p_license)
    ) AS _

    IF @tmp_ix IS NOT NULL
    BEGIN
      ;SET @cur_mo = Cast(Concat(@tmp_ix, '01') AS date)

      ;PRINT Concat('starting month: ', @cur_mo)

      ;DECLARE @nwbill decimal(15, 2) = -1
      WHILE (@ref_fee > 0 AND @nwbill <> 0)
      BEGIN
        EXEC sp_recalc_bills__UNSAFE @tmp_ix, @p_uid
      
        ;SELECT @nwbill = IsNull(SUM(amount - discount), 0)
         FROM Bill
         WHERE (@p_license IS NULL OR cd_license = @p_license)
           AND uid = @p_uid
           AND ix_yrmo = @tmp_ix

        ;SET @cur_mo = DateAdd(Month, 1, @cur_mo)
        ;SET @tmp_ix = Year(@cur_mo)*100+Month(@cur_mo)
        ;SET @ref_fee = @ref_fee - @nwbill

      END -- WHILE
    END -- IF // somehow prevent when no any record is under a vehicle but the user trigger this action, everything should go to balance
     
  END -- BLOCK

  -- cache for insert and delete
  ;WITH fact AS (
    SELECT
      b1.*, cumulative_amount = Sum(amount - discount) OVER (PARTITION BY [uid] ORDER BY ix_yrmo, amount - discount, cd_license)
    FROM Bill AS b1
    WHERE b1.uid = @p_uid
      AND (@p_license IS NOT NULL OR b1.company = @p_company)
      AND (@p_license IS NULL OR b1.cd_license = @p_license)
  )
  SELECT *
  INTO #tmp -- temp table of successful bills paid
  FROM fact
  WHERE cumulative_amount <= @qualified_balance

  -- move items
  ;INSERT INTO BillArchive (
      company, ix_yrmo, uid, cd_license, bill_type, create_dtm, amount, discount,
      bill_start, bill_end, due_dtm, iv_ix, iv_seq )
   SELECT
      company, ix_yrmo, uid, cd_license, bill_type, create_dtm, amount, discount,
      bill_start, bill_end, due_dtm, @ix, @mx_useq
   FROM #tmp

  -- remove items
  ;DELETE Bill FROM #tmp AS t
   WHERE Bill.company    = t.company
     AND Bill.ix_yrmo    = t.ix_yrmo
     AND Bill.uid        = t.uid
     AND Bill.cd_license = t.cd_license
     AND Bill.bill_type  = 1 -- for auto generated bills

  -- find extra balance
  SELECT @settled_amount = IsNull(SUM(amount - discount), 0) FROM #tmp

  -- update customer balance
  ;UPDATE Customer
   SET last_payment = @now
      ,balance      = @qualified_balance - @settled_amount
   WHERE Customer.id = @p_uid

  -- get information
  ;DECLARE @applied_lics varchar(max)
  ;SELECT @applied_lics = IsNull( STRING_AGG( cd_license, ',' ), '*BALANCE(CR)*' )
   FROM (SELECT DISTINCT cd_license FROM #tmp) AS _

  -- detect company
  /*                             (( FORCE SELECTION MODE ))
  ;IF @p_company IS NULL
   SELECT TOP 1 @p_company = company FROM #tmp

  -- no bills be qualified for settling
  ;IF @p_company IS NULL
   BEGIN
    ;WITH vs AS (
       SELECT company, rid = ROW_NUMBER() OVER (ORDER BY start_dtm DESC)
       FROM VehicleService
       WHERE owner_id = @p_uid AND cd_license = @p_license
     )
     SELECT @p_company = company
     FROM vs
     WHERE rid = 1
   END
  */

  -- detect company
  /*                             (( AUTO SELECTION MODE ))
  */
  ;DECLARE @b_company char(2)
  ;SELECT TOP 1 @b_company = company FROM #tmp

  ;IF @b_company IS NULL
   BEGIN
    ;WITH vs AS (
       SELECT company, rid = ROW_NUMBER() OVER (ORDER BY start_dtm DESC)
       FROM VehicleService
       WHERE owner_id = @p_uid AND cd_license = @p_license
     )
     SELECT @b_company = company
     FROM vs
     WHERE rid = 1
   END

  ;IF @b_company IS NULL SET @b_company = @p_company

  -- create payment record
  ;INSERT INTO Payment(
    company, ix_yrmo, uid, useq, cd_license,
    cust_name, amount, payment_type, ref_code, transfer_dtm,
    create_dtm, create_by, mod_dtm, mod_by, remarks
  )
  SELECT
    @b_company, @ix, @p_uid, @mx_useq, @applied_lics,
    u.display_name, @p_amount, @p_payment_type, @p_ref_code, @p_transfer_dtm,
    @now, @p_create_by, @now, @p_create_by, @p_remarks
  FROM TKUser AS u
  WHERE u.id = @p_uid

  -- clear cache
  ;DROP TABLE IF EXISTS #tmp

  ;IF @p_dryrun = 1
   BEGIN
    ;ROLLBACK
    ;PRINT Concat('qualified_balance = :', @qualified_balance)

    -- show result
    ;SELECT tb = 'Bill MIN', ix = Min(ix_yrmo)
     FROM Bill
     WHERE uid = @p_uid AND (@p_license IS NULL OR cd_license = @p_license)
     UNION ALL
     SELECT tb = 'BillArchive MAX', ix = Year(ixd)*100+Month(ixd)
     FROM (
       SELECT ixd = (CASE WHEN Max(ix_yrmo) IS NOT NULL THEN DateAdd(Month, 1, Cast(Concat(Max(ix_yrmo), '01') AS date)) END)
       FROM BillArchive
       WHERE uid = @p_uid AND (@p_license IS NULL OR cd_license = @p_license)
     ) AS _
     UNION ALL
     SELECT tb = 'VehicleService MAX', ix = Year(Max(start_dtm))*100+Month(Max(start_dtm))
     FROM VehicleService
     WHERE owner_id = @p_uid
       AND (@p_license IS NULL OR cd_license = @p_license)
   END
   ELSE
    COMMIT

END TRY
BEGIN CATCH
  ;ROLLBACK
  ;INSERT INTO AuditError(create_dtm, caller_class, caller_member, msg)
   SELECT GETDATE(), 'STORED_PROCEDURE', 'sp_process_payment', ERROR_MESSAGE()

  ;PRINT 'Bill generation failed: ' + ERROR_MESSAGE()
  ;THROW 52001, 'Database Operation Failed', 1
END CATCH
GO

;GRANT EXECUTE ON dbo.sp_process_payment TO tkweb
GO

