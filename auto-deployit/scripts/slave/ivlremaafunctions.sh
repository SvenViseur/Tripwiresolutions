#### ivlremaafunctions.sh script
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
# This AA functions module contains functions that can be executed by
# Automated Actions. It is NOT meant to deploy any material, merely to
# perform a set of preselected actions like start and stop code.
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Jun/2020      # 1.0.0   # initial version
# dexa  # Jun/2020      # 1.0.1   # add ivlgroovypre to disable groovy calls
# dexa  # Jul/2020      # 1.1.0   # add call civl_register_properties
#       #               #         #
#       #               #         #
#       #               #         #
#############################################################################
#
ScriptName="ivlremaafunctions.sh"
ScriptVersion="1.1.0"

ivlgroovypre=""  ## default is no echo mode
## activate the below line to activate an echo mode instead of
## real execution of groovy calls
##ivlgroovypre="echo " ## use echo mode

DoStartScheduler() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TheTicketNr=$4
local JenkinsBuildNr=$5
local JenkinsBuildURL=$6
local DebugLevel=$7

## test ODI using the activesessions script
OdiRTDeployUser="Undef"
## load the credentials
source $TheFld/ivlremcfgodi.sh
if [ $OdiRTDeployUser = "Undef" ]; then
  echo "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"
if [ $DebugLevel -gt 3 ]; then
  echo "Alle verdere ODI groovy stappen voor deze server gebruiken deze settings:"
  echo "GROOVY_CONF   : $GROOVY_CONF with contents:"
  cat $GROOVY_CONF
  echo "End of $GROOVY_CONF contents"
fi
if [ "$OdiRTActive" = "YES" ]; then
  echo "ODI RT is actief."
  export ODI_URL="$OdiRTUrl"
  export ODI_USER="$OdiRTDeployUser"
  export ODI_PWD="$OdiRTDeployPsw"
  export ODI_MASTER_USER="$OdiRTMasterUser"
  export ODI_MASTER_PWD="$OdiRTMasterPsw"
  export ODI_WORKREP="WORKREP"
  export RMC_DB_URL="$OdiLogDbUrl"
  export RMC_DB_USER="$OdiLogDbUser"
  export RMC_DB_PASSWORD="$OdiLogDbPsw"
  $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_activate_schedule_db.groovy -t ${TheTicketNr} -r ${JenkinsBuildNr}
  if [ $? -ne 0 ]; then
    echo "De ODI scheduler kon niet gestart worden."
    exit 16
  else
    echo "De ODI scheduler is nu gestart."
  fi ## RC test on groovy runningSession
else
  echo "ODI RT is niet actief."
fi

}

DoStopScheduler() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TheTicketNr=$4
local JenkinsBuildNr=$5
local JenkinsBuildURL=$6
local DebugLevel=$7

## test ODI using the activesessions script
OdiRTDeployUser="Undef"
## load the credentials
source $TheFld/ivlremcfgodi.sh
if [ $OdiRTDeployUser = "Undef" ]; then
  echo "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"
if [ $DebugLevel -gt 3 ]; then
  echo "Alle verdere ODI groovy stappen voor deze server gebruiken deze settings:"
  echo "GROOVY_CONF   : $GROOVY_CONF with contents:"
  cat $GROOVY_CONF
  echo "End of $GROOVY_CONF contents"
fi
if [ "$OdiRTActive" = "YES" ]; then
  echo "ODI RT is actief."
  export ODI_URL="$OdiRTUrl"
  export ODI_USER="$OdiRTDeployUser"
  export ODI_PWD="$OdiRTDeployPsw"
  export ODI_MASTER_USER="$OdiRTMasterUser"
  export ODI_MASTER_PWD="$OdiRTMasterPsw"
  export ODI_WORKREP="WORKREP"
  export RMC_DB_URL="$OdiLogDbUrl"
  export RMC_DB_USER="$OdiLogDbUser"
  export RMC_DB_PASSWORD="$OdiLogDbPsw"
  $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_deactivate_schedule_db.groovy -t ${TheTicketNr} -r ${JenkinsBuildNr}
  if [ $? -ne 0 ]; then
    echo "De ODI scheduler kon niet gestopt worden."
    exit 16
  else
    echo "De ODI scheduler is nu gestopt."
  fi ## RC test on groovy runningSession
else
  echo "ODI RT is niet actief."
fi

}


DoWaitRunningSessions() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TheTicketNr=$4
local JenkinsBuildNr=$5
local JenkinsBuildURL=$6
local DebugLevel=$7

## test ODI using the activesessions script
OdiRTDeployUser="Undef"
## load the credentials
source $TheFld/ivlremcfgodi.sh
if [ $OdiRTDeployUser = "Undef" ]; then
  echo "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"
