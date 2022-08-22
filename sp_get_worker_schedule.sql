
;DROP PROCEDURE IF EXISTS sp_get_worker_schedule
GO

;CREATE PROCEDURE sp_get_worker_schedule (
   @p_worker_id int
  ,@p_sd date
  ,@p_ed date
) AS
BEGIN

  -- somehow SQL Server has problems with paramters
  ;DECLARE @i_worker_id int = @p_worker_id
  ;DECLARE @i_sd date = @p_sd
  ;DECLARE @i_ed date = @p_ed

  -- query
  ;WITH DayList AS (
    /* recursive loop for getting week of days in the searching period (whole month) */
    SELECT
        l_date = @i_sd
      ,l_day  = 1+(DatePart(WEEKDAY, @i_sd) + @@DATEFIRST - 2) % 7
      ,ix     = Year(@i_sd)*100+Month(@i_sd)
    UNION ALL
    SELECT
        DateAdd(DAY, 1, l_date)
      ,1+(DatePart(WEEKDAY, DateAdd(DAY, 1, l_date)) + @@DATEFIRST - 2) % 7
      ,Year(DateAdd(DAY, 1, l_date))*100+Month(DateAdd(DAY, 1, l_date))
    FROM DayList
    WHERE l_date < @i_ed
  ), vs AS (
    SELECT
        dl.l_date
      ,company, cd_license, owner_id, srv_plan
      ,srv_dis, srv_loc
      ,srv_floor, srv_psn
      ,waxing
    FROM DayList AS dl
    JOIN VehicleService AS vs
    ON (  dl.l_date >= vs.start_dtm AND (vs.end_dtm IS NULL OR dl.l_date <= vs.end_dtm)
      AND (/* switch logics over plans */
          (vs.srv_plan = 'A' AND dl.l_day <> 6)
       OR (vs.srv_plan = 'B' AND dl.l_day IN (vs.weekday1, vs.weekday2, vs.weekday3))
       OR (vs.srv_plan = 'C' AND dl.l_day = vs.weekday1)
      )
    )
    JOIN TKUser AS w ON (vs.worker = w.id)
    WHERE w.active = 1
      AND vs.worker = @i_worker_id
      AND vs.start_dtm <= @i_ed
      AND (vs.end_dtm IS NULL OR vs.end_dtm >= @i_sd)
  )
  SELECT
      l_date
    ,company, vs.cd_license, srv_plan
    ,vs.srv_dis, vs.srv_loc, srv_floor, srv_psn
    ,loc_name = Trim(Concat(sl.name_zh, ' ', sl.name_en))
    ,waxing
    ,remarks = Trim( IsNull(u.remarks, '') + (CASE WHEN u.remarks IS NOT NULL AND u.remarks <> '' THEN Concat(';', Char(13), Char(10)) + v.remarks ELSE '' END))
  FROM vs
  JOIN ServiceLocation AS sl ON (vs.srv_dis = sl.srv_dis AND vs.srv_loc = sl.srv_loc)

  JOIN TKUser AS u ON (vs.owner_id = u.id)
  JOIN Vehicle AS v ON (vs.owner_id = v.owner_id AND vs.cd_license = v.cd_license)
  ORDER BY l_date, vs.srv_dis, vs.srv_loc, srv_floor, srv_psn
  OPTION (MAXRECURSION 465)

END
GO

;GRANT EXECUTE ON sp_get_worker_schedule TO tkweb
GO

