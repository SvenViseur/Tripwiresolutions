DECLARE
  P_NUMBER NUMBER;
  P_RETURN_CODE NUMBER;
  P_RETURN_TXT VARCHAR2(200);
BEGIN
  P_NUMBER := 0;

  SP_DROP_RESTORE_POINT(
    P_NUMBER => P_NUMBER,
    P_RETURN_CODE => P_RETURN_CODE,
    P_RETURN_TXT => P_RETURN_TXT
  );
 
END;
/
exit
