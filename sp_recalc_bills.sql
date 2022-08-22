

;DROP PROCEDURE IF EXISTS sp_recalc_bills
GO

;CREATE PROCEDURE sp_recalc_bills (
   @p_ix    int
  ,@p_uid   int
  ,@dry_run bit = 0
) AS
BEGIN TRANSACTION
BEGIN TRY

  EXEC sp_recalc_bills__UNSAFE @p_ix, @p_uid, @dry_run

  ;COMMIT
  ;PRINT 'Operation Completed'
END TRY
BEGIN CATCH
  ;ROLLBACK
  ;INSERT INTO AuditError(create_dtm, caller_class, caller_member, msg)
   SELECT GETDATE(), 'STORED_PROCEDURE', 'sp_recalc_bills', ERROR_MESSAGE()
END CATCH
GO

;GRANT EXECUTE ON sp_recalc_bills TO tkweb
GO


