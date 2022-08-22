

;DROP PROCEDURE IF EXISTS sp_recalc_bills__UNSAFE
GO

;CREATE PROCEDURE sp_recalc_bills__UNSAFE (
   @p_ix    int
  ,@p_uid   int
  ,@dry_run bit = 0
) AS
BEGIN

  ;DECLARE @rc         int
  ;DECLARE @batch_dtm  datetime2      = GETDATE()
  ;DECLARE @l_sd       date           = Convert(date, Concat(@p_ix, '01'))
  ;DECLARE @l_ed       date           = EOMonth(@l_sd)

  ;WITH b AS (
     SELECT
       paid = 0, company, ix_yrmo, uid, cd_license, amount, discount, bill_start, bill_end, due_dtm
     FROM Bill WHERE (@p_uid IS NULL OR uid = @p_uid) AND ix_yrmo = @p_ix
     UNION ALL
     SELECT
       paid = 1, company, ix_yrmo, uid, cd_license, amount, discount, bill_start, bill_end, due_dtm
     FROM BillArchive WHERE (@p_uid IS NULL OR uid = @p_uid) AND ix_yrmo = @p_ix
   ), f AS (
     SELECT
       paid = 0, company, ix_yrmo, uid, cd_license, amount, discount=(0), bill_start, bill_end, due_dtm
     FROM fn_calc_bills(@l_sd, @l_ed, @p_uid) AS f
   ), fact AS (
     /* removed services */
     SELECT
       st = -1, paid, b.company, ix_yrmo, b.uid, b.cd_license, b_amount = b.amount, f_amount = 0, discount, bill_start, bill_end, due_dtm
     FROM b
     JOIN (SELECT company, cd_license, uid FROM b EXCEPT SELECT company, cd_license, uid FROM f) AS j1
     ON (b.company = j1.company AND b.cd_license = j1.cd_license AND b.uid = j1.uid)
     UNION ALL
     /* new services */
     SELECT
       st = 1, paid, f.company, ix_yrmo, f.uid, f.cd_license, b_amount = 0, f_amount = f.amount, discount, bill_start, bill_end, due_dtm
     FROM f
     JOIN (SELECT company, cd_license, uid FROM f EXCEPT SELECT company, cd_license, uid FROM b) AS j2
     ON (f.company = j2.company AND f.cd_license = j2.cd_license AND f.uid = j2.uid)
     UNION ALL
     /* changed or same services */
     SELECT
       st = 0, b.paid, f.company, f.ix_yrmo, f.uid, f.cd_license, b_amount = b.amount, f_amount = f.amount, b.discount, f.bill_start, f.bill_end, f.due_dtm
     FROM b JOIN f ON (b.company = f.company AND b.cd_license = f.cd_license AND b.uid = f.uid)
     WHERE b.amount <> f.amount
   )
   SELECT * INTO #tmp FROM fact

  -- check if changes applied
  ;SELECT @rc = @@ROWCOUNT
  ;PRINT Concat(@rc, ' mismatch items found')

  -- execution condition
  ;IF 0 < @rc AND 0 = @dry_run
   BEGIN
    -- Old bill exists, New bill removed
    -- CASE 1: st=-1  paid=0   // invalid bill, remove = OK
    ;DELETE Bill FROM #tmp AS t
     WHERE t.st = -1 AND t.paid = 0
       AND Bill.company    = t.company
       AND Bill.cd_license = t.cd_license
       AND Bill.uid        = t.uid
       AND Bill.ix_yrmo    = @p_ix

    ;SET @rc = @@ROWCOUNT
    ;PRINT Concat('case 1: ', @rc, ' bills deleted')
  
    -- CASE 2: st=-1  paid=1   // invalid bill, need refund
    -- refund
    ;PRINT 'case 2: Refund customer'
    ;UPDATE Customer
     SET balance = balance + sum_refund
     FROM (SELECT uid, sum_refund = SUM(b_amount)
           FROM #tmp WHERE st = -1 AND paid = 1
           GROUP BY uid
           HAVING SUM(b_amount) <> 0
     ) AS _
     WHERE id = _.uid
    
    ;DELETE BillArchive FROM #tmp AS t
     WHERE t.st = -1 AND t.paid = 1
       AND BillArchive.company    = t.company
       AND BillArchive.cd_license = t.cd_license
       AND BillArchive.uid        = t.uid
       AND BillArchive.ix_yrmo    = @p_ix
  
    ;SET @rc = @@ROWCOUNT
    ;PRINT Concat('case 2: ', @rc, ' archived bills deleted')

    -- New bill exists, new service
    -- CASE 3: st= 1  paid=0   // insert to bill table
    ;INSERT INTO Bill (company, ix_yrmo, uid, cd_license, bill_type, create_dtm, amount, discount, bill_start, bill_end, due_dtm)
     SELECT company, ix_yrmo, uid, cd_license, bill_type = 1, @batch_dtm, f_amount, discount, bill_start, bill_end, due_dtm
     FROM #tmp AS t
     WHERE t.st = 1 AND t.paid = 0
  
    ;SET @rc = @@ROWCOUNT
    ;PRINT Concat('case 3: ', @rc, ' bills created')

    -- CASE *: st= 1  paid=1   // imposible case, no virtual bills can be in paid status
    -- **
  
    -- Existing bills, amount can be same or different
    -- CASE 4: st= 0  paid=0  amount same // do nothing
    -- CASE 5: st= 0  paid=1  amount same // do nothing
    -- CASE 6: st= 0  paid=0  amount diff // update amount
    ;UPDATE Bill
     SET amount = f_amount, create_dtm = @batch_dtm, due_dtm = t.due_dtm
     FROM #tmp AS t
     WHERE t.st = 0 AND t.paid = 0
       AND Bill.company    = t.company
       AND Bill.cd_license = t.cd_license
       AND Bill.uid        = t.uid
       AND Bill.ix_yrmo    = @p_ix
    
    ;SET @rc = @@ROWCOUNT
    ;PRINT Concat('case 6: ', @rc, ' bills updated')

    -- CASE 7: st= 0  paid=1  amount diff, new_amount > old_amount // refund all and create new bill
    ;INSERT INTO Bill (company, ix_yrmo, uid, cd_license, bill_type, create_dtm, amount, discount, bill_start, bill_end, due_dtm)
     SELECT company, ix_yrmo, uid, cd_license, bill_type = 1, @batch_dtm, f_amount, discount, bill_start, bill_end, due_dtm
     FROM #tmp AS t
     WHERE t.st = 0 AND t.paid = 1
       AND f_amount > b_amount
  
    ;SET @rc = @@ROWCOUNT
    ;PRINT Concat('case 7: ', @rc, ' bills created for replacement')

    ;DELETE BillArchive FROM #tmp AS t
     WHERE t.st = 0 AND t.paid = 1 AND f_amount > b_amount
       AND BillArchive.company    = t.company
       AND BillArchive.cd_license = t.cd_license
       AND BillArchive.uid        = t.uid
       AND BillArchive.ix_yrmo    = @p_ix

    ;SET @rc = @@ROWCOUNT
    ;PRINT Concat('case 7: ', @rc, ' archived bills created for replacement')

    -- refund
    ;PRINT 'case 7: Refund customer'
    ;UPDATE Customer
     SET balance = balance + sum_refund
     FROM (SELECT uid, sum_refund = SUM(b_amount - discount)
           FROM #tmp WHERE st = 0 AND paid = 1 AND f_amount > b_amount
           GROUP BY uid
           HAVING SUM(b_amount) <> 0
     ) AS _
     WHERE id = _.uid
  
    -- CASE 8: st= 0  paid=1  amount diff, old_amount > new_amount // refund partial and update amount
    ;UPDATE BillArchive
     SET amount = f_amount
     FROM #tmp AS t
     WHERE t.st = 0 AND t.paid = 1 AND f_amount < b_amount
       AND BillArchive.company    = t.company
       AND BillArchive.cd_license = t.cd_license
       AND BillArchive.uid        = t.uid
       AND BillArchive.ix_yrmo    = @p_ix

    ;PRINT Concat('case 8: ', @rc, ' arvhiced bills updated for replacement')
  
    -- refund
    ;PRINT 'case 8: Refund customer'
    ;UPDATE Customer
     SET balance = balance + sum_refund
     FROM (SELECT uid, sum_refund = SUM(b_amount - f_amount)
           FROM #tmp WHERE st = 0 AND paid = 1 AND f_amount < b_amount
           GROUP BY uid
           HAVING SUM(b_amount - f_amount) <> 0
     ) AS _
     WHERE id = _.uid
  
  END -- not dry run

  SELECT * FROM #tmp
END
GO

;GRANT EXECUTE ON sp_recalc_bills__UNSAFE TO tkweb
GO


