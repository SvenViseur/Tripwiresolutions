#!/bin/bash
#### V1_ivlcheck_deploy_runtime.sh script
# This script is called from the ivlrun_script.sh
#
# Command line options:
# option             mand.     value (all values are case sensitive!!!)
# -T<target>          YES      the target application, either "IVL" or "CIVL"
# -E<environment>     YES      the target Environment, either "ACC","SIM","PRD","SIC"
# -V<version>         YES      the version should be the same as the script version
# -L<list tickets>    YES      the list of tickets, delimited by comma
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Feb/2022      # 1.0.0   # initial version
#############################################################################
ivlrun_check_deploy_main_script_version="V1"

SetLogFile()
{

LOG_FILE="${ivllog}/ivlcheck_deploy_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

SetLocalLogFile()
{

main_log_file_copy=$LOG_FILE

#Override the log settings for the specific directory
LOG_FILE="${ivllog}/ivlcheck_deploy_$(date +"%Y%m%d_%H%M%S").log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

Initialise()
{
    SUBROUTINE=$0

    # General Settings and procedures
    . $colash/ShProcedures.sh;
    . $colash/Oracle.sh;
}

LoadIniFiles()
{
  source ${ivlini}/${ivlcheck_deploy_code_version}_ivlcheck_deploy.properties
  source ${ivlini}/${ivlcheck_deploy_code_version}_ivlcheck_deploy_credentials.properties
}

## The values used in the below functions are loaded via a call to the
## LoadIniFiles function. That loads 2 properties files. The contents of
## those files is built during the deploy using placeholders and ConfigIT.

getRTSettings() {
export ODI_URL="$OdiRTUrl"
export ODI_USER="$OdiRTSecUser"
export ODI_PWD="$OdiRTSecPsw"
export ODI_MASTER_USER="$OdiRTMasterUser"
export ODI_MASTER_PWD="$OdiRTMasterPsw"
export ODI_WORKREP="WORKREP"

export GROOVY_CONF="${ivlini}/${ivlcheck_deploy_odi_RT_version}"

}

getOEMMSettings() {
export ODI_URL="$OdiOEMMUrl"
export ODI_USER="$OdiOEMMSecUser"
export ODI_PWD="$OdiOEMMSecPsw"
export ODI_MASTER_USER="$OdiOEMMMasterUser"
export ODI_MASTER_PWD="$OdiOEMMMasterPsw"
export ODI_WORKREP="WORKREP"

export GROOVY_CONF="${ivlini}/${ivlcheck_deploy_odi_OEMM_version}"

}

ClearEngineSettings() {
export ODI_URL="None selected"
export ODI_USER="No_User"
export ODI_PWD="No_Password"
export ODI_MASTER_USER="No_User"
export ODI_MASTER_PWD="No_Password"
export ODI_WORKREP="No_Repo"

export user_profile_file=""
export tech_user_file=""
export iam_odi_file=""

export GROOVY_CONF="${ivlini}/${ivlcheck_deploy_odi_OEMM_version}"

}

DoODICheckDeploy() {

  SUBROUTINE=$0
  Log "${ivlsh}/${ivlrun_check_deploy_main_script_version}_ivlcheck_deploy_functions.sh"
  source ${ivlsh}/${ivlrun_check_deploy_main_script_version}_ivlcheck_deploy_functions.sh

  ivlcheck_deploy_groovy_folder=/$platform/ivl/lib
  ivlcheck_deploy_groovy_conf="${ivlini}/ivliws-groovy-${ivliws_target^^}.cfg"

  ivlcheck_deploy_temp_folder="${ivltmp}/J${UNISON_JOBNUM}"

  Log "Start RunODICheckDeploy"

  rm -rf ${ivlcheck_deploy_temp_folder}
  mkdir -p ${ivlcheck_deploy_temp_folder}

  ivlcheck_deploy_initialize

  RunODICheckDeploy

  if [ ! $ivlcheck_deploy_error == "0" ]; then
    Log "There was an error during the execution of the ODICheckDeploy"
    Failure "ODICheckDeploy failed with error $ivliws_error"
  fi
#  rm -rf ${ivlcheck_deploy_temp_folder}
}

SetLogFile

LogIWSInfo

Initialise

ArgTarget="X"
ArgEnvironment="X"
ArgRepoType="RT"
ArgVersion="X"
ArgList="X"

## process command line options

while getopts :hT:E:V:L: option; do
  case $option
    in
    h) print_help;;
    T) ArgTarget=${OPTARG};;
    E) ArgEnvironment=${OPTARG};;
