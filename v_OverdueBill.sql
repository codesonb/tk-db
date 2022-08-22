
;DROP VIEW IF EXISTS OverdueBill
GO

;CREATE VIEW OverdueBill AS
  WITH ix AS (
    SELECT tsmo  = Year( refdate )*100 + Month( refdate )
         , nxmo  = Year( DateAdd(Month, 1, refdate) )*100 + Month( DateAdd(Month, 1, refdate) )
         , tsmod = refdate
         , nxmod = DateAdd(Month, 1, refdate)
    FROM ( SELECT refdate = (CASE WHEN Day(GetDate()) < 22 THEN DateAdd(Month, -1, GETDATE()) ELSE GETDATE() END) ) AS _
  ), d AS (
    SELECT
        due_lv = DateDiff(Month, DateFromParts(ix_yrmo / 100, ix_yrmo % 100, 1), (SELECT tsmod FROM ix))
      , b.company, b.ix_yrmo, b.uid, b.cd_license, b.bill_type, b.create_dtm, b.amount, b.discount, b.bill_start, b.bill_end, b.due_dtm
      , cust_name = u.display_name, c.is_mobill, c.is_print_bill, c.is_rtn_envelope, c.balance
      , is_whatsapp = IsNull((SELECT TOP 1 1 FROM Contact WHERE uid = u.id AND c_type = 1 /*whataspp*/), 0)
    FROM Bill AS b
    JOIN TKUser AS u ON (b.uid = u.id)
    JOIN Customer AS c ON (b.uid = c.id)
    WHERE (
          ( b.ix_yrmo = ( SELECT nxmo FROM ix ) AND c.is_mobill = 0 )
       OR ( b.ix_yrmo < ( SELECT nxmo FROM ix )                     )
    )
  ), g AS (
    SELECT
        rid = ROW_NUMBER() OVER (PARTITION BY d.company, d.uid, d.cd_license ORDER BY d.bill_end)
      , d.company, d.uid, d.cd_license
      , srv_dis = FIRST_VALUE(vs.srv_dis) OVER (PARTITION BY d.company, d.uid, d.cd_license ORDER BY vs.start_dtm DESC)
      , srv_loc = FIRST_VALUE(vs.srv_loc) OVER (PARTITION BY d.company, d.uid, d.cd_license ORDER BY vs.start_dtm DESC)
      , loc_psn = Trim(CONCAT(
         FIRST_VALUE(vs.srv_floor) OVER (PARTITION BY d.company, d.uid, d.cd_license ORDER BY vs.start_dtm DESC)
        ,' '
        ,FIRST_VALUE(vs.srv_psn) OVER (PARTITION BY d.company, d.uid, d.cd_license ORDER BY vs.start_dtm DESC)
      ))
      , urd = ROW_NUMBER() OVER (PARTITION BY d.uid ORDER BY d.cd_license)
    FROM d
    JOIN VehicleService AS vs
    ON (  d.company    = vs.company
      AND d.cd_license = vs.cd_license
      AND d.uid        = vs.owner_id
    )
    JOIN ServiceLocation AS sl
    ON ( vs.srv_dis = sl.srv_dis AND vs.srv_loc = sl.srv_loc )
  )
  SELECT
      due_lv = Max(CASE WHEN d.due_lv > 2 THEN 2
                     WHEN d.due_lv < 0 THEN 0
                     ELSE d.due_lv
                END) OVER (PARTITION BY d.uid, d.cd_license)
    , d.company, d.ix_yrmo, d.uid, d.cd_license, d.cust_name, d.bill_type, d.create_dtm
    , d.amount, d.discount, d.bill_start, d.bill_end, d.due_dtm
    , d.is_mobill, d.is_print_bill, d.is_rtn_envelope, d.is_whatsapp
    , balance = (CASE WHEN g.urd = MIN(g.urd) OVER (PARTITION BY d.uid) THEN d.balance ELSE 0 END)
    , g.srv_dis, g.srv_loc, sl.mgt_dis
    , g.loc_psn
    , loc_key = Concat(
         g.srv_dis, g.srv_loc
        ,' (', sl.mgt_dis, ')'
        ,' - '
        ,sl.name_zh
      )
  FROM d JOIN g
  ON (  d.company    = g.company
    AND d.uid        = g.uid
    AND d.cd_license = g.cd_license
  )
  JOIN ServiceLocation AS sl
  ON (g.srv_dis = sl.srv_dis AND g.srv_loc = sl.srv_loc)
  WHERE g.rid = 1
  --AND d.amount - d.discount - balance > 0
GO


GRANT SELECT ON OverdueBill TO tkweb
GO
