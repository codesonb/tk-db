-- VER 2024 Apr 29

;DROP VIEW IF EXISTS OverdueBill
GO

;CREATE VIEW OverdueBill AS
  WITH ix AS (
    SELECT
        tsmo  = Year( refdate )*100 + Month( refdate )
      , nxmo  = Year( DateAdd(Month, 1, refdate) )*100 + Month( DateAdd(Month, 1, refdate) )
      , tsmod = refdate
      , nxmod = DateAdd(Month, 1, refdate)
    FROM ( SELECT refdate = (CASE WHEN Day(GetDate()) < 22 THEN DateAdd(Month, -1, GETDATE()) ELSE GETDATE() END) ) AS _
  ), d AS (
    SELECT
        d_diff = DateDiff(Month, DateFromParts(ix_yrmo / 100, ix_yrmo % 100, 1), (SELECT tsmod FROM ix))
      , b.company, b.ix_yrmo, b.uid, b.cd_license, b.bill_type, b.create_dtm, b.amount, b.discount, b.bill_start, b.bill_end, b.due_dtm
      , cust_name = u.display_name, c.is_mobill, c.is_print_bill, c.is_rtn_envelope, c.balance
      , is_whatsapp = CAST(CASE (SELECT TOP 1 1 FROM Contact WHERE uid = u.id AND c_type = 1 /*whataspp*/) WHEN 1 THEN 1 ELSE 0 END AS BIT)
      , is_email    = CAST(CASE (SELECT TOP 1 1 FROM Contact WHERE uid = u.id AND c_type = 2 /*email   */) WHEN 1 THEN 1 ELSE 0 END AS BIT)
      , is_mail     = CAST(CASE (SELECT TOP 1 1 FROM Contact WHERE uid = u.id AND c_type = 3 /*mail    */) WHEN 1 THEN 1 ELSE 0 END AS BIT)
      , is_fax      = CAST(CASE (SELECT TOP 1 1 FROM Contact WHERE uid = u.id AND c_type = 4 /*fax     */) WHEN 1 THEN 1 ELSE 0 END AS BIT)
-- @@ BillWhatsApp = 1, BillEmail = 2, BillAddress = 3, Tel = 10, Mobile = 11, Fax = 12, EMail = 13, Address = 20
    FROM Bill AS b
    JOIN TKUser AS u ON (b.uid = u.id)
    JOIN Customer AS c ON (b.uid = c.id)
    WHERE (
           ( b.ix_yrmo = ( SELECT nxmo FROM ix ) AND c.is_mobill = 0 )
        OR ( b.ix_yrmo < ( SELECT nxmo FROM ix )                     )
    )
    -- due_dtm < DateAdd(MONTH, 2, DateFromParts(Year(GETDATE()), Month(GETDATE()), 1))
    -- ** due_dtm is useless due to client's requirement

  ), DueLevel AS (
    SELECT m.uid, m.cd_license, due_lv = (
      CASE
        WHEN max_diff > 2 THEN 2
        WHEN max_diff < 0 THEN 0
        ELSE max_diff -- 0 or 1
      END)
    FROM (
      SELECT
        d.uid, d.cd_license, max_diff = MAX(d_diff)
      FROM d
      GROUP BY d.uid, d.cd_license
    ) AS m
  ), g AS (
    SELECT
      due_lv, company, ix_yrmo, d.uid, d.cd_license,
      bill_type, create_dtm, amount, discount, bill_start, bill_end,
      due_dtm, cust_name, is_mobill, is_print_bill, is_rtn_envelope, balance,
      is_whatsapp, is_email, is_mail, is_fax
    FROM d
    LEFT JOIN DueLevel AS dl
    ON (d.cd_license = dl.cd_license AND d.uid = dl.uid)
  )
  SELECT
      g.*, ca.*, sl.mgt_dis
    , loc_key = Concat(ca.srv_dis, ca.srv_loc,' (', sl.mgt_dis, ')', ' - ',sl.name_zh)
    , cvc
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
  JOIN (
    SELECT
      uid, cvc = COUNT(DISTINCT cd_license)
    FROM g
    GROUP BY uid
  ) AS vh
  ON (g.uid = vh.uid)
GO


;IF EXISTS (SELECT [name] FROM sys.database_principals WHERE type = N'S' AND [name] = 'tkuat')
  GRANT SELECT ON dbo.OverdueBill TO tkuat
 ELSE
  GRANT SELECT ON dbo.OverdueBill TO tkweb
GO
