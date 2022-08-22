-- VER AUG 07
;DROP PROCEDURE IF EXISTS sp_calc_salary
GO

;CREATE PROCEDURE sp_calc_salary
   @p_sd date
  ,@p_ed date
  ,@p_uid int
AS
BEGIN

  ;SET NOCOUNT ON

  -- Validate
  ;IF @p_sd IS NULL RETURN
  ;IF @p_ed IS NULL RETURN

  -- Swap if start > end
  ;IF @p_sd > @p_ed
  BEGIN
    ;DECLARE @tmp_d date
    ;SELECT @tmp_d = @p_sd, @p_sd = @p_ed, @p_ed = @tmp_d
  END

  /* gather services provided and period for actual service charge calculation */
  ;DECLARE @tbl_vs TABLE (
    company    char(2),
    owner_id   int,
    worker     int,
    srv_dis    varchar(3),
    srv_loc    int,
    cd_license varchar(30),
    vh_type    tinyint,
    srv_plan   char(1),
    srv_floor  nvarchar(12),
    srv_psn    nvarchar(50),
    weekday1   tinyint,
    weekday2   tinyint,
    weekday3   tinyint,
    waxing     bit,
    task_start datetime2,
    task_end   datetime2
  )

  ;INSERT INTO @tbl_vs
   SELECT
     vs.company ,vs.owner_id
    ,vs.worker ,srv_dis ,srv_loc, vs.cd_license
    ,vh_type ,vs.srv_plan
    ,srv_floor ,srv_psn
    ,weekday1 ,weekday2 ,weekday3
    ,waxing
    ,task_start = (CASE WHEN @p_sd > start_dtm  THEN @p_sd ELSE start_dtm END)
    ,task_end   = (CASE WHEN vs.end_dtm IS NULL THEN @p_ed
                        WHEN @p_ed < vs.end_dtm THEN @p_ed
                        ELSE vs.end_dtm
                   END)
  FROM VehicleService AS vs
  WHERE (@p_uid IS NULL OR vs.worker = @p_uid)
    AND start_dtm <= @p_ed
    AND (vs.end_dtm IS NULL OR vs.end_dtm >= @p_sd)

  -- ===========================================================

  ;WITH a AS (
    /* produce row number for obtaining end-date for each pricing period */
    SELECT
       row_id = ROW_NUMBER() OVER (PARTITION BY sp.srv_dis, sp.srv_loc, sp.company, sp.cd_plan, sp.vh_type ORDER BY effect)
      ,*
    FROM ServicePlan AS sp
  ), PlanSalary AS (
    SELECT a1.*, end_dtm = IsNull( dateadd(day,-1,a2.effect), @p_ed )
    FROM a AS a1
    LEFT JOIN a AS a2
    ON (    a1.row_id + 1 = a2.row_id
        AND a1.srv_dis    = a2.srv_dis
        AND a1.srv_loc    = a2.srv_loc
        AND a1.company    = a2.company
        AND a1.cd_plan    = a2.cd_plan
        AND a1.vh_type    = a2.vh_type )
  ), DayList AS (
    /* recursive loop for getting week of days in the searching period (whole month) */
    SELECT l_date = @p_sd, l_day = 1+(DatePart(WEEKDAY, @p_sd) + @@DATEFIRST - 2) % 7
    UNION ALL
    SELECT DATEADD(DAY, 1, l_date), 1+(DatePart(WEEKDAY, DATEADD(DAY, 1, l_date)) + @@DATEFIRST - 2) % 7 FROM DayList
    WHERE l_date < @p_ed
  ), precalc AS (
    SELECT
       vs.owner_id, vs.worker, vs.srv_dis, vs.srv_loc, vs.cd_license
      ,vs.srv_plan, vs.vh_type
      ,base_salary = IsNull(
          (CASE srv_plan
            WHEN 'A' THEN w.salary_A
            WHEN 'B' THEN w.salary_B
            WHEN 'C' THEN w.salary_C
          END),
          IsNull(ps.salary, CONVERT(decimal(15,2), config.c_value2))
       )
      ,numerator = Convert(decimal(17, 4),
        CASE srv_plan
          /* Plan A: 6 days a week, deduct each day */
          WHEN 'A' THEN
            1+DATEDIFF(DAY, task_start, task_end)
          /* Plan B: 3 days a week, deduct each time */
          WHEN 'B' THEN
            1+DATEDIFF(DAY, task_start, task_end)
          /* Plan C: 1 day a week, deduct each time */
          WHEN 'C' THEN (
            SELECT COUNT(1) FROM DayList AS p
            WHERE p.l_date >= task_start AND p.l_date <= task_end AND l_day = weekday1
          )
          ELSE
            1
        END)
      ,denominator = Convert(decimal(17, 4),
        CASE srv_plan
          WHEN 'A' THEN DAY(@p_ed)
          WHEN 'B' THEN DAY(@p_ed)
          WHEN 'C' THEN (SELECT COUNT(1) FROM DayList WHERE l_day = weekday1)
          ELSE 1
        END)
      ,leave_cnt = Convert(decimal(17, 4),
        CASE srv_plan
          /* Plan A: 6 days a week, deduct each day */
          WHEN 'A' THEN (
            SELECT IsNull(Sum(1-pay_ratio), 0) FROM Leave AS l
            WHERE l.uid = worker AND leave_dtm >= task_start AND leave_dtm <= task_end
          )
          /* Plan B: 3 days a week, deduct each time */
          WHEN 'B' THEN (
            SELECT IsNull(Sum(1-pay_ratio), 0) FROM Leave AS l
            WHERE l.uid = worker AND leave_dtm >= task_start AND leave_dtm <= task_end
          )
          /* Plan C: 1 day a week, deduct each time */
          WHEN 'C' THEN
            (SELECT Sum(1-pay_ratio)
             FROM ( SELECT l_date FROM DayList AS p
                    WHERE p.l_date >= task_start AND p.l_date <= task_end AND l_day = weekday1
                  ) AS _r
             JOIN Leave AS l
             ON l.leave_dtm = _r.l_date AND l.uid = worker
            )
          ELSE
            1
        END)
      ,srv_drng = Concat(
            '{"p":"'    , srv_plan
          , '","s":"'   , FORMAT(task_start, 'yyyy-MM-dd')
          , '","e":"'   , FORMAT(task_end, 'yyyy-MM-dd')
          , '","psn":"' , STRING_ESCAPE(Trim(srv_floor + (CASE WHEN vs.srv_psn IS NOT NULL AND vs.srv_psn <> '' THEN ' ' + vs.srv_psn ELSE '' END)), 'json')
          , '","d1":'   , weekday1
          ,  ',"d2":'   , weekday2
          ,  ',"d3":'   , weekday3
          ,  ',"wx":'   , (CASE WHEN waxing = 1 THEN 'true' ELSE 'false' END)
          , '}'
        )
    FROM @tbl_vs AS vs
    LEFT JOIN Worker AS w
    ON (vs.worker = w.uid)
    LEFT JOIN PlanSalary AS ps
    ON (    ps.company  = vs.company
        AND ps.srv_dis  = vs.srv_dis
        AND ps.srv_loc  = vs.srv_loc
        AND ps.vh_type  = vs.vh_type
        AND ps.cd_plan  = vs.srv_plan
        AND ps.effect  <= vs.task_start
        AND ps.end_dtm >= vs.task_end
    )
    LEFT JOIN SystemConfig AS config
    ON (config.c_value1 = CONCAT(vs.srv_plan, vs.vh_type))
    WHERE dict_key = 'DATA' AND grp_key = 'SALARY'
  ), calc AS (
    SELECT
       owner_id, worker, srv_dis ,srv_loc, cd_license
      ,srv_plan ,vh_type
      ,salary = Convert(decimal(15, 2), CASE
        WHEN 0 = denominator THEN 0
        ELSE base_salary * numerator / denominator
      END)
      ,leave_deduct = Convert(decimal(15, 2), CASE
        WHEN 0 = denominator THEN 0
        ELSE base_salary * leave_cnt / denominator
      END)
      ,srv_drng
    FROM precalc
  ), vsw AS (
    SELECT
       worker, srv_dis ,srv_loc
      ,count_1 = Count(DISTINCT (CASE srv_plan WHEN 'A' THEN cd_license END))
      ,count_2 = Count(DISTINCT (CASE srv_plan WHEN 'B' THEN cd_license END))
      ,count_3 = Count(DISTINCT (CASE srv_plan WHEN 'C' THEN cd_license END))
      ,task_start = Min(task_start)
      ,task_end   = Max(task_end)
    FROM @tbl_vs AS vs
    GROUP BY worker, srv_dis, srv_loc
  ), o1 AS (
    SELECT
       worker, srv_dis, srv_loc, calc.cd_license
      ,salary_1       = IsNull( SUM(CASE srv_plan WHEN 'A' THEN salary END), 0)
      ,salary_2       = IsNull( SUM(CASE srv_plan WHEN 'B' THEN salary END), 0)
      ,salary_3       = IsNull( SUM(CASE srv_plan WHEN 'C' THEN salary END), 0)
      ,leave_deduct_1 = IsNull( SUM(CASE srv_plan WHEN 'A' THEN leave_deduct END), 0)
      ,leave_deduct_2 = IsNull( SUM(CASE srv_plan WHEN 'B' THEN leave_deduct END), 0)
      ,leave_deduct_3 = IsNull( SUM(CASE srv_plan WHEN 'C' THEN leave_deduct END), 0)
      ,srv_drng       = '[' + STRING_AGG(srv_drng, ',') + ']'
      ,remarks        = Trim( IsNull(Min(u.remarks), '') + CHAR(13) + CHAR(10) + IsNull(Min(v.remarks), '') )
    FROM calc
    JOIN TKUser AS u
    ON (calc.owner_id = u.id)
    JOIN Vehicle AS v
    ON (calc.owner_id = v.owner_id AND calc.cd_license = v.cd_license)
    GROUP BY worker, srv_dis, srv_loc, calc.cd_license
  ), o2 AS (
    SELECT
       worker         = o1.worker
      ,srv_dis        = o1.srv_dis
      ,srv_loc        = o1.srv_loc
      ,salary_1       = IsNull( SUM(salary_1), 0 )
      ,salary_2       = IsNull( SUM(salary_2), 0 )
      ,salary_3       = IsNull( SUM(salary_3), 0 )
      ,leave_deduct_1 = IsNull( SUM(leave_deduct_1), 0 )
      ,leave_deduct_2 = IsNull( SUM(leave_deduct_2), 0 )
      ,leave_deduct_3 = IsNull( SUM(leave_deduct_3), 0 )
      ,salary_total   = IsNull( SUM(salary_1 + salary_2 + salary_3 - leave_deduct_1 - leave_deduct_2 - leave_deduct_3), 0)
      ,srv_detail   = '{' + STRING_AGG(Concat(
          Cast('"' AS varchar(max)), cd_license, '":{'
          , '"range":', srv_drng 
          , ',"remarks":"', STRING_ESCAPE(Trim(remarks), 'json')
          , '","fs_end":', (CASE WHEN cass.end_dtm IS NULL THEN 'null' ELSE Concat('"', cass.end_dtm, '"') END)
          , '}'), ',') + '}'
    FROM o1
    OUTER APPLY (
      SELECT TOP 1 end_dtm
      FROM SuspendedService AS ss
      WHERE is_terminate = 1
        AND cd_license = o1.cd_license
        AND end_dtm >= DateAdd(Day, -30, GETDATE())
      ORDER BY end_dtm ASC
    ) AS cass
    GROUP BY o1.worker, o1.srv_dis, o1.srv_loc
  ), fact AS (
    SELECT
       o.worker, o.srv_dis, o.srv_loc
      ,task_start, task_end
      ,count_1, count_2, count_3
      ,salary_1, salary_2, salary_3
      ,leave_deduct_1, leave_deduct_2, leave_deduct_3
      ,mpf = Convert(decimal(15,2), sl.mpf * salary_total * 0.05)
      ,srv_detail
    FROM o2 AS o
    LEFT JOIN vsw ON (o.worker = vsw.worker AND o.srv_dis = vsw.srv_dis AND o.srv_loc = vsw.srv_loc)
    JOIN ServiceLocation AS sl ON (o.srv_dis = sl.srv_dis AND o.srv_loc = sl.srv_loc)
  )
  SELECT
     worker
    ,fact.srv_dis
    ,fact.srv_loc
    ,loc_name = RTrim(Concat(sl.name_zh, ' ', sl.name_en))
    ,task_start
    ,task_end
    ,count_1, count_2, count_3
    ,salary_1, salary_2, salary_3
    ,leave_deduct_1, leave_deduct_2, leave_deduct_3
    ,fact.mpf
    ,srv_detail
  FROM fact
  JOIN ServiceLocation AS sl
  ON (fact.srv_dis = sl.srv_dis AND fact.srv_loc = sl.srv_loc)
  OPTION (MAXRECURSION 1000)

END
GO

GRANT EXECUTE ON sp_calc_salary TO tkweb
GO
