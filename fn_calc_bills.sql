
;DROP FUNCTION IF EXISTS fn_calc_bills
GO

;CREATE FUNCTION fn_calc_bills
(	
  @p_sd  date,
  @p_ed  date,
  @p_uid int   = NULL
)
RETURNS @out TABLE  (
   company    char(2)       NOT NULL
  ,ix_yrmo    int           NOT NULL
  ,uid        int           NOT NULL
  ,cd_license varchar(30)   NOT NULL
  ,amount     decimal(15,2) NOT NULL
  ,bill_start date          NOT NULL
  ,bill_end   date          NOT NULL
  ,due_dtm    datetime2     NOT NULL
)
AS
BEGIN
  ;DECLARE @tmpId TABLE (id int)

  ;IF @p_uid = -1
     WITH MonthList AS (
       SELECT nxtmo = DateAdd(MONTH, 1, DateFromParts(Year(@p_sd), Month(@p_sd), 1)), ix = Year(@p_sd)*100+Month(@p_sd)
       UNION ALL
       SELECT DateAdd(MONTH, 1, nxtmo), Year(nxtmo)*100+Month(nxtmo) FROM MonthList
       WHERE nxtmo < @p_ed
     )
     INSERT INTO @tmpId SELECT id FROM Customer WHERE id NOT IN (
       SELECT DISTINCT uid FROM Bill WHERE ix_yrmo IN (SELECT ix FROM MonthList)
       UNION
       SELECT DISTINCT uid FROM BillArchive WHERE ix_yrmo IN (SELECT ix FROM MonthList)
     )
   ELSE IF @p_uid IS NOT NULL
     INSERT INTO @tmpId SELECT @p_uid
   ELSE
     INSERT INTO @tmpId SELECT id FROM Customer

  ;WITH DayList AS (
    /* recursive loop for getting week of days in the searching period (whole month) */
    SELECT
       l_date = DateFromParts(Year(@p_sd), Month(@p_sd), 1)
      ,l_day  = 1+(DatePart(WEEKDAY, @p_sd) + @@DATEFIRST - 2) % 7
      ,ix     = Year(@p_sd)*100+Month(@p_sd)
    UNION ALL
    SELECT
       DateAdd(DAY, 1, l_date)
      ,1+(DatePart(WEEKDAY, DateAdd(DAY, 1, l_date)) + @@DATEFIRST - 2) % 7    --DatePart(WEEKDAY, DateAdd(DAY, 1, l_date))
      ,Year(l_date)*100+Month(l_date)
    FROM DayList
    WHERE l_date < EOMonth(@p_ed)
  ), BillingMonths AS (
    SELECT
      ix = Year(@p_sd)*100 + Month(@p_sd),
      batch_start = DateFromParts(Year(@p_sd), Month(@p_sd), 1),
      batch_end   = DateAdd(DAY, -1, DateAdd(MONTH, 1, DateFromParts(Year(@p_sd),Month(@p_sd), 1))),
      next_month  = DateAdd(MONTH, 1, DateFromParts(Year(@p_sd),Month(@p_sd), 1))
    UNION ALL
    SELECT
      ix = Year(next_month)*100 + Month(next_month),
      batch_start = next_month,
      batch_end   = DateAdd(DAY, -1, DateAdd(MONTH, 1, next_month)),
      next_month  = DateAdd(MONTH, 1, next_month)
    FROM BillingMonths
    WHERE next_month < @p_ed
  ), fact1 AS (
    /* gather services provided and period for actual service charge calculation */
    SELECT
       company
      ,ix_yrmo    = ix
      ,batch_start
      ,batch_end
      ,uid        = owner_id
      ,cd_license = vs.cd_license
      ,vh_type    = vs.vh_type
      ,srv_plan   = vs.srv_plan
      ,vs.weekday1
      ,vs.weekday2
      ,vs.weekday3
      ,mofee      = vs.fee
      ,exfee      = vs.extra_fee
      ,bill_start = (CASE WHEN batch_start > vs.start_dtm THEN batch_start ELSE vs.start_dtm END)
      ,bill_end   = (CASE WHEN batch_end <= IsNull(vs.end_dtm, batch_end) THEN batch_end ELSE vs.end_dtm END)
    FROM VehicleService AS vs
    JOIN BillingMonths AS bm
    ON (start_dtm <= batch_end AND (end_dtm IS NULL OR end_dtm >= batch_start))
    WHERE owner_id IN (SELECT * FROM @tmpId)
  ), fact2 AS (
    SELECT
      /* calculate actual fee by plan */
       company
      ,ix_yrmo
      ,uid
      ,cd_license
      ,exfee
      ,amount = CAST(mofee * (CASE srv_plan
          /* Plan A: 6 days a week, deduct each DAY */
          WHEN 'A' THEN
            CAST(1+DATEDIFF(DAY, bill_start, bill_end) AS float) / DAY(EOMonth(batch_end))
          /* Plan B: 3 days a week, deduct each DAY */
          WHEN 'B' THEN
            CAST(1+DATEDIFF(DAY, bill_start, bill_end) AS float) / DAY(EOMonth(batch_end))
          /* Plan C: 1 day a week, deduct each TIME */
          WHEN 'C' THEN
            (CASE WHEN (SELECT COUNT(1) FROM DayList AS p WHERE p.l_day = weekday1 AND p.l_date >= batch_start AND p.l_date <= batch_end) > 0 THEN
              CAST(
                (SELECT COUNT(1) FROM DayList AS p WHERE p.l_date >= bill_start AND p.l_date <= bill_end AND l_day = weekday1)
              AS float) /
                (SELECT COUNT(1) FROM DayList AS p WHERE p.l_day = weekday1 AND p.l_date >= batch_start AND p.l_date <= batch_end)
              ELSE 0 END)
          WHEN 'D' THEN
            1 -- this is the ratio * monthly fee
          ELSE
            1 -- for all other unknown plans, always full monthly payment
        END) AS decimal(15, 2))
      ,batch_start
      ,batch_end
      ,bill_start
      ,bill_end
    FROM fact1
  ), fact3 AS (
    SELECT
       company
      ,ix_yrmo
      ,uid
      ,cd_license
      ,amount      = Max(exfee) + Round(SUM(amount), 0)
      ,bill_start  = Min(bill_start)
      ,bill_end    = Max(bill_end)
      ,batch_start = Min(batch_start)
      ,batch_end   = Max(batch_end)
    FROM fact2
    GROUP BY company, ix_yrmo, uid, cd_license
  )
  INSERT INTO @out
  SELECT
     company
    ,ix_yrmo
    ,uid
    ,cd_license
    ,amount
    ,bill_start
    ,bill_end
    ,due_dtm = (CASE WHEN 1=cust.is_mobill
       THEN EOMonth(DateAdd(DAY, 1, batch_end)) -- bill end
       ELSE EOMonth(batch_start)
     END)
  FROM fact3
  JOIN Customer AS cust ON (uid = cust.id)
  ORDER BY uid, bill_start
  OPTION (MAXRECURSION 1000)

  ;RETURN
END
GO

;GRANT SELECT ON dbo.fn_calc_bills TO tkweb
GO