#    R) ArgRepoType=${OPTARG};;
    V) ArgVersion=${OPTARG};;
    L) ArgList=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done

ivlcheck_deploy_code_version="${ArgVersion}"

Log "checking version"

#Check tussen VERSION (parameter) en oemm_script_version => moeten gelijk zijn
if [ ! "${ivlrun_check_deploy_main_script_version}" = "${ArgVersion}" ]; then
  Log "Wrong version of script. (${ivlrun_check_deploy_main_script_version} vs ${ArgVersion})"
  exit 1
#  Failure "bad version."
fi


Log "checking target"
# Check ArgTarget value
if [ "${ArgTarget}" = "X" ]; then
  Log "Missing -T parameter. Use -h for help."
  exit 1
  #Failure "bad options."
fi
if [ ! "${ArgTarget}" = "CIVL" ] && [ ! "${ArgTarget}" = "IVL" ]; then
  Log "Invalid value for -T parameter. Only CIVL or IVL are allowed. Use -h for help."
  exit 1
  #Failure "bad options."
fi

# Check ArgEnvironment value
if [ "${ArgEnvironment}" = "X" ]; then
  Log "Missing -E parameter. Use -h for help."
  exit 1
  #Failure "bad options."
fi
if [ ! "${ArgEnvironment}" = "DVL" ] && [ ! "${ArgEnvironment}" = "ACC" ] && [ ! "${ArgEnvironment}" = "SIM" ] && [ ! "${ArgEnvironment}" = "PRD" ] && [ ! "${ArgEnvironment}" = "SIC" ]; then
  Log "Invalid value for -E parameter. Only DVL, ACC, SIM, PRD or SIC are allowed. Use -h for help."
  exit 1
  #Failure "bad options."
fi

# Check type deploy
if [ "${ArgRepoType}" = "X" ]; then
    Log "Missing -R parameter. Use -h for help."
    exit 1
    #Failure "bad options."
fi
if [ ! "${ArgRepoType}" = "OEMM" ] && [ ! "${ArgRepoType}" = "RT" ]; then
    Log "Invalid value for -R parameter. Eiter OEMM or RT can be used"
    exit 1
    #Failure "bad options."
fi

Log "checking list of tickets"
# Check List of Tickets
if [ "${ArgList}" = "X" ]; then
  Log "Missing -L parameter. Use -h for help."
  exit 1
  #Failure "bad options."
fi

ivlcheck_deploy_target="${ArgTarget}"
ivlcheck_deploy_env="${ArgEnvironment}"
ivlcheck_deploy_repotype="${ArgRepoType}"
ivlcheck_deploy_tickets=$(echo "${ArgList}" | sed 's/ //g')

Log $ivlcheck_deploy_target
Log $ivlcheck_deploy_env
Log $ivlcheck_deploy_repotype
Log $ivlcheck_deploy_tickets


# Load the values used in the code according the information given as parameter
LoadIniFiles

Log "Started with the user management for Runtime only"

if [ "${ArgRepoType}" == "OEMM" ]; then
   # Check if ivloem is active on this environment
   if [ "${OdiOEMMActive}" = "NO" ]; then
      Log "IVL RT for ${ivlcheck_deploy_target}/${ivlcheck_deploy_env} is inactive according to the properties files. Nothing to do."
      exit 0
   fi

   getOEMMSettings

fi

if [ "${ArgRepoType}" == "RT" ]; then
   # Check if ivloem is active on this environment
   if [ "${OdiRTActive}" = "NO" ]; then
      Log "IVL RT for ${ivlcheck_deploy_target}/${ivlcheck_deploy_env} is inactive according to the properties files. Nothing to do."
      exit 0
   fi

   getRTSettings

fi

Log "started with ODI security"

DoODICheckDeploy

exit 0

