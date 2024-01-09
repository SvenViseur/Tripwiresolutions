#### ivlreminst.sh script
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
# dexa  # Dec/2019      # 1.0.0   # initial version based on code from
#       #               #         # Sven Viseur
# dexa  # Dec/2019      # 1.0.1   # added NLS_LANG to SQL section
# dexa  # Dec/2019      # 1.0.2   # work on ODI part
# dexa  # Jan/2020      # 1.0.3   # added optional verbosity on ODI part
# dexa  # Jan/2020      # 1.0.4   # added LP_ and OEMM specific deploy steps
# dexa  # Jan/2020      # 1.0.5   # added extra debugging info on progress
# dexa  # Jan/2020      # 1.0.6   # added fct DoIvlCheckStop
# dexa  # Feb/2020      # 1.0.7   # mod fct DoIvlCheckStop: test CheckEnvDown
# dexa  # Feb/2020      # 1.0.8   # chg opt -n naar -f voor DeployArchive
# dexa  # Feb/2020      # 1.0.9   # added topology code, check_release and
#       #               #         # movingscenarios
# dexa  # Feb/2020      # 1.1.0   # Zelfs als SQL_ACTIVE uit staat, kan ODI
#       #               #         # nog deployen (voor SIC)
# dexa  # Feb/2020      # 1.1.1   # ConfigIT can disable test SQL
# dexa  # Feb/2020      # 1.1.2   # Added TS logging via DualEchoTS
# dexa  # Maa/2020      # 1.2.0   # Force delete voor de ODI deploy
#       #               #         # Added logging to tables
# dexa  # Apr/2020      # 1.2.1   # Minor corr to fetch SqlActive flag
# lekri # Aug/2021      # 1.2.2   # zorgen dat connection errors ook RC!=0 geven
#       #               #         #
#       #               #         #
#############################################################################
#
ScriptName="ivlreminst.sh"
ScriptVersion="1.2.2"
TheLogFile=""

# Required other scripts (to be sourced by calling scripts):
# deploy_slverrorwarns.sh

## set the base error value so that you can call slv_exit:
DPLERR_BASE=$DPLERRSLV_IVL_Base

## The values used in the below functions are loaded via a call to the
## ivlremcfgodi.sh routine. The contents of that file is dynamically built
## using placeholders and ConfigIT.
getRTSettings() {
export ODI_URL="$OdiRTUrl"
export ODI_USER="$OdiRTDeployUser"
export ODI_PWD="$OdiRTDeployPsw"
export ODI_MASTER_USER="$OdiRTMasterUser"
export ODI_MASTER_PWD="$OdiRTMasterPsw"
export ODI_WORKREP="WORKREP"
}

getOEMMSettings() {
export ODI_URL="$OdiOEMMUrl"
export ODI_USER="$OdiOEMMDeployUser"
export ODI_PWD="$OdiOEMMDeployPsw"
export ODI_MASTER_USER="$OdiOEMMMasterUser"
export ODI_MASTER_PWD="$OdiOEMMMasterPsw"
export ODI_WORKREP="WORKREP"
}

ClearEngineSettings() {
export ODI_URL="None selected"
export ODI_USER="No_User"
export ODI_PWD="No_Password"
export ODI_MASTER_USER="No_User"
export ODI_MASTER_PWD="No_Password"
export ODI_WORKREP="No_Repo"
}

DualEcho() {
  echo "$1"
  echo "$1" >> $TheLogFile
}

DualEchoTS() {
  CurTS=$(date)
  echo "$CurTS $1"
  echo "$CurTS $1" >> $TheLogFile
}