if [ $DebugLevel -gt 3 ]; then
  echo "Alle verdere ODI groovy stappen voor deze server gebruiken deze settings:"
  echo "GROOVY_CONF   : $GROOVY_CONF with contents:"
  cat $GROOVY_CONF
  echo "End of $GROOVY_CONF contents"
fi
if [ "$OdiRTActive" = "YES" ]; then
  echo "ODI RT is actief."
  export ODI_URL="$OdiRTUrl"
  export ODI_USER="$OdiRTDeployUser"
  export ODI_PWD="$OdiRTDeployPsw"
  export ODI_MASTER_USER="$OdiRTMasterUser"
  export ODI_MASTER_PWD="$OdiRTMasterPsw"
  export ODI_WORKREP="WORKREP"
  i=0
  ended="0"
  while [ "$ended" = "0" ]; do
    $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_runningSession.groovy
    lastRC=$?
    ## RC values:
    ## 0=no more running sessions, 1=there are running sessions-please wait, 2=system error, stop now
    if [ $lastRC -ne 0 ]; then
      if [ $lastRC -gt 1 ]; then
        ## system error while checking - stop now
        echo "Er was een probleem bij de controle op RunningSessions. Kan niet verdergaan."
        exit 16
      fi
      ## RC=1 dus sleep en loop
      if [ $i -gt 150 ]; then  ## timeout is 150 minuten
        ended="1"
      else
        ((i++));
        sleep 1m
      fi
    else
      ended="1"
      echo "De ODI omgeving is gestopt."
    fi ## RC test on groovy runningSession
  done
  if [ $lastRC -ne 0 ]; then
    echo "Er was een time-out bij het wachten op het stoppen van de ODI processen."
    exit 16
  fi
else
  echo "ODI RT is niet actief."
fi

}


DoRunProperties() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TheTicketNr=$4
local ScenActionsFile=$5
local TicketInfoFile=$6
local JenkinsBuildNr=$7
local JenkinsBuildURL=$8
local DebugLevel=$9

## test ODI using the activesessions script
OdiRTDeployUser="Undef"
## load the credentials
source $TheFld/ivlremcfgodi.sh
if [ $OdiRTDeployUser = "Undef" ]; then
  echo "De file ivlremcfgodi.sh kon niet geladen worden met configuratiedata."
  exit 16
fi
declare -x GROOVY_CONF="$TheFld/groovy-ivl-generic.conf"
if [ $DebugLevel -gt 3 ]; then
  echo "Alle verdere ODI groovy stappen voor deze server gebruiken deze settings:"
  echo "GROOVY_CONF   : $GROOVY_CONF with contents:"
  cat $GROOVY_CONF
  echo "End of $GROOVY_CONF contents"
fi
if [ "$OdiRTActive" = "YES" ]; then
  echo "ODI RT is actief."
  export ODI_URL="$OdiRTUrl"
  export ODI_USER="$OdiRTDeployUser"
  export ODI_PWD="$OdiRTDeployPsw"
  export ODI_MASTER_USER="$OdiRTMasterUser"
  export ODI_MASTER_PWD="$OdiRTMasterPsw"
  export ODI_WORKREP="WORKREP"
  export RMC_DB_URL="$OdiLogDbUrl"
  export RMC_DB_USER="$OdiLogDbUser"
  export RMC_DB_PASSWORD="$OdiLogDbPsw"
  if [ $DebugLevel -gt 3 ]; then
    echo "Deinhoud van de ticketinfo file is:"
    cat ${TicketInfoFile}
    echo "Einde van de ticketinfo file."
  fi
  $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_register_properties.groovy -f ${TicketInfoFile} -t ${TheTicketNr} -r ${JenkinsBuildNr}
  $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_register_run.groovy -f ${TicketInfoFile} -t ${TheTicketNr} -e ${TheEnv} -s "START" -r ${JenkinsBuildNr} -u ${JenkinsBuildURL}
  if [ $DebugLevel -gt 3 ]; then
    echo "Deze acties zullen gevraagd worden:"
    cat ${ScenActionsFile}
    echo "Einde van de gevraagde acties."
  fi
  $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_start_scenario.groovy -f "${ScenActionsFile}"
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "Het civl_start_scenario.groovy script faalde."
    $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_register_run.groovy -f ${TicketInfoFile} -t ${TheTicketNr} -e ${TheEnv} -s "END WITH FAIL" -m "RC=$RC" -r ${JenkinsBuildNr} -u ${JenkinsBuildURL}
    exit 16
  else
    echo "Het civl_start_scenario.groovy script is OK."
    $ivlgroovypre groovy $groovy_opts $TheFld/groovy/civl_register_run.groovy -f ${TicketInfoFile} -t ${TheTicketNr} -e ${TheEnv} -s "END" -r ${JenkinsBuildNr} -u ${JenkinsBuildURL}
  fi ## RC test on groovy start_scenario
else
  echo "ODI RT is niet actief."
fi

}
