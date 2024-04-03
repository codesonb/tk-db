-- VER 2024 Apr 2

;DROP VIEW IF EXISTS OverdueBill
GO

;CREATE VIEW OverdueBill AS
  WITH ix AS (
    SELECT  tsmo  = Year( refdate )*100 + Month( refdate )
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
        due_lv = CASE WHEN d.due_lv > 2 THEN 2
                      WHEN d.due_lv < 0 THEN 0
                      ELSE d.due_lv
                END,
        company, ix_yrmo, uid, cd_license,
        bill_type, create_dtm, amount, discount, bill_start, bill_end,
        due_dtm, cust_name, is_mobill, is_print_bill, is_rtn_envelope, balance, is_whatsapp
    FROM d
  )
  SELECT
      g.*, ca.*, sl.mgt_dis
    , loc_key = Concat(ca.srv_dis, ca.srv_loc,' (', sl.mgt_dis, ')', ' - ',sl.name_zh)
  FROM g
  CROSS APPLY (
    SELECT TOP 1
        srv_dis, srv_loc, srv_plan
      , loc_psn = Trim(CONCAT(vs.srv_floor, ' ', vs.srv_psn))
    FROM VehicleService AS vs
    WHERE vs.owner_id   = g.uid
      AND vs.cd_license = g.cd_license
    ORDER BY start_dtm DESC
  ) AS ca
  JOIN ServiceLocation AS sl
  ON (ca.srv_dis = sl.srv_dis AND ca.srv_loc = sl.srv_loc)
GO


;IF EXISTS (SELECT [name] FROM sys.database_principals WHERE type = N'S' AND [name] = 'tkuat')
  GRANT SELECT ON dbo.OverdueBill TO tkuat
 ELSE
  GRANT SELECT ON dbo.OverdueBill TO tkweb
GO
