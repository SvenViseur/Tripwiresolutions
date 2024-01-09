#### ivlremtestsql.sh script
# This script is to be source'd from a Jenkins AutoDeploy job.
#
# IMPORTANT! The code in this script will only run on TARGET IVL servers,
# not on DeployIT servers (depm/depp/deps).
#
# !!! !!! !!! VERY IMPORTANT!!!  VERY IMPORTANT!!!  VERY IMPORTANT!!! !!! !!! !!!
# !!! The code in this file is only meant to TEST the SQL code of             !!!
# !!! a deployment. Hence, it will only be executed on the target system      !!!
# !!! when the deploy targets the correct environment. This is managed using  !!!
# !!! the DoTestSql flag. Environments that do not have TEST SQL should NOT   !!!
# !!! have this piece of code                                                 !!!
# !!! !!! !!! VERY IMPORTANT!!!  VERY IMPORTANT!!!  VERY IMPORTANT!!! !!! !!! !!!
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Dec/2019      # 1.0.0   # initial version
# dexa  # Feb/2019      # 1.1.0   # Added flashback
# dexa  # Feb/2019      # 1.2.0   # Aparte user voor RestorePoint en voor SQL
# lekri # Aug/2021      # 1.2.1   # zorgen dat connection errors ook RC!=0 geven
#############################################################################

## benodigde libraries: deploy_slverrorwarns.sh moet geladen zijn

echo "uitvoering gevraagd van ivlremtestsql.sh."

IsConfigITTestSqlActive() {
local DeployITDoTestDdl="@@DEPLOYIT_DO_TEST_DDL#@"

[ "$DeployITDoTestDdl" = "YES" ]
return  ## this returns the result of the above test
}

DoIvlCreateRestorePoint() {
local OraTestRPUser="@@DEPLOYIT_IVL_ORACLE_TEST_RP_USER#@"
local OraTestRPPsw="@@DEPLOYIT_IVL_ORACLE_TEST_RP_PSW#@"
local OraTestRPSrv="@@DEPLOYIT_IVL_ORACLE_TEST_RP_SERVER#@"
local TimeOutMin=15  ## timeout value in minutes
## make a log folder to capture Oracle outputs
cd $TheFld
rm -rf log
mkdir log
cd log
sqlplus /nolog <<!EOF
whenever sqlerror exit sql.sqlcode
connect ${OraTestRPUser}/${OraTestRPPsw}@${OraTestRPSrv}
SET SERVEROUTPUT ON
DECLARE
    p_number        NUMBER;
    p_loper         NUMBER;
    p_return_code   NUMBER;
    p_return_txt    VARCHAR2(200);
    v_eye           NUMBER := 1;
    v_prev_date     DATE;
    v_main_date     DATE;
    v_date          VARCHAR2(20);

BEGIN
    p_number := 0;
    p_loper := 1;
    v_main_date := sysdate;
    WHILE ( p_loper > 0 AND v_main_date > (sysdate - interval '$TimeOutMin' MINUTE))  LOOP
        c##ivl_admin.sp_create_restore_point(p_number => p_number,p_return_code => p_return_code,p_return_txt => p_return_txt);
        dbms_output.put_line(p_return_code);
        p_loper := p_return_code;
        dbms_output.put_line(p_loper);
        IF ( p_loper > 0 ) THEN
            v_prev_date := SYSDATE;
            WHILE SYSDATE <= v_prev_date + INTERVAL '5' SECOND LOOP
                v_eye := 1;
            END LOOP;
        ELSE
            dbms_output.put_line(p_return_txt || ' - ' || to_char((sysdate - v_main_date)*1440*60, '99999999'));
        END IF;
    END LOOP;
    IF p_loper > 0
    THEN
        raise_application_error(-20000, 'Create restore point failed - ' || to_char((sysdate - v_main_date)*1440*60, '99999999'));
    END IF;
END;

/
EXIT
!EOF

RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR in CREATE_RESTORE_POINT sqlplus execution: RC=$RC. See in the above log for details." >> $LogFile
  echo "ERROR in CREATE_RESTORE_POINT sqlplus execution: RC=$RC. See log for details."
  ivl_slv_exit $DPLERRSLV_IVL_CreateRPError
fi
echo "Call to DoIvlCreateRestorePoint ended."
}

DoIvlDropRestorePoint() {
local OraTestRPUser="@@DEPLOYIT_IVL_ORACLE_TEST_RP_USER#@"
local OraTestRPPsw="@@DEPLOYIT_IVL_ORACLE_TEST_RP_PSW#@"
local OraTestRPSrv="@@DEPLOYIT_IVL_ORACLE_TEST_RP_SERVER#@"
## make a log folder to capture Oracle outputs
cd $TheFld
rm -rf log
mkdir log
cd log
sqlplus /nolog <<!EOF
whenever sqlerror exit sql.sqlcode
connect ${OraTestRPUser}/${OraTestRPPsw}@${OraTestRPSrv}
SET SERVEROUTPUT ON
DECLARE
  P_NUMBER NUMBER;
  P_RETURN_CODE NUMBER;
  P_RETURN_TXT VARCHAR2(200);
BEGIN
  P_NUMBER := 0;

  C##IVL_ADMIN.SP_DROP_RESTORE_POINT(
    P_NUMBER => P_NUMBER,
    P_RETURN_CODE => P_RETURN_CODE,
    P_RETURN_TXT => P_RETURN_TXT
  );

  dbms_output.put_line(p_return_code || ' - ' || p_return_txt);

EXCEPTION
WHEN OTHERS THEN
  raise_application_error(P_RETURN_CODE, p_return_txt);

END;
/
exit
!EOF

RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR in DROP_RESTORE_POINT sqlplus execution: RC=$RC. See in the above log for details." >> $LogFile
  echo "ERROR in DROP_RESTORE_POINT sqlplus execution: RC=$RC. See log for details."
  exit 16
fi
echo "Call to DoIvlDropRestorePoint ended."
}

DoIvlFlashbackToRestorePoint() {
local OraTestRPUser="@@DEPLOYIT_IVL_ORACLE_TEST_RP_USER#@"
local OraTestRPPsw="@@DEPLOYIT_IVL_ORACLE_TEST_RP_PSW#@"
local OraTestRPSrv="@@DEPLOYIT_IVL_ORACLE_TEST_RP_SERVER#@"
## make a log folder to capture Oracle outputs
cd $TheFld
rm -rf log
mkdir log
cd log
sqlplus /nolog <<!EOF
whenever sqlerror exit sql.sqlcode
connect ${OraTestRPUser}/${OraTestRPPsw}@${OraTestRPSrv}
SET SERVEROUTPUT ON

DECLARE
  P_NUMBER NUMBER;
  P_RETURN_CODE NUMBER;
  P_RETURN_TXT VARCHAR2(200);
BEGIN
  P_NUMBER := 0;

  C##IVL_ADMIN.SP_FLASHBACK_TO_RESTORE_POINT(
    P_NUMBER => P_NUMBER,
    P_RETURN_CODE => P_RETURN_CODE,
    P_RETURN_TXT => P_RETURN_TXT
  );
  dbms_output.put_line(p_return_code || ' - ' || p_return_txt);

  C##IVL_ADMIN.SP_DROP_RESTORE_POINT(
    P_NUMBER => P_NUMBER,
    P_RETURN_CODE => P_RETURN_CODE,
    P_RETURN_TXT => P_RETURN_TXT
  );


  dbms_output.put_line(p_return_code || ' - ' || p_return_txt);

EXCEPTION
WHEN OTHERS THEN
  raise_application_error(-20000, sqlerrm);

END;
/
exit
!EOF

RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR in FLASHBACK_TO_RESTORE_POINT sqlplus execution: RC=$RC. See in the above log for details." >> $LogFile
  echo "ERROR in FLASHBACK_TO_RESTORE_POINT sqlplus execution: RC=$RC. See log for details."
  ivl_slv_exit $DPLERRSLV_IVL_FlashRPError
fi
echo "Call to DoIvlFlashbackToRestorePoint ended."
}

DoIvlTestOneSql() {
local LogFile=$1
local SqlFolder=$2
local MainSQL=$3
local TheFld=$4
local DebugLevel=$5

local OraTestUser="@@DEPLOYIT_IVL_ORACLE_TEST_USER#@"
local OraTestPsw="@@DEPLOYIT_IVL_ORACLE_TEST_PSW#@"
local OraTestSrv="@@DEPLOYIT_IVL_ORACLE_TEST_SERVER#@"

## make a log folder to capture Oracle outputs
cd $TheFld
rm -rf test1log
mkdir test1log
cd test1log
SQLPATH=${sqlfolder} sqlplus /nolog <<!EOF
whenever sqlerror exit sql.sqlcode
connect ${OraTestUser}/${OraTestPsw}@${OraTestSrv}
@$mainsql
!EOF

RC=$?

if [ $RC -ne 0 ]; then
  echo "output folder contents:" >> $LogFile
  ls -l >> $LogFile
  echo "sending all that output to the log file ..." >> $LogFile
  cat * >> $LogFile
  echo "end of SQLPlus output files." >> $LogFile
  echo "ERROR in sqlplus execution: RC=$RC. See in the above log for details." >> $LogFile
  echo "ERROR in sqlplus execution: RC=$RC. See log for details."
  ## Er was een fout in test 1: flashback naar restore point!
  DoIvlFlashbackToRestorePoint
  echo "FLASHBACK is uitgevoerd. Einde van de test DDL!"
  ivl_slv_exit $DPLERRSLV_IVL_TestDDL1Error
fi

if [ $DebugLevel -gt 3 ]; then
  echo "output folder contents:" >> $LogFile
  ls -l >> $LogFile
  echo "sending all that output to the log file ..." >> $LogFile
  cat * >> $LogFile
  echo "end of SQLPlus output files." >> $LogFile
fi

## test1 is goed gebeurd. Kuis de log folder op
cd $TheFld
rm -rf test1log

## Probeer een tweede uitvoering
## make a log folder to capture Oracle outputs
cd $TheFld
rm -rf test2log
mkdir test2log
cd test2log
SQLPATH=${sqlfolder} sqlplus /nolog <<!EOF
whenever sqlerror exit sql.sqlcode
connect ${OraTestUser}/${OraTestPsw}@${OraTestSrv}
@$mainsql
!EOF

RC=$?

if [ $RC -ne 0 ]; then
  echo "output folder contents for the SECOND execution of the DDL code:" >> $LogFile
  ls -l >> $LogFile
  echo "sending all that output to the log file ..." >> $LogFile
  cat * >> $LogFile
  echo "end of SQLPlus output files." >> $LogFile
  echo "ERROR in sqlplus execution of SECOND run of DDL code: RC=$RC. See in the above log for details." >> $LogFile
  echo "ERROR in sqlplus execution of SECOND run of DDL code: RC=$RC. See log for details."
  ## Er was een fout in test 2: flashback naar restore point!
  DoIvlFlashbackToRestorePoint
  echo "FLASHBACK is uitgevoerd wegens fouten in 2de uitvoering van DDL code. Einde van de test DDL!"
  ivl_slv_exit $DPLERRSLV_IVL_TestDDL2Error
fi
  echo "Call to DoIvlTestOneSql ended OK for this SQL."
}