DoLogToDB_Start() {
## This function will log a bunch of data to some logging tables via groovy scripts.
local LogFile=$1
local TheFld=$2
local TheEnv=$3
local ZipFolder=$4
local TicketNr=$5
local JenkinsBuildNr=$6
local JenkinsBuildURL=$7
local DebugLevel=$8
TheLogFile=$LogFile

OdiLogDbUser="Undef"
## load the credentials
source $TheFld/psw/ivlremcfgodi.sh
if [ $OdiLogDbUser = "Undef" ]; then
  DualEcho "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
export RMC_DB_URL="$OdiLogDbUrl"
export RMC_DB_USER="$OdiLogDbUser"
export RMC_DB_PASSWORD="$OdiLogDbPsw"

declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"

cd ${ZipFolder}/unzipped
groovy $groovy_opts $TheFld/groovy/civl_register_properties.groovy -f parameters/*.properties -t ${TicketNr} -r ${JenkinsBuildNr}
RC=$?
if [ $DebugLevel -gt 3 ]; then
  echo "RC of civl_register_properties.groovy: $RC"
fi
if [ -f "parameters/ODI_execution_order.txt" ]; then
  ## Parse the execution order line by line
  while read -r line; do
    odifolder="odi/${line}"
    groovy $groovy_opts $TheFld/groovy/civl_register_odi.groovy -fh ${odifolder}/${line}.odiinfo  -fd ${odifolder}/${line}.detailodiinfo  -t ${TicketNr} -r ${JenkinsBuildNr}
    RC=$?
    if [ $DebugLevel -gt 3 ]; then
      echo "RC of civl_register_odi.groovy: $RC"
    fi
  done < "parameters/ODI_execution_order.txt"
fi
if [ -f "parameters/DDL_execution_order.txt" ]; then
  ## Parse the execution order line by line
  while read -r line; do
    sqlfolder="sql/${line}"
    groovy $groovy_opts $TheFld/groovy/civl_register_sql.groovy -fd ${sqlfolder}/${line}.sqldetailinfo  -t ${TicketNr} -r ${JenkinsBuildNr}
    RC=$?
    if [ $DebugLevel -gt 3 ]; then
      echo "RC of civl_register_sql.groovy: $RC"
    fi
  done < "parameters/DDL_execution_order.txt"
fi
groovy $groovy_opts $TheFld/groovy/civl_register_deploy.groovy -f parameters/*.properties -t ${TicketNr} -e ${TheEnv} -s START -r ${JenkinsBuildNr} -u ${JenkinsBuildURL}
RC=$?
if [ $DebugLevel -gt 3 ]; then
  echo "RC of civl_register_deploy.groovy: $RC"
fi

## erase credentials from env settings
export RMC_DB_URL="Not specified"
export RMC_DB_USER="No user"
export RMC_DB_PASSWORD="No password"
}

DoLogToDB_EndOK() {
## This function will log a bunch of data to some logging tables via groovy scripts.
local LogFile=$1
local TheFld=$2
local TheEnv=$3
local ZipFolder=$4
local TicketNr=$5
local JenkinsBuildNr=$6
local JenkinsBuildURL=$7
local DebugLevel=$8
TheLogFile=$LogFile

OdiLogDbUser="Undef"
## load the credentials
source $TheFld/psw/ivlremcfgodi.sh
if [ $OdiLogDbUser = "Undef" ]; then
  DualEcho "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
export RMC_DB_URL="$OdiLogDbUrl"
export RMC_DB_USER="$OdiLogDbUser"
export RMC_DB_PASSWORD="$OdiLogDbPsw"

declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"

cd ${ZipFolder}/unzipped
groovy $groovy_opts $TheFld/groovy/civl_register_deploy.groovy -f parameters/*.properties -t ${TicketNr} -e ${TheEnv} -s "END" -r ${JenkinsBuildNr} -u ${JenkinsBuildURL}
RC=$?
if [ $DebugLevel -gt 3 ]; then
  echo "RC of civl_register_deploy.groovy: $RC"
fi

## erase credentials from env settings
export RMC_DB_URL="Not specified"
export RMC_DB_USER="No user"
export RMC_DB_PASSWORD="No password"
}

DoLogToDB_EndNOK() {
## This function will log a bunch of data to some logging tables via groovy scripts.
local LogFile=$1
local TheFld=$2
local TheEnv=$3
local ZipFolder=$4
local TicketNr=$5
local JenkinsBuildNr=$6
local JenkinsBuildURL=$7
local errorcode=$8
local DebugLevel=$9
TheLogFile=$LogFile

OdiLogDbUser="Undef"
## load the credentials
source $TheFld/psw/ivlremcfgodi.sh
if [ $OdiLogDbUser = "Undef" ]; then
  DualEcho "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
export RMC_DB_URL="$OdiLogDbUrl"
export RMC_DB_USER="$OdiLogDbUser"
export RMC_DB_PASSWORD="$OdiLogDbPsw"

declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"

cd ${ZipFolder}/unzipped
groovy $groovy_opts $TheFld/groovy/civl_register_deploy.groovy -f parameters/*.properties -t ${TicketNr} -e ${TheEnv} -s "END WITH FAIL" -r ${JenkinsBuildNr} -u ${JenkinsBuildURL} -m "$errorcode"
RC=$?
if [ $DebugLevel -gt 3 ]; then
  echo "RC of civl_register_deploy.groovy: $RC"
fi

## erase credentials from env settings
export RMC_DB_URL="Not specified"
export RMC_DB_USER="No user"
export RMC_DB_PASSWORD="No password"
}


DoIvlCheckStop() {
## This function will first examine whether the required IVL should be stopped.
## If it should be, it will perform the stop check. If that fails, an error will
## be returned and the deploy will abort.
local LogFile=$1
local ZipFolder=$2
local TheFld=$3
local DebugLevel=$4
TheLogFile=$LogFile
cd $ZipFolder
cd unzipped/parameters
if [ ! -f *.properties ]; then
  DualEcho "Er is geen .properties file om vast te stellen of een Stop_Env nodig is."
  exit 16
fi
declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"
grep "BLDR_Stop_Env=Y" *.properties
if [ $? -eq 0 ]; then
  OdiRTDeployUser="Undef"
  ## load the credentials
  source $TheFld/psw/ivlremcfgodi.sh
  if [ $OdiRTDeployUser = "Undef" ]; then
    DualEcho "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
    exit 16
  fi
  if [ $CheckEnvDown = "NO" ]; then
    if [ $DebugLevel -gt 3 ]; then
      DualEcho "De ConfigIT flag DEPLOYIT_IVL_CHECK_ENV_DOWN staat op NO, zodat er geen check moet gebeuren."
    fi
  else
    getRTSettings
    ## We moeten nu testen of de IVL effectief niet actief is
    groovy $groovy_opts $TheFld/groovy/civl_runningSession.groovy
    if [ $? -ne 0 ]; then
      DualEcho "Er is een .properties file die eist dat de IVL omgeving gestopt is (Stop_Env=Y), maar de omgeving is nog actief."
      ivl_slv_exit $DPLERRSLV_IVL_EnvNotStopped
    else
      if [ $DebugLevel -gt 3 ]; then
        DualEcho "Er is een Stop_Env=Y gevonden in een .properties file, en de omgeving is inderdaad gestopt."
      fi
    fi ## RC test on groovy runningSession
  fi  ## if CheckEnvDown
else
  if [ $DebugLevel -gt 3 ]; then
    DualEcho "Er is geen Stop_Env=Y gevonden in enige .properties file, dus een stop is NIET nodig."
  fi
fi ## RC on grep BLDR_Stop_Env
}

DoIvlOneSql() {
local LogFile=$1
local SqlFolder=$2
local MainSQL=$3
local TheFld=$4
local DebugLevel=$5
TheLogFile=$LogFile

DualEcho "DoIvlOneSql functie gestart voor folder ${SqlFolder}"
local OraUser="Undef"
## load the credentials
source $TheFld/psw/ivlremcfgoracle.sh
if [ $OraUser = "Undef" ]; then
  DualEcho "De file ivlremcfgoracle.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
if [ $DebugLevel -gt 3 ]; then
  DualEcho "Oracle zal benaderd worden met deze user: $OraUser"
fi
## Set NLSLANG variable
NLS_LANG="AMERICAN_AMERICA.AL32UTF8"; export NLS_LANG
## make a log folder to capture Oracle outputs
cd $TheFld
rm -rf log
mkdir log
cd log
SQLPATH=${sqlfolder} sqlplus /nolog <<!EOF
whenever sqlerror exit sql.sqlcode
connect ${OraUser}/${OraPsw}@${OraSrv}
@$mainsql
!EOF

RC=$?
echo "output folder contents:" >> $LogFile
ls -l >> $LogFile
echo "sending all that output to the log file ..." >> $LogFile
ls -1tr | xargs cat >> $LogFile
echo "end of SQLPlus output files." >> $LogFile
if [ $RC -ne 0 ]; then
  DualEcho "ERROR in sqlplus execution: RC=$RC. See in the above log for details."
  ivl_slv_exit $DPLERRSLV_IVL_DDLError
fi
if [ $DebugLevel -gt 3 ]; then
  DualEcho "DDL uitvoering eindigde goed."
fi
}

DoIvlOneOdi() {
local LogFile=$1
local OdiFolder=$2
local OdiSet=$3
local TheFld=$4
local DebugLevel=$5
TheLogFile=$LogFile

DualEcho "DoIvlOneOdi functie gestart voor folder ${OdiFolder}"
OdiRTDeployUser="Undef"
## load the credentials
source $TheFld/psw/ivlremcfgodi.sh
if [ $OdiRTDeployUser = "Undef" ]; then
  DualEcho "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
if [ $DebugLevel -gt 3 ]; then
  DualEcho "ODI deploy gestart voor project ${OdiProject}."
fi
### GROOVY_HOME="$TheFld/groovy"; export GROOVY_HOME
declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"
if [ $DebugLevel -gt 3 ]; then
  echo "Alle verdere ODI groovy stappen voor deze ${OdiSet} deploy gebruiken deze settings:"
  echo "GROOVY_CONF   : $GROOVY_CONF with contents:"
  cat $GROOVY_CONF
  echo "End of $GROOVY_CONF contents"
fi
## test of we wel een RT deploy moeten doen
if [ "$OdiRTActive" = "YES" ]; then
  if [ $DebugLevel -gt 3 ]; then
    echo "ODI RT is actief."
    echo "ODI RT is actief." >> $LogFile
  fi
  ## Stap 0: laad de juiste settings
  getRTSettings
  ## Stap 1: uitrol topology op RT engine
  cd $OdiFolder
  ## test if TOPOLOGY_ to deploy
  local TopoZip="TOPOLOGY_${OdiSet}.zip"
  if [ -e "${TopoZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van TOPOLOGY set naar de RT engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_applyTopology.groovy"
      echo "Topo zip file : ${TopoZip}"
      echo "ODI_URL       : $ODI_URL"
    fi
    DualEchoTS "Start applyTopology on RT"
    groovy $groovy_opts $TheFld/groovy/civl_applyTopology.groovy -f ${TopoZip}
    if [ $? -ne 0 ]; then
      # Stap 2: The deploy failed. Retry it with first the removeObjectsFromRepo script
      DualEchoTS "End applyTopology on RT"
      echo "De topology archive ${TopoZip} kon niet geladen worden in de Run time omgeving. Deploy is gefaald."
      echo "De topology archive ${TopoZip} kon niet geladen worden in de Run time omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_TopoZipRTError
    fi
    DualEchoTS "End applyTopology on RT"
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar RT: geen TOPOLOGY ZIP bestand gevonden."
      echo "ODI deploy naar RT: geen TOPOLOGY ZIP bestand gevonden." >> $LogFile
    fi
  fi ##test -e TopoZip
  ## Stap 3: DeployArchive van de EXEC naar de RT engine
  cd $OdiFolder
  ## test if EXEC_ to deploy
  local OdiZip="EXEC_${OdiSet}.zip"
  if [ -e "${OdiZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van EXEC set naar de RT engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_applyDeployArchive.groovy"
      echo "ODI zip file  : ${OdiZip}"
      echo "ODI_URL       : $ODI_URL"
    fi
    DualEchoTS "Start removeObjectsFromRepo on RT"
    groovy $groovy_opts $TheFld/groovy/civl_removeObjectsFromRepo.groovy -f ${OdiZip} -p ${OdiProject}
    DualEchoTS "End removeObjectsFromRepo on RT"
    # stap 5: try it again
    DualEchoTS "Start applyDeployArchive on RT"
    groovy $groovy_opts $TheFld/groovy/civl_applyDeployArchive.groovy -f ${OdiZip}
    if [ $? -ne 0 ]; then
      # stap 6: It still fails. Report the error
      DualEchoTS "End applyDeployArchive on RT"
      echo "De archive ${OdiZip} kon niet geladen worden in de Run time omgeving. Deploy is gefaald."
      echo "De archive ${OdiZip} kon niet geladen worden in de Run time omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_EXECRTError
    fi
    DualEchoTS "End applyDeployArchive on RT"
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar RT: geen EXEC bestand gevonden."
      echo "ODI deploy naar RT: geen EXEC bestand gevonden." >> $LogFile
    fi
  fi ##test -e OdiZip on EXEC
  ##stap 7: LoadPlans opladen op RT
  local OdiZip="LP_${OdiSet}.zip"
  if [ -e "${OdiZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van LOAD PLAN set naar de RT engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_importLoadplans.groovy"
      echo "ODI zip file  : ${OdiZip}"
      echo "ODI_URL       : $ODI_URL"
    fi
    mkdir -p ${TheFld}/tmp/LOADPLANS
    unzip ${OdiZip} -d ${TheFld}/tmp/LOADPLANS
    if [ $DebugLevel -gt 3 ]; then
      echo "Contents of the zip file:"
      ls -l ${TheFld}/tmp/LOADPLANS
    fi
    DualEchoTS "Start importLoadplans on RT"
    groovy $groovy_opts $TheFld/groovy/civl_importLoadplans.groovy -d ${TheFld}/tmp/LOADPLANS
    if [ $? -ne 0 ]; then
      # Stap 8: LP load fails. Report the error
      DualEchoTS "End importLoadplans on RT"
      echo "De Loadplan archive ${OdiZip} kon niet geladen worden in de Run time omgeving. Deploy is gefaald."
      echo "De Loadplan archive ${OdiZip} kon niet geladen worden in de Run time omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_LPRTError
    fi
    DualEchoTS "End importLoadplans on RT"
    ## clean up the LOADPLANS folder
    rm -rf ${TheFld}/tmp/LOADPLANS
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar RT: geen LP_ bestand gevonden."
      echo "ODI deploy naar RT: geen LP_ bestand gevonden." >> $LogFile
    fi
  fi ##test -e OdiZip on LP
  ## Stap 9: Link topology
  cd $OdiFolder
  ## test if .topology to deploy
  local TopoFile="${OdiSet}.topology"
  if [ -e "${TopoFile}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van TOPOLOGY set naar de RT engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_link_context_topology.groovy"
      echo "Topo file     : ${TopoFile}"
      echo "ODI_URL       : $ODI_URL"
    fi
    DualEchoTS "Start link_context_topology on RT"
    groovy $groovy_opts $TheFld/groovy/civl_link_context_topology.groovy -f ${TopoFile}
    if [ $? -ne 0 ]; then
      # Stap 10: The TopoFile failed.
      DualEchoTS "End link_context_topology on RT"
      echo "De topology ${TopoFile} kon niet geladen worden in de Run time omgeving. Deploy is gefaald."
      echo "De topology ${TopoFile} kon niet geladen worden in de Run time omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_LinkTopoRTError
    fi
    DualEchoTS "End link_context_topology on RT"
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar RT: geen .topology bestand gevonden."
      echo "ODI deploy naar RT: geen .topology bestand gevonden." >> $LogFile
    fi
  fi ##test -e TopoZip
  ## Stap 11: Check_Release
  cd $OdiFolder
  local OdiInfo="${OdiSet}.odiinfo"
  if [ ! -e "${OdiInfo}" ]; then
    echo "De odiinfo ${OdiInfo} kon niet gevonden worden voor de check van de Run time omgeving. Deploy is gefaald."
    echo "De odiinfo ${OdiInfo} kon niet gevonden worden voor de check van de Run time omgeving. Deploy is gefaald." >> $LogFile
    exit 16
  fi
  if [ $DebugLevel -gt 3 ]; then
    echo "ODI deploy options voor de controle op de RT engine."
    echo "Groovy options: $groovy_opts"
    echo "Groovy script : $TheFld/groovy/civl_check_release.groovy"
    echo "OdiInfo file  : ${OdiInfo}"
    echo "ODI_URL       : $ODI_URL"
  fi
  DualEchoTS "Start check_release on RT"
  groovy $groovy_opts $TheFld/groovy/civl_check_release.groovy -f ${OdiInfo}
  if [ $? -ne 0 ]; then
    # Stap 12: The Check_Release failed.
    DualEchoTS "End check_release on RT"
    echo "De check_release op basis van de ${OdiInfo} is gefaald in de Run time omgeving. Deploy is gefaald."
    echo "De check_release op basis van de ${OdiInfo} is gefaald in de Run time omgeving. Deploy is gefaald." >> $LogFile
    ivl_slv_exit $DPLERRSLV_IVL_CheckRelRTError
  fi
  DualEchoTS "End check_release on RT"
  ##Stap 13: movescenarios
  DualEchoTS "Start movingscenarios on RT"
  groovy $groovy_opts $TheFld/groovy/civl_movingscenarios.groovy -p ${OdiProject}
  DualEchoTS "End movingscenarios on RT"
  ## We don't care if the above failed or not.
else
  if [ $DebugLevel -gt 3 ]; then
    echo "ODI deploy naar RT is NIET ACTIEF."
    echo "ODI deploy naar RT is NIET ACTIEF." >> $LogFile
  fi
fi ## test OdiRTActive
if [ "$OdiOEMMActive" = "YES" ]; then
  if [ $DebugLevel -gt 3 ]; then
    echo "ODI OEMM is actief."
    echo "ODI OEMM is actief." >> $LogFile
  fi
  ## Stap 0: laad de juiste settings
  getOEMMSettings
  ## Stap 1: uitrol topology op OEMM engine
  cd $OdiFolder
  ## test if TOPOLOGY_ to deploy
  local TopoZip="TOPOLOGY_${OdiSet}.zip"
  if [ -e "${TopoZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van TOPOLOGY set naar de OEMM engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_applyTopology.groovy"
      echo "Topo zip file : ${TopoZip}"
      echo "ODI_URL       : $ODI_URL"
    fi
    DualEchoTS "Start applyTopology on OEMM"
    groovy $groovy_opts $TheFld/groovy/civl_applyTopology.groovy -f ${TopoZip}
    if [ $? -ne 0 ]; then
      # Stap 2: The deploy failed. Retry it with first the removeObjectsFromRepo script
      DualEchoTS "End applyTopology on OEMM"
      echo "De topology archive ${TopoZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      echo "De topology archive ${TopoZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_TopoZipOEMMError
    fi
    DualEchoTS "End applyTopology on OEMM"
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar OEMM: geen TOPOLOGY ZIP bestand gevonden."
      echo "ODI deploy naar OEMM: geen TOPOLOGY ZIP bestand gevonden." >> $LogFile
    fi
  fi ##test -e TopoZip
  ## Stap 3: DeployArchive van de EXEC naar de RT engine
  cd $OdiFolder
  ## test if base zip exists to deploy
  local OdiZip="${OdiSet}.zip"
  if [ -e "${OdiZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van FULL set naar de OEMM engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_applyDeployArchive.groovy"
      echo "ODI zip file  : ${OdiZip}"
      echo "ODI_URL       : $ODI_URL"
    fi
    DualEchoTS "Start removeObjectsFromRepo on OEMM"
    groovy $groovy_opts $TheFld/groovy/civl_removeObjectsFromRepo.groovy -f ${OdiZip} -p ${OdiProject}
    DualEchoTS "End removeObjectsFromRepo on OEMM"
    DualEchoTS "Start applyDeployArchive on OEMM"
    groovy $groovy_opts $TheFld/groovy/civl_applyDeployArchive.groovy -f ${OdiZip}
    if [ $? -ne 0 ]; then
      # stap 6: It still fails. Report the error
      DualEchoTS "End applyDeployArchive on OEMM"
      echo "De archive ${OdiZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      echo "De archive ${OdiZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_FULLOEMMError
    fi
    DualEchoTS "End applyDeployArchive on OEMM"
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar OEMM: geen FULL zip bestand gevonden."
      echo "ODI deploy naar OEMM: geen FULL zip bestand gevonden." >> $LogFile
    fi
  fi ##test -e OdiZip on base zip
  ##stap 7: LoadPlans opladen op OEMM
  local OdiZip="LP_${OdiSet}.zip"
  if [ -e "${OdiZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van LOAD PLAN set naar de OEMM engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_importLoadplans.groovy"
      echo "ODI zip file  : ${OdiZip}"
      echo "ODI_URL       : $ODI_URL"
    fi
    mkdir -p ${TheFld}/tmp/LOADPLANS
    unzip ${OdiZip} -d ${TheFld}/tmp/LOADPLANS
    if [ $DebugLevel -gt 3 ]; then
      echo "Contents of the zip file:"
      ls -l ${TheFld}/tmp/LOADPLANS
    fi
    DualEchoTS "Start importLoadplans on OEMM"
    groovy $groovy_opts $TheFld/groovy/civl_importLoadplans.groovy -d ${TheFld}/tmp/LOADPLANS
    if [ $? -ne 0 ]; then
      # Stap 8: LP load fails. Report the error
      DualEchoTS "End importLoadplans on OEMM"
      echo "De Loadplan archive ${OdiZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      echo "De Loadplan archive ${OdiZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_LPOEMMError
    fi
    DualEchoTS "End importLoadplans on OEMM"
    ## clean up the LOADPLANS folder
    rm -rf ${TheFld}/tmp/LOADPLANS
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar OEMM: geen LP_ bestand gevonden."
      echo "ODI deploy naar OEMM: geen LP_ bestand gevonden." >> $LogFile
    fi
  fi ##test -e OdiZip on LP
  ## Stap 9: Link topology
  cd $OdiFolder
  ## test if .topology to deploy
  local TopoFile="${OdiSet}.topology"
  if [ -e "${TopoFile}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy options voor de uitrol van TOPOLOGY set naar de OEMM engine."
      echo "Groovy options: $groovy_opts"
      echo "Groovy script : $TheFld/groovy/civl_link_context_topology.groovy"
      echo "Topo file     : ${TopoFile}"
      echo "ODI_URL       : $ODI_URL"
    fi
    DualEchoTS "Start link_context_topology on OEMM"
    groovy $groovy_opts $TheFld/groovy/civl_link_context_topology.groovy -f ${TopoFile}
    if [ $? -ne 0 ]; then
      # Stap 10: The TopoFile failed.
      DualEchoTS "End link_context_topology on OEMM"
      echo "De topology ${TopoFile} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      echo "De topology ${TopoFile} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald." >> $LogFile
      ivl_slv_exit $DPLERRSLV_IVL_LinkTopoOEMMError
    fi
    DualEchoTS "End link_context_topology on OEMM"
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "ODI deploy naar OEMM: geen .topology bestand gevonden."
      echo "ODI deploy naar OEMM: geen .topology bestand gevonden." >> $LogFile
    fi
  fi ##test -e TopoZip
  ## Stap 11: Check_Release
  cd $OdiFolder
  local OdiInfo="${OdiSet}.odiinfo"
  if [ ! -e "${OdiInfo}" ]; then
    echo "De odiinfo ${OdiInfo} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
    echo "De odiinfo ${OdiInfo} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald." >> $LogFile
    exit 16
  fi
  if [ $DebugLevel -gt 3 ]; then
    echo "ODI deploy options voor de controle op de OEMM engine."
    echo "Groovy options: $groovy_opts"
    echo "Groovy script : $TheFld/groovy/civl_check_release.groovy"
    echo "OdiInfo file  : ${OdiInfo}"
    echo "ODI_URL       : $ODI_URL"
  fi
  DualEchoTS "Start check_release on OEMM"
  groovy $groovy_opts $TheFld/groovy/civl_check_release.groovy -f ${OdiInfo}
  if [ $? -ne 0 ]; then
    # Stap 12: The Check_Release failed.
    DualEchoTS "End check_release on OEMM"
    echo "De check_release op basis van de ${OdiInfo} is gefaald in de OEMM omgeving. Deploy is gefaald."
    echo "De check_release op basis van de ${OdiInfo} is gefaald in de OEMM omgeving. Deploy is gefaald." >> $LogFile
    ivl_slv_exit $DPLERRSLV_IVL_CheckRelOEMMError
  fi
  DualEchoTS "End check_release on OEMM"
  ##Stap 13: movescenarios
  DualEchoTS "Start movingscenarios on OEMM"
  groovy $groovy_opts $TheFld/groovy/civl_movingscenarios.groovy -p ${OdiProject}
  DualEchoTS "End movingscenarios on OEMM"
  ## We don't care if the above failed or not.
else
  if [ $DebugLevel -gt 3 ]; then
    echo "ODI deploy naar OEMM is NIET ACTIEF."
    echo "ODI deploy naar OEMM is NIET ACTIEF." >> $LogFile
  fi
fi ## test OdiOEMMActive
## We have finished using the RT or OEMM settings. Clear them
ClearEngineSettings
if [ $DebugLevel -gt 3 ]; then
  echo "DoIvlOneOdi beeindigd."
  echo "DoIvlOneOdi beeindigd." >> $LogFile
fi
}

ivl_slv_exit() {
## This function will exit the deploy with an ERROR status
local errorcode=$1
local stacktrace=$(caller 0)
echo "debug info: ivl_slv_exit called from: $stacktrace"

## log the error to the ODI logging infrastructure tables
DoLogToDB_EndNOK $LogFile $TheFld $TheEnv $ZipFolder $TicketNr $JenkinsBuildNr $JenkinsBuildURL $errorcode $DebugLevel

## now call the generic slv_exit code. That will exit to the requesting server with the correct RC.
slv_exit $errorcode
}

DoIvlFullInstall() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local DebugLevel=$5
local LogFile=$6
local ZipFolder=$7
local DoTestSql=$8
local JenkinsBuildNr=${9}
local JenkinsBuildURL=${10}

if [ $DebugLevel -gt 3 ]; then
  ## log to Jenkins
  echo "DoIvlFullInstall functie gestart met deze opties:"
  echo "TheEnv                = ${TheEnv}"
  echo "TheFld                = ${TheFld}"
  echo "TheADC                = ${TheADC}"
  echo "TicketNr              = ${TicketNr}"
  echo "DebugLevel            = ${DebugLevel}"
  echo "LogFile               = ${LogFile}"
  echo "ZipFolder             = ${ZipFolder}"
  echo "DoTestSql             = ${DoTestSql}"
  echo "JenkinsBuildNr        = ${JenkinsBuildNr}"
  echo "JenkinsBuildURL       = ${JenkinsBuildURL}"
  echo "SQLPlus version: "
  sqlplus -V
  ## log to the log file
  echo "DoIvlFullInstall functie gestart met deze opties:" >> $LogFile
  echo "TheEnv                = ${TheEnv}" >> $LogFile
  echo "TheFld                = ${TheFld}" >> $LogFile
  echo "TheADC                = ${TheADC}" >> $LogFile
  echo "TicketNr              = ${TicketNr}" >> $LogFile
  echo "DebugLevel            = ${DebugLevel}" >> $LogFile
  echo "LogFile               = ${LogFile}" >> $LogFile
  echo "ZipFolder             = ${ZipFolder}" >> $LogFile
  echo "DoTestSql             = ${DoTestSql}" >> $LogFile
  echo "JenkinsBuildNr        = ${JenkinsBuildNr}" >> $LogFile
  echo "JenkinsBuildURL       = ${JenkinsBuildURL}" >> $LogFile
  echo "SQLPlus version: " >> $LogFile
  sqlplus -V >> $LogFile
fi

TheLogFile=$LogFile

cd ${ZipFolder}
ls -l >> $LogFile

mkdir unzipped
cd unzipped
unzip ../*.zip
if [ $? -ne 0 ]; then
  echo "ERROR: De unzip operatie verliep niet goed. Mogelijks is de zip file beschadigd."
  echo "ERROR: De unzip operatie verliep niet goed. Mogelijks is de zip file beschadigd." >> $LogFile
  ivl_slv_exit $DPLERRSLV_IVL_ZipError
fi

## We have tested the zip before, and it passed the tests. So we can now proceed without
## having to recheck these elements.

## Perform logging actions
DoLogToDB_Start $LogFile $TheFld $TheEnv $ZipFolder $TicketNr $JenkinsBuildNr $JenkinsBuildURL $DebugLevel


DualEcho "**************************************"
DualEcho "*                                    *"
DualEcho "* DDDDDDDD   DDDDDDDD    LLLL        *"
DualEcho "*   DD   DD    DD   DD    LL         *"
DualEcho "*   DD    DD   DD    DD   LL         *"
DualEcho "*   DD    DD   DD    DD   LL         *"
DualEcho "*   DD    DD   DD    DD   LL         *"
DualEcho "*   DD    DD   DD    DD   LL         *"
DualEcho "*   DD   DD    DD   DD    LL    LL   *"
DualEcho "* DDDDDDDD   DDDDDDDD    LLLLLLLLL   *"
DualEcho "*                                    *"
DualEcho "**************************************"

## load Oracle related configIT parameter values that will influence how the deploy will work
source $TheFld/psw/ivlremcfgoracle.sh

## Check the SQL_ACTIVE flag. If it is Off, then we can skip the complete SQL part.
##    This occurs in environments where ODI is not installed, or environments where the DDLs
##    come from a refresh rather than a deploy.
if [ "$SqlActive" = "NO" ]; then
  echo "The SQL_ACTIVE flag prohibits execution on this environment. Skipping SQL section." >> $LogFile
  echo "The SQL_ACTIVE flag prohibits execution on this environment. Skipping SQL section."
else
  ## First, we must check whether a Test SQL must be performed. If it is, that must happen
  ## before testing the Running processes.
  if [ ${DoTestSql} -eq 1 ]; then
    ## We are allowed to perform a test SQL on this environment. Load the code for it.
    source $TheFld/psw/ivlremtestsql.sh
    ## Test if ConfigIT allows to do the tests
    if IsConfigITTestSqlActive; then
      ## load the execution_order and process it
      cd ${ZipFolder}/unzipped
      if [ -f "parameters/DDL_execution_order.txt" ]; then
        DualEchoTS "Start of TEST SQL phase."
        ## there is SQL code to test. First take a restore point
        DoIvlCreateRestorePoint
        cd ${ZipFolder}/unzipped
        ## Parse the execution order line by line
        while read -r line; do
          mainsql="${line}_main_sql.sql"
          sqlfolder="${ZipFolder}/unzipped/sql/${line}"
          echo "preparing for SQL process of file $mainsql." >> $LogFile
          DoIvlTestOneSql $LogFile $sqlfolder $mainsql $TheFld $DebugLevel
          cd ${ZipFolder}/unzipped
        done < "parameters/DDL_execution_order.txt"
        ## All sql parts completed OK. We can erase the restore point
        DoIvlDropRestorePoint
        DualEchoTS "End of TEST SQL phase."
      else
        if [ $DebugLevel -gt 3 ]; then
          echo "file DDL_execution_order.txt ontbreekt, dus GEEN TEST SQL uitvoering."
          echo "file DDL_execution_order.txt ontbreekt, dus GEEN TEST SQL uitvoering." >> $LogFile
        fi
      fi
    else
      if [ $DebugLevel -gt 3 ]; then
        echo "ConfigIT settings zorgen ervoor dat er GEEN TEST SQL uitvoering is."
        echo "ConfigIT settings zorgen ervoor dat er GEEN TEST SQL uitvoering is." >> $LogFile
      fi
    fi
  fi # if DoTestSql -eq 1
  ## We really need to deploy something. Thus, we must check the running state
  DualEchoTS "Start of Check STOP phase (if applicable)."
  DoIvlCheckStop $LogFile $ZipFolder $TheFld $DebugLevel
  DualEchoTS "End of Check STOP phase (if applicable)."

  cd ${ZipFolder}/unzipped
  if [ -f "parameters/DDL_execution_order.txt" ]; then
    DualEchoTS "Start of SQL Deploy."
    ## Parse the execution order line by line
    while read -r line; do
      mainsql="${line}_main_sql.sql"
      sqlfolder="${ZipFolder}/unzipped/sql/${line}"
      echo "preparing for SQL process of file $mainsql." >> $LogFile
      DoIvlOneSql $LogFile $sqlfolder $mainsql $TheFld $DebugLevel
      cd ${ZipFolder}/unzipped
    done < "parameters/DDL_execution_order.txt"
    DualEchoTS "End of SQL Deploy."
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "file DDL_execution_order.txt ontbreekt, dus GEEN SQL uitvoering."
      echo "file DDL_execution_order.txt ontbreekt, dus GEEN SQL uitvoering." >> $LogFile
    fi
  fi
fi

DualEcho "**************************************"
DualEcho "*                                    *"
DualEcho "* Einde SQL/DDL deploy               *"
DualEcho "*                                    *"
DualEcho "**************************************"

DualEcho ""

DualEcho "**************************************"
DualEcho "*                                    *"
DualEcho "*     OO     DDDDDDDD    IIII        *"
DualEcho "*   OOOOOO     DD   DD    II         *"
DualEcho "*  OO    OO    DD    DD   II         *"
DualEcho "*  OO    OO    DD    DD   II         *"
DualEcho "*  OO    OO    DD    DD   II         *"
DualEcho "*  OO    OO    DD    DD   II         *"
DualEcho "*   OOOOOO     DD   DD    II         *"
DualEcho "*     OO     DDDDDDDD    IIII        *"
DualEcho "*                                    *"
DualEcho "**************************************"

cd ${ZipFolder}/unzipped
if [ -f "parameters/ODI_execution_order.txt" ]; then
  ## Parse the execution order line by line
  while read -r line; do
    odifolder="odi/${line}"
    echo "preparing for ODI process of folder $odifolder." >> $LogFile
    DoIvlOneOdi $LogFile ${ZipFolder}/unzipped/${odifolder} $line $TheFld $DebugLevel
    cd ${ZipFolder}/unzipped
  done < "parameters/ODI_execution_order.txt"
else
  if [ $DebugLevel -gt 3 ]; then
    echo "file ODI_execution_order.txt ontbreekt, dus GEEN ODI uitvoering."
    echo "file ODI_execution_order.txt ontbreekt, dus GEEN ODI uitvoering." >> $LogFile
  fi
fi

DualEcho "**************************************"
DualEcho "*                                    *"
DualEcho "* Einde ODI deploy                   *"
DualEcho "*                                    *"
DualEcho "**************************************"
## Perform logging actions
DoLogToDB_EndOK $LogFile $TheFld $TheEnv $ZipFolder $TicketNr $JenkinsBuildNr $JenkinsBuildURL $DebugLevel

exit

}
