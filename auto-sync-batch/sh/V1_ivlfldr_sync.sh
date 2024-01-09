#!/bin/bash
#### V1_ivlfldr_sync.sh script
# This script is called from the ivlrun_script.sh
#
# Command line options:
# option             mand.     value (all values are case sensitive!!!)
# -T<target>          YES      the target application, either "IVL" or "CIVL"
# -E<environment>     YES      the target Environment, either "ACC","SIM","PRD","SIC"
# -V<version>         YES      the version should be the same as the script version
# -R<repo             YES      the type repo: RT or OEMM
# -S<source>          YES      the source Environment, example DVL
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Feb/2022      # 1.0.0   # initial version
#############################################################################
ivlrun_fldrsync_main_script_version="V1"

SetLogFile()
{

LOG_FILE="${ivllog}/IVLFLDR_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

SetLocalLogFile()
{

main_log_file_copy=$LOG_FILE

#Override the log settings for the specific directory
LOG_FILE="${ivllog}/IVLFLDR_$(date +"%Y%m%d_%H%M%S").log"
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
  source ${ivlini}/${ivlfldr_code_version}_ivlfldr_sync.properties
  source ${ivlini}/${ivlfldr_code_version}_ivlfldr_sync_credentials.properties
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
export GROOVY_CONF="${ivlini}/${ivlfldr_odi_RT_version}"

}

getOEMMSettings() {
export ODI_URL="$OdiOEMMUrl"
export ODI_USER="$OdiOEMMSecUser"
export ODI_PWD="$OdiOEMMSecPsw"
export ODI_MASTER_USER="$OdiOEMMMasterUser"
export ODI_MASTER_PWD="$OdiOEMMMasterPsw"
export ODI_WORKREP="WORKREP"
export GROOVY_CONF="${ivlini}/${ivlfldr_odi_OEMM_version}"

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

export GROOVY_CONF="${ivlini}/${ivlfldr_odi_OEMM_version}"

}

DoODIFolderSync_GetFolders() {

  SUBROUTINE=$0
  Log "${ivlsh}/${ivlrun_fldrsync_main_script_version}_ivlfldr_functions.sh"
  source ${ivlsh}/${ivlrun_fldrsync_main_script_version}_ivlfldr_functions.sh

  ivlfldr_groovy_folder=/$platform/ivl/lib
  ivlfldr_groovy_conf="${ivlini}/ivliws-groovy-${ivliws_target^^}.cfg"

  ivlfldr_temp_folder="${ivltmp}/J${UNISON_JOBNUM}"

  Log "Start runODIFolderSync_GetFolders"

  rm -rf ${ivlfldr_temp_folder}
  mkdir -p ${ivlfldr_temp_folder}

  ivlfldr_folders_directory="${ivlfldr_temp_folder}/FLDRS"
  ivlfldr_exclude_folders="${ivlpub}/ivlfldr/exclude_folders.lst"

  ivlfldr_initialize

  runODIFolderSync_GetFolders

  if [ ! $ivlfldr_error == "0" ]; then
    Log "There was an error during the execution of the ODI Folder Sync" 
    Failure "DoODIFolderSync_GetFolders failed with error $ivliws_error"
  fi
}

DoODIFolderSync_SetFolders() {

  SUBROUTINE=$0
  Log "${ivlsh}/${ivlrun_fldrsync_main_script_version}_ivlfldr_functions.sh"
  source ${ivlsh}/${ivlrun_fldrsync_main_script_version}_ivlfldr_functions.sh

  ivlfldr_groovy_folder=/$platform/ivl/lib
  ivlfldr_groovy_conf="${ivlini}/ivliws-groovy-${ivliws_target^^}.cfg"

  ivlfldr_temp_folder="${ivltmp}/J${UNISON_JOBNUM}"
  ivlfldr_folders_directory="${ivlfldr_temp_folder}/FLDRS"

  Log "Start runODIFolderSync_SetFolders"

  ivlfldr_initialize

  runODIFolderSync_SetFolders

  if [ ! $ivlfldr_error == "0" ]; then
    Log "There was an error during the execution of the ODI Folder Sync"
    Failure "DoODIFolderSync_SetFolders failed with error $ivliws_error"
  fi

  rm -rf ${ivlfldr_temp_folder}

}

SetLogFile

LogIWSInfo

Initialise

ArgTarget="X"
ArgEnvironment="X"
ArgRepoType="X"
ArgVersion="X"
ArgSource="X"

## process command line options

while getopts :hT:E:R:V:S: option; do
  case $option
    in
    h) print_help;;
    T) ArgTarget=${OPTARG};;
    E) ArgEnvironment=${OPTARG};;
    R) ArgRepoType=${OPTARG};;
    V) ArgVersion=${OPTARG};;
    S) ArgSource=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done

ivlfldr_code_version="${ArgVersion}"

Log "checking version"

#Check tussen VERSION (parameter) en oemm_script_version => moeten gelijk zijn
if [ ! "${ivlrun_fldrsync_main_script_version}" = "${ArgVersion}" ]; then
  Log "Wrong version of script. (${ivlrun_fldrsync_main_script_version} vs ${ArgVersion})"
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
if [ ! "${ArgEnvironment}" = "ACC" ] && [ ! "${ArgEnvironment}" = "SIM" ] && [ ! "${ArgEnvironment}" = "PRD" ] && [ ! "${ArgEnvironment}" = "SIC" ]; then
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

# Check Source
if [ "${ArgSource}" = "X" ]; then
    Log "Missing -S parameter. Use -h for help."
    exit 1
    #Failure "bad options."
fi

# Step 1: get the settings for the source repository

# to get the proper settings for the source we assign that value to the target (cfr properties file)
ivlfldr_target="${ArgTarget}"
ivlfldr_env="${ArgSource}"
ivlfldr_repotype="RT"

Log "##############################"
Log "Source definition and settings"
Log "##############################"
Log $ivlfldr_target
Log $ivlfldr_env
Log $ivlfldr_repotype
Log "##############################"

# Load the values used in the code according the information given as parameter
LoadIniFiles
Log "Started with the Folder Sync settings on source: ${ivlfldr_env}"

getRTSettings
Log "Started with the Folder Sync groovy on source: ${ivlfldr_env}"

DoODIFolderSync_GetFolders

################################################
## END STEP 1 
################################################

# Step 2: set the settings for the target repository

ivlfldr_target="${ArgTarget}"
ivlfldr_env="${ArgEnvironment}"
ivlfldr_repotype="${ArgRepoType}"

Log "##############################"
Log "Target definition and settings"
Log "##############################"
Log $ivlfldr_target
Log $ivlfldr_env
Log $ivlfldr_repotype
Log "##############################"

# Load the values used in the code according the information given as parameter
LoadIniFiles

Log "Started with the Folder Sync on target : ${ivlfldr_env}"

if [ "${ArgRepoType}" == "OEMM" ]; then
   # Check if ivloem is active on this environment
   if [ "${OdiOEMMActive}" = "NO" ]; then
      Log "IVL RT for ${ivlfldr_target}/${ivlfldr_env} is inactive according to the properties files. Nothing to do."
      exit 0
   fi

   getOEMMSettings

fi

if [ "${ArgRepoType}" == "RT" ]; then
   # Check if ivloem is active on this environment
   if [ "${OdiRTActive}" = "NO" ]; then
      Log "IVL RT for ${ivlfldr_target}/${ivlfldr_env} is inactive according to the properties files. Nothing to do."
      exit 0
   fi

   getRTSettings

fi

DoODIFolderSync_SetFolders

################################################
## END STEP 2
################################################


exit 0

