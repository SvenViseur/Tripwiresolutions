#### ivlremselftest.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# IMPORTANT! The code in this script will only run on TARGET IVL servers,
# not on DeployIT servers (depm/depp/deps). Hence, you CANNOT use
# the DeployIT libraries like global_functions, error or warning log
# functions etc.
#
# This script must be SOURCE'd by the calling script to be able to
# call the functions in this script.
# It must therefore also be transferred to the target system during the
# the deploy process.
#
# All parameters from the calling system (ticket nr, ...) should be
# passed as parameters to functions that are published here. No global
# variables should be used here.
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Mei/2020      # 1.0.0   # initial version
# dexa  # Jun/2020      # 1.0.1   # corr path groovy scripts
# lekri # Aug/2021      # 1.0.2   # zorgen dat connection errors ook RC!=0 geven
#       #               #         #
#       #               #         #
#       #               #         #
#############################################################################
#
ScriptName="ivlremselftest.sh"
ScriptVersion="1.0.2"

DoSelftest() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3

ErrorsFound=0
echo "Test of de logging folder bestaat ..."
if [ ! -d ${LoggingFolder} ]; then
  echo "The logging folder ${LoggingFolder} (derived from"
  echo " DEPLOYIT_IVL_LOGGING_FOLDER in ConfigIT) does not exist!"
  let "ErrorsFound += 1";
else
  echo "Logging folder $LoggingFolder was found."
fi
## try to write a test file in the logging folder
echo "Test of de logging folder beschrijfbaar is ..."
touch "${LoggingFolder}/diagnostics_test_file.log"
RC=$?
if [ $RC -ne 0 ]; then
  echo "The logging folder ${LoggingFolder} is not writeable!"
  let "ErrorsFound += 1";
else
  echo "Logging folder $LoggingFolder is writeable."
  # erase the file again
  rm -f "${LoggingFolder}/diagnostics_test_file.log"
fi
## check presence of the unzip program
echo "Test of het unzip programma aanwezig is ..."
which unzip
RC=$?
if [ $RC -ne 0 ]; then
  echo "The unzip program was not found! It is required to deploy the ODI files."
  let "ErrorsFound += 1";
else
  echo "The program unzip is available."
fi
## check presence of the sqlplus program
echo "Test of het sqlplus programma aanwezig is ..."
which sqlplus
RC=$?
if [ $RC -ne 0 ]; then
  echo "The sqlplus program was not found! It is required to deploy the ODI files."
  let "ErrorsFound += 1";
else
  echo "sqlplus version info:"
  sqlplus -V
fi

## testing SQL access
echo "Test of via sqlplus de database benaderd kan worden ..."
local OraUser="Undef"
## load the credentials
source $TheFld/ivlremcfgoracle.sh
if [ $OraUser = "Undef" ]; then
  echo "De file ivlremcfgoracle.sh kon niet geladen worden met configuratiedata."
  let "ErrorsFound += 1";
else
  echo "Oracle zal benaderd worden met deze user: $OraUser"
  ## Set NLSLANG variable
  NLS_LANG="AMERICAN_AMERICA.AL32UTF8"; export NLS_LANG
  ## make a log folder to capture Oracle outputs
  cd $TheFld
  rm -rf log
  mkdir log
  cd log
sqlplus /nolog <<!EOF
whenever sqlerror exit sql.sqlcode
connect ${OraUser}/${OraPsw}@${OraSrv}
SELECT * FROM DUAL;

!EOF
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "The connection to $OraSrv using the $OraUser credentials did not allow to do a simple select."
    let "ErrorsFound += 1";
  else
    echo "sqlplus connectie naar $OraSrc was succesvol."
  fi
fi

## test ODI using the activesessions script
OdiRTDeployUser="Undef"
## load the credentials
source $TheFld/ivlremcfgodi.sh
if [ $OdiRTDeployUser = "Undef" ]; then
  echo "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"
echo "Alle verdere ODI groovy stappen voor deze server gebruiken deze settings:"
echo "GROOVY_CONF   : $GROOVY_CONF with contents:"
cat $GROOVY_CONF
echo "End of $GROOVY_CONF contents"
if [ "$OdiRTActive" = "YES" ]; then
  echo "ODI RT is actief."
  export ODI_URL="$OdiRTUrl"
  export ODI_USER="$OdiRTDeployUser"
  export ODI_PWD="$OdiRTDeployPsw"
  export ODI_MASTER_USER="$OdiRTMasterUser"
  export ODI_MASTER_PWD="$OdiRTMasterPsw"
  export ODI_WORKREP="WORKREP"
  echo "Test of ODI de actieve sessies kan oplijsten ..."
  groovy $groovy_opts $TheFld/groovy/civl_runningSession.groovy
  if [ $? -ne 0 ]; then
    echo "De ODI omgeving is actief."
  else
    echo "De ODI omgeving is gestopt."
  fi ## RC test on groovy runningSession
  echo "Test of ODI zijn selftest kan doen op de RT omgeving ..."
  groovy $groovy_opts $TheFld/groovy/civl_odi_selftest.groovy
  if [ $? -ne 0 ]; then
    echo "Er waren fouten fouten bij de ODI selftest op de RT omgeving."
    let "ErrorsFound += 1";
  else
    echo "De ODI selftest verliep zonder problemen op de RT omgeving."
  fi ## RC test on groovy cifl_odi_selftest
else
  echo "ODI RT is niet actief."
fi
if [ "$OdiOEMMActive" = "YES" ]; then
  echo "ODI OEMM is actief."
  export ODI_URL="$OdiOEMMUrl"
  export ODI_USER="$OdiOEMMDeployUser"
  export ODI_PWD="$OdiOEMMDeployPsw"
  export ODI_MASTER_USER="$OdiOEMMMasterUser"
  export ODI_MASTER_PWD="$OdiOEMMMasterPsw"
  export ODI_WORKREP="WORKREP"
  echo "Test of ODI zijn selftest kan doen op de OEMM omgeving ..."
  groovy $groovy_opts $TheFld/groovy/civl_odi_selftest.groovy
  if [ $? -ne 0 ]; then
    echo "Er waren fouten fouten bij de ODI selftest op de OEMM omgeving."
    let "ErrorsFound += 1";
  else
    echo "De ODI selftest verliep zonder problemen op de OEMM omgeving."
  fi ## RC test on groovy cifl_odi_selftest
else
  echo "ODI OEMM is niet actief."
fi
echo "Einde van de tests voor deze server/ADC combinatie."

if [ $ErrorsFound -ne 0 ]; then
  echo "Total errors found for this ODI server: $ErrorsFound."
  exit 1
fi
}


