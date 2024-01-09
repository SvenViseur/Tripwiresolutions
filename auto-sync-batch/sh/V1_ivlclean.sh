#!/bin/bash
#### V1_ivlclean.sh script
# This script is called from the ivlrun_script.sh
#
# Command line options:
# option             mand.     value (all values are case sensitive!!!)
# -T<target>          YES      the target application, either "IVL" or "CIVL"
# -E<environment>     YES      the target Environment, either "ACC","SIM","PRD","SIC"
# -V<version>         YES      the version should be the same as the script version
# -R<repo             YES      the type repo: RT or OEMM
# -C<cleanup type>    YES      type of cleanup (RT or DVL)
# -F<source file>     YES      the source File (location included)
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Feb/2022      # 1.0.0   # initial version
#############################################################################
ivlrun_clean_main_script_version="V1"

SetLogFile()
{

LOG_FILE="${ivllog}/IVLCLEAN_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

SetLocalLogFile()
{

main_log_file_copy=$LOG_FILE

#Override the log settings for the specific directory
LOG_FILE="${ivllog}/ivlclean_$(date +"%Y%m%d_%H%M%S").log"
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
  source ${ivlini}/${ivlclean_code_version}_ivlclean.properties
  source ${ivlini}/${ivlclean_code_version}_ivlclean_credentials.properties
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
export GROOVY_CONF="${ivlini}/${ivlclean_odi_RT_version}"

}

getOEMMSettings() {
export ODI_URL="$OdiOEMMUrl"
export ODI_USER="$OdiOEMMSecUser"
export ODI_PWD="$OdiOEMMSecPsw"
export ODI_MASTER_USER="$OdiOEMMMasterUser"
export ODI_MASTER_PWD="$OdiOEMMMasterPsw"
export ODI_WORKREP="WORKREP"
export GROOVY_CONF="${ivlini}/${ivlclean_odi_OEMM_version}"

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

export GROOVY_CONF="${ivlini}/${ivlclean_odi_OEMM_version}"

}

DoODICleanup() {

  SUBROUTINE=$0
  Log "${ivlsh}/${ivlrun_clean_main_script_version}_ivlclean_functions.sh"
  source ${ivlsh}/${ivlrun_clean_main_script_version}_ivlclean_functions.sh

  ivlclean_groovy_folder=/$platform/ivl/lib
  ivlclean_groovy_conf="${ivlini}/ivliws-groovy-${ivliws_target^^}.cfg"

  ivlclean_temp_folder="${ivltmp}/J${UNISON_JOBNUM}"

  Log "Start runODICleanup"

  rm -rf ${ivlclean_temp_folder}
  mkdir -p ${ivlclean_temp_folder}

  ivlclean_initialize

  runODICleanup

  if [ ! $ivlclean_error == "0" ]; then
    Log "There was an error during the execution of the ODI Cleanup" 
    Failure "DoODICleanup failed with error $ivliws_error"
  fi
}

SetLogFile

LogIWSInfo

Initialise

ArgTarget="X"
ArgEnvironment="X"
ArgRepoType="X"
ArgVersion="X"
ArgSource="X"
ArgCleanupType="X"

## process command line options

while getopts :hT:E:R:V:F:C: option; do
  case $option
    in
    h) print_help;;
    T) ArgTarget=${OPTARG};;
    E) ArgEnvironment=${OPTARG};;
    R) ArgRepoType=${OPTARG};;
    V) ArgVersion=${OPTARG};;
    F) ArgSource=${OPTARG};;
    C) ArgCleanupType=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done

ivlclean_code_version="${ArgVersion}"

Log "checking version"

#Check tussen VERSION (parameter) en oemm_script_version => moeten gelijk zijn
if [ ! "${ivlrun_clean_main_script_version}" = "${ArgVersion}" ]; then
  Log "Wrong version of script. (${ivlrun_clean_main_script_version} vs ${ArgVersion})"
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
if [ ! "${ArgEnvironment}" = "DVL" ] &&  [ ! "${ArgEnvironment}" = "ACC" ] && [ ! "${ArgEnvironment}" = "SIM" ] && [ ! "${ArgEnvironment}" = "PRD" ] && [ ! "${ArgEnvironment}" = "SIC" ]; then
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

if [ ! "${ArgCleanupType}" = "DVL" ] && [ ! "${ArgCleanupType}" = "RT" ]; then
    Log "Invalid value for -C parameter. Eiter DVL or RT can be used"
    exit 1
    #Failure "bad options."
fi

# Check Source
if [ "${ArgSource}" = "X" ]; then
    Log "Missing -F parameter. Use -h for help."
    exit 1
    #Failure "bad options."
fi

if [ ! -f "${ArgSource}" ]; then
    Log "wrong -F parameter. ${ArgSource} does not exist Use -h for help."
    exit 1
    #Failure "bad options."
fi

# Step 1: set the settings for the target repository

ivlclean_target="${ArgTarget}"
ivlclean_env="${ArgEnvironment}"
ivlclean_repotype="${ArgRepoType}"
ivlclean_input_file="${ArgSource}"
ivlclean_cleanuptype="${ArgCleanupType}"

Log "##############################"
Log "Target definition and settings"
Log "##############################"
Log $ivlclean_target
Log $ivlclean_env
Log $ivlclean_repotype
Log $ivlclean_input_file
Log $ivlclean_cleanuptype
Log "##############################"

# Load the values used in the code according the information given as parameter
LoadIniFiles

Log "Started with the Folder Sync on target : ${ivlclean_env}"

if [ "${ArgRepoType}" == "OEMM" ]; then
   # Check if ivloem is active on this environment
   if [ "${OdiOEMMActive}" = "NO" ]; then
      Log "(C)IVL OEMM/DVL for ${ivlclean_target}/${ivlclean_env} is inactive according to the properties files. Nothing to do."
      exit 0
   fi

   getOEMMSettings

fi

if [ "${ArgRepoType}" == "RT" ]; then
   # Check if ivloem is active on this environment
   if [ "${OdiRTActive}" = "NO" ]; then
      Log "(C)IVL RT for ${ivlclean_target}/${ivlclean_env} is inactive according to the properties files. Nothing to do."
      exit 0
   fi

   getRTSettings

fi

DoODICleanup

exit 0

