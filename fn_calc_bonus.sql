-- VER AUG 07

;DROP FUNCTION IF EXISTS fn_calc_bonus
GO

;CREATE FUNCTION fn_calc_bonus(
  @p_ixdate date,
  @p_uid    int
)
RETURNS @out TABLE (
   worker   int
  ,bonus    int
  ,deduct   int
  ,total    int
  ,json_add varchar(max)
  ,json_sub varchar(max)
  ,rot_cnt  int
  ,rot_sal  int
  ,wax_cnt  int
  ,wax_sal  int
  ,json_rot varchar(max)
  ,json_wax varchar(max)
) AS
BEGIN
  ;IF @p_ixdate IS NULL RETURN

  ;DECLARE @ix   int  = Year(@p_ixdate)*100+Month(@p_ixdate)
  ;DECLARE @p_sd date = DateAdd(MONTH, -3, Cast(Concat(@ix, '01') AS date))
  ;DECLARE @p_td date = DateFromParts(Year(@p_ixdate), Month(@p_ixdate), 1)
  ;DECLARE @p_ed date = EOMonth(Cast(Concat(@ix, '01') AS date))

  -- get rotation salary
  ;DECLARE @sys_waxsalary float
  ;DECLARE @sys_rotsalary float
  ;SELECT @sys_waxsalary = Convert(float, c_value2) FROM SystemConfig
   WHERE dict_key = 'DATA' AND grp_key = 'SALARY_EX' AND c_value1 = 'WAXING'
  ;SELECT @sys_rotsalary = Convert(float, c_value2) FROM SystemConfig
   WHERE dict_key = 'DATA' AND grp_key = 'SALARY_EX' AND c_value1 = 'ROTATION'

  -- get monthly salary
  ;WITH d AS(
    SELECT
       ix  = Year(vs.reg_dtm)*100+Month(vs.reg_dtm)
      ,rid = ROW_NUMBER() OVER (PARTITION BY Year(vs.reg_dtm)*100+Month(vs.reg_dtm), vs.cd_license ORDER BY start_dtm)
      ,vs.cd_license, srv_plan, reg_dtm, worker
    FROM VehicleService AS vs
    JOIN Vehicle AS v
    ON (vs.owner_id = v.owner_id AND vs.cd_license = v.cd_license)
    WHERE (@p_uid IS NULL OR vs.worker = @p_uid)
      AND v.source = 2
      AND vs.reg_dtm >= @p_sd
  ), NewCust AS (
    SELECT ix, worker, reg_dtm, cd_license, srv_plan FROM d WHERE rid = 1
  ), Defaulter AS (
    SELECT DISTINCT ix = ix_yrmo, cd_license, srv_plan, end_dtm, worker
    FROM SuspendedService
    WHERE end_dtm >= @p_sd AND end_dtm <= @p_ed
      AND is_terminate = 1
  ), fact AS (
    SELECT
       n.worker, n.cd_license, n.srv_plan
      ,join_ix = n.ix, deft_ix = d.ix
      ,reg_dtm, end_dtm
      ,diff = DateDiff(MONTH, reg_dtm, end_dtm)
    FROM NewCust AS n
    LEFT JOIN Defaulter AS d
    ON (n.cd_license = d.cd_license AND n.worker = d.worker)
  ), prep1 AS (
    SELECT
        t = CASE WHEN join_ix = @ix THEN 'add' ELSE 'base' END
      ,join_ix, worker, srv_plan
      ,cnt_new = COUNT(DISTINCT cd_license)
      ,json_license = STRING_AGG(
          Cast('{"l":"' + STRING_ESCAPE(cd_license, 'json') + '","p":"' + srv_plan + '"}' AS varchar(max))
        , ',') 
    FROM fact
    WHERE (deft_ix IS NULL OR (deft_ix = @ix AND diff < 3))
    GROUP BY join_ix, worker, srv_plan
    UNION ALL
    SELECT
       t = 'sub'
      ,join_ix, worker, srv_plan
      ,cnt_def = COUNT(DISTINCT cd_license)
      ,json_license = STRING_AGG(
          Cast('{"l":"' + STRING_ESCAPE(cd_license, 'json') + '","p":"' + srv_plan + '"}' AS varchar(max))
        , ',') 
    FROM fact
    WHERE deft_ix = @ix AND diff < 3
    GROUP BY join_ix, worker, srv_plan
  ), MoCount AS (
    SELECT
       join_ix, worker, srv_plan
      ,base_ = IsNull([base], 0)
      ,sub_  = IsNull([sub], 0)
      ,add_  = IsNull([add], 0)
    FROM prep1
    PIVOT (
      SUM(cnt_new) FOR t IN ([base], [sub], [add])
    ) AS pvt
  ), MoBonusAdj AS (
    SELECT 
       join_ix
      ,worker
      ,bonus = SUM(add_ * (CASE srv_plan
            WHEN 'A' THEN bonus_A
            WHEN 'B' THEN bonus_B
            WHEN 'C' THEN bonus_C
          END))
      ,deduct = MIN(bonus_extra) * (CASE WHEN SUM(base_) < 4 THEN 0 ELSE (CASE WHEN SUM(base_) - 3 < SUM(sub_) THEN SUM(base_) - 3 ELSE SUM(sub_) END) END)
        + SUM(sub_ * (CASE srv_plan
            WHEN 'A' THEN bonus_A
            WHEN 'B' THEN bonus_B
            WHEN 'C' THEN bonus_C
          END))
    FROM MoCount
    JOIN Worker AS w
    ON (worker = w.uid)
    GROUP BY join_ix, worker
  ), DetailLicense AS (
    SELECT
      worker, json_add = [add], json_sub = [sub]
    FROM (
      SELECT t, worker, json_license = '[' + STRING_AGG(json_license, ',') + ']'
      FROM prep1
      GROUP BY t, worker
    ) AS _
    PIVOT (
      MIN(json_license) FOR t IN ([add], [sub])
    ) AS pvt
  ), MoBonusFinal AS (
    SELECT
       worker
      ,bonus  = SUM(bonus)
      ,deduct = SUM(deduct)
      ,total  = SUM(bonus) - SUM(deduct)
    FROM MoBonusAdj
    GROUP BY worker
  ), vs AS (
    SELECT worker, cd_license, rotation
      , has_rot = (CASE WHEN Trim(rotation) <> '' THEN 1 ELSE 0 END)
      , waxing = 0+waxing
    FROM VehicleService
    WHERE start_dtm <= @p_ed
      AND (end_dtm IS NULL OR end_dtm >= @p_td)
  ), ServiceCount AS (
    SELECT worker = IsNull(t1.worker, t2.worker), rot_cnt, wax_cnt, json_rot, json_wax
    FROM (
      SELECT worker, rot_cnt = Count(cd_license)
           , json_rot = '[' + STRING_AGG(Convert(varchar(max), Concat('"', cd_license, ' / ', rotation, '"')), ',') + ']'
      FROM (
        SELECT worker, cd_license, rotation = MAX(rotation), has_rot = MAX(has_rot) FROM vs
        WHERE (@p_uid IS NULL OR vs.worker = @p_uid)
        GROUP BY worker, cd_license HAVING MAX(has_rot) > 0
      ) AS _
      GROUP BY worker
    ) AS t1
    FULL JOIN (
      SELECT worker, wax_cnt = Count(DISTINCT cd_license)
           , json_wax = '[' + STRING_AGG(Convert(varchar(max), Concat('"', cd_license, '"')), ',') + ']'
      FROM (
        SELECT worker, cd_license, waxing = MAX(waxing) FROM vs
        WHERE (@p_uid IS NULL OR vs.worker = @p_uid)
        GROUP BY worker, cd_license HAVING MAX(waxing) > 0
      ) AS _
      GROUP BY worker
    ) AS t2
    ON (t1.worker = t2.worker)
  )
  INSERT INTO @out
  SELECT
      worker = IsNull(mbf.worker, srv.worker)
    , bonus  = IsNull(bonus, 0)
    , deduct = IsNull(deduct, 0)
    , total  = IsNull(total, 0)
    , json_add, json_sub
    , rot_cnt = IsNull(rot_cnt, 0)
    , rot_sal = IsNull(rot_cnt, 0) * IsNull(w.sal_rot, @sys_rotsalary)
    , wax_cnt = IsNull(wax_cnt, 0)
    , wax_sal = IsNull(wax_cnt, 0) * IsNull(w.sal_wax, @sys_waxsalary)
    , json_rot, json_wax
  FROM MoBonusFinal AS mbf
  LEFT JOIN Worker AS w
  ON (mbf.worker = w.uid)
  JOIN DetailLicense AS dlc
  ON (mbf.worker = dlc.worker)
  FULL JOIN ServiceCount AS srv
  ON (mbf.worker = srv.worker)
  WHERE NOT (bonus = 0 AND deduct = 0 AND rot_cnt = 0 AND wax_cnt = 0)

  ;RETURN
END
GO

;GRANT SELECT ON fn_calc_bonus TO tkweb
GO

