
;DROP PROCEDURE IF EXISTS sp_report_location_count
GO

;CREATE PROCEDURE sp_report_location_count
   @p_sd date,
   @p_ed date
AS
BEGIN
  -- VER: 2024-03-18

  ;DECLARE @sd date = @p_sd
  ;DECLARE @ed date = @p_ed
  
  ;WITH IXPeriod AS (
    SELECT
        ix = Cast(FORMAT(@sd,'yyyyMM') AS int)
      , ls = DATEFROMPARTS(Year(@sd), Month(@sd), 1)
      , le = EOMonth(@sd)
    UNION ALL
    SELECT
        ix = Cast(FORMAT(mos,'yyyyMM') AS int)
      , ls = mos
      , le = EOMonth(mos)
    FROM (SELECT mos = DateAdd(DAY, 1, le) FROM IXPeriod WHERE le < @ed) AS _
  ), ss1 AS (
    SELECT
      company, cd_license, end_dtm, reason_id
    FROM SuspendedService AS ss
    WHERE ss.is_terminate = 1
  ), ss2 AS (
    SELECT ix, ca.*
    FROM IXPeriod
    CROSS APPLY (
      SELECT
        vs.company, vs.cd_license, srv_dis, srv_loc, ss.end_dtm, ss.reason_id
      FROM ss1 AS ss
      JOIN VehicleService AS vs
      ON (ss.cd_license = vs.cd_license)
      WHERE ss.end_dtm >= DateAdd(DAY, -1, ls)
        AND ss.end_dtm <  le
        AND vs.start_dtm <= ss.end_dtm
        AND vs.end_dtm   >= ss.end_dtm
    ) AS ca
  ), vs1 AS (
    SELECT IXP.ix, ca.*
    FROM IXPeriod AS IXP
    CROSS APPLY (
      SELECT
          vs.company, vs.cd_license, vs.srv_dis, vs.srv_loc
        , reg_dtm   = Min(vs.reg_dtm)
        , start_dtm = Max(vs.start_dtm)
        , max_end   = Max(vs.end_dtm)
        , last_term = (
            SELECT Max(end_dtm)
            FROM ss1 AS ss
            WHERE ss.company = vs.company
              AND ss.cd_license = vs.cd_license
              AND ss.end_dtm < Max(vs.start_dtm)
              AND ss.end_dtm > DateAdd(Year, -1, Min(vs.reg_dtm))
          )
        , next_term = (
            SELECT Min(end_dtm)
            FROM ss1 AS ss
            WHERE ss.company = vs.company
              AND ss.cd_license = vs.cd_license
              AND ss.end_dtm > Max(vs.start_dtm)
              AND ss.end_dtm < DateAdd(Month, 3, Min(vs.start_dtm))
          )
        , reason_id = (
            SELECT TOP 1 reason_id
            FROM ss1 AS ss
            WHERE ss.company = vs.company
              AND ss.cd_license = vs.cd_license
              AND ss.end_dtm  < le
              AND ss.end_dtm >= DateAdd(Day, -1, Max(start_dtm))
          )
      FROM VehicleService AS vs
      WHERE start_dtm <= le AND (vs.end_dtm IS NULL OR vs.end_dtm >= ls)
      GROUP BY vs.company, vs.cd_license, vs.srv_dis, vs.srv_loc
    ) AS ca
  ), vs2 AS (
    SELECT
        ix         = IsNull(vs.ix        , ss.ix        )
      , company    = IsNull(vs.company   , ss.company   )
      , cd_license = IsNull(vs.cd_license, ss.cd_license)
      , srv_dis    = IsNull(vs.srv_dis   , ss.srv_dis   )
      , srv_loc    = IsNull(vs.srv_loc   , ss.srv_loc   )
      , reason_id  = IsNull(vs.reason_id , ss.reason_id )
      , is_count   = IIF(vs.cd_license IS NULL, 0, 1)
      , vs.reg_dtm
      , vs.start_dtm
      , vs.max_end
      , vs.last_term
      , vs.next_term
    FROM vs1 AS vs
    FULL JOIN ss2 AS ss
    ON (ss.ix = vs.ix AND ss.cd_license = vs.cd_license)
  ), fact1 AS (
    SELECT
        ix, company, vs.cd_license, srv_dis, srv_loc, source
      , is_count
      , is_new = (CASE
          WHEN last_term IS NULL
            AND next_term IS NULL
            AND ix = Year(reg_dtm)*100+Month(reg_dtm)
          THEN 1
          ELSE 0
        END)
      , is_reu = (CASE
          WHEN last_term IS NOT NULL
            AND next_term IS NULL
            AND ix = Year(start_dtm)*100+Month(start_dtm)
          THEN 1
          ELSE 0
        END)
      , reason_id
    FROM vs2 AS vs
    LEFT JOIN Vehicle AS v
    ON (vs.cd_license = v.cd_license)
  ), fact2 AS (
    SELECT
        ix, company, cd_license, srv_dis, srv_loc
      , is_count
      , is_new_flt  = (CASE WHEN source  = 0 THEN is_new ELSE 0 END)
      , is_new_oth  = (CASE WHEN source <> 0 THEN is_new ELSE 0 END)
      , is_reu
      , is_term_cmp = IIF(reason_id IS NULL, 0, (CASE WHEN reason_id  = 4 THEN 1 ELSE 0 END))
      , is_term_nrm = IIF(reason_id IS NULL, 0, (CASE WHEN reason_id <> 4 THEN 1 ELSE 0 END))
    FROM fact1
  ), rpt1 AS (
    SELECT
        ix, company, srv_dis, srv_loc
      , cnt_total     = SUM(is_count)
      , cnt_new_flt   = SUM(is_new_flt)
      , cnt_new_oth   = SUM(is_new_oth)
      , cnt_reu       = SUM(is_reu)
      , cnt_term_cmp  = SUM(is_term_cmp)
      , cnt_term_nrm  = SUM(is_term_nrm)
      , json_total    = STRING_AGG(CASE WHEN is_count    = 1 THEN cd_license END, '","') WITHIN GROUP (ORDER BY cd_license)
      , json_new_flt  = STRING_AGG(CASE WHEN is_new_flt  = 1 THEN cd_license END, '","') WITHIN GROUP (ORDER BY cd_license)
      , json_new_oth  = STRING_AGG(CASE WHEN is_new_oth  = 1 THEN cd_license END, '","') WITHIN GROUP (ORDER BY cd_license)
      , json_reu      = STRING_AGG(CASE WHEN is_reu      = 1 THEN cd_license END, '","') WITHIN GROUP (ORDER BY cd_license)
      , json_term_cmp = STRING_AGG(CASE WHEN is_term_cmp = 1 THEN cd_license END, '","') WITHIN GROUP (ORDER BY cd_license)
      , json_term_nrm = STRING_AGG(CASE WHEN is_term_nrm = 1 THEN cd_license END, '","') WITHIN GROUP (ORDER BY cd_license)
    FROM fact2 AS fact
    GROUP BY ix, company, srv_dis, srv_loc
  ), rpt2 AS (
    SELECT
        ix, company, srv_dis, srv_loc
      , json_total    = IIF(json_total    IS NULL, NULL, Concat('["', json_total   , '"]'))
      , json_new_flt  = IIF(json_new_flt  IS NULL, NULL, Concat('["', json_new_flt , '"]'))
      , json_new_oth  = IIF(json_new_oth  IS NULL, NULL, Concat('["', json_new_oth , '"]'))
      , json_reu      = IIF(json_reu      IS NULL, NULL, Concat('["', json_reu     , '"]'))
      , json_term_cmp = IIF(json_term_cmp IS NULL, NULL, Concat('["', json_term_cmp, '"]'))
      , json_term_nrm = IIF(json_term_nrm IS NULL, NULL, Concat('["', json_term_nrm, '"]'))
    FROM rpt1
  ), pvtc AS (
    SELECT
      *
    FROM (
      SELECT
          ix, srv_dis, srv_loc, cnt
        , typ = company + '_' + typ
      FROM rpt1
      UNPIVOT (
        cnt FOR typ IN (cnt_total, cnt_new_flt, cnt_new_oth, cnt_reu, cnt_term_cmp, cnt_term_nrm)
      ) AS up
    ) AS _
    PIVOT (
      SUM(cnt) FOR typ IN (
        TK_cnt_total, TK_cnt_new_flt, TK_cnt_new_oth, TK_cnt_reu, TK_cnt_term_cmp, TK_cnt_term_nrm,
        KY_cnt_total, KY_cnt_new_flt, KY_cnt_new_oth, KY_cnt_reu, KY_cnt_term_cmp, KY_cnt_term_nrm,
        PF_cnt_total, PF_cnt_new_flt, PF_cnt_new_oth, PF_cnt_reu, PF_cnt_term_cmp, PF_cnt_term_nrm
      )
    ) AS pv
  ), pvtj AS (
    SELECT
      *
    FROM (
      SELECT
          ix, srv_dis, srv_loc, jsn
        , typ = company + '_' + typ
      FROM rpt2
      UNPIVOT (
        jsn FOR typ IN (json_total, json_new_flt, json_new_oth, json_reu, json_term_cmp, json_term_nrm)
      ) AS up
    ) AS _
    PIVOT (
      Max(jsn) FOR typ IN (
        TK_json_total, TK_json_new_flt, TK_json_new_oth, TK_json_reu, TK_json_term_cmp, TK_json_term_nrm,
        KY_json_total, KY_json_new_flt, KY_json_new_oth, KY_json_reu, KY_json_term_cmp, KY_json_term_nrm,
        PF_json_total, PF_json_new_flt, PF_json_new_oth, PF_json_reu, PF_json_term_cmp, PF_json_term_nrm
      )
    ) AS p
  )
  SELECT
      pvtc.ix, pvtc.srv_dis, pvtc.srv_loc, mgt_dis, cd_fleet
    , loc_name   = Trim(sl.name_zh)
    , TK_Total   = IsNull(TK_cnt_total   , 0)
    , TK_FltNew  = IsNull(TK_cnt_new_flt , 0)
    , TK_OthNew  = IsNull(TK_cnt_new_oth , 0)
    , TK_Reunion = IsNull(TK_cnt_reu     , 0)
    , TK_CmpTerm = IsNull(TK_cnt_term_cmp, 0)
    , TK_NrmTerm = IsNull(TK_cnt_term_nrm, 0)
    , KY_Total   = IsNull(KY_cnt_total   , 0)
    , KY_FltNew  = IsNull(KY_cnt_new_flt , 0)
    , KY_OthNew  = IsNull(KY_cnt_new_oth , 0)
    , KY_Reunion = IsNull(KY_cnt_reu     , 0)
    , KY_CmpTerm = IsNull(KY_cnt_term_cmp, 0)
    , KY_NrmTerm = IsNull(KY_cnt_term_nrm, 0)
    , PF_Total   = IsNull(PF_cnt_total   , 0)
    , PF_FltNew  = IsNull(PF_cnt_new_flt , 0)
    , PF_OthNew  = IsNull(PF_cnt_new_oth , 0)
    , PF_Reunion = IsNull(PF_cnt_reu     , 0)
    , PF_CmpTerm = IsNull(PF_cnt_term_cmp, 0)
    , PF_NrmTerm = IsNull(PF_cnt_term_nrm, 0)
    , json_TK_Total   = TK_json_total
    , json_TK_FltNew  = TK_json_new_flt
    , json_TK_OthNew  = TK_json_new_oth
    , json_TK_Reunion = TK_json_reu
    , json_TK_CmpTerm = TK_json_term_cmp
    , json_TK_NrmTerm = TK_json_term_nrm
    , json_KY_Total   = KY_json_total
    , json_KY_FltNew  = KY_json_new_flt
    , json_KY_OthNew  = KY_json_new_oth
    , json_KY_Reunion = KY_json_reu
    , json_KY_CmpTerm = KY_json_term_cmp
    , json_KY_NrmTerm = KY_json_term_nrm
    , json_PF_Total   = PF_json_total
    , json_PF_FltNew  = PF_json_new_flt
    , json_PF_OthNew  = PF_json_new_oth
    , json_PF_Reunion = PF_json_reu
    , json_PF_CmpTerm = PF_json_term_cmp
    , json_PF_NrmTerm = PF_json_term_nrm
  FROM pvtc
  FULL JOIN pvtj
  ON (pvtc.srv_dis = pvtj.srv_dis AND pvtc.srv_loc = pvtj.srv_loc)
  LEFT JOIN ServiceLocation AS sl
  ON (pvtc.srv_dis = sl.srv_dis AND pvtc.srv_loc = sl.srv_loc)

END
GO

;IF EXISTS (SELECT [name] FROM sys.database_principals WHERE type = N'S' AND [name] = 'tkuat')
  GRANT EXECUTE ON dbo.sp_report_location_count TO tkuat
 ELSE
  GRANT EXECUTE ON dbo.sp_report_location_count TO tkweb
GO
