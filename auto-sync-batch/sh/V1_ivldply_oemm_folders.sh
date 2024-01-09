#!/bin/bash
#### V1_ivldply_oemm_folders.sh script
# This script is to be run from ths main script ivlrun_oemm_dply.sh
#
# Command line options:
# option          mand.     value (all values are case sensitive!!!)
# -T<target>        YES      the target application, either "IVL" or "CIVL"
# -E<environment>   YES      the target Environment, either "ACC","SIM","PRD","SIC"
# -V<version>       YES      the version should be the same as the script version
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Jan/2021      # 1.0.0   # initial version
# visv  # May/2021      # 1.1.0   # added cleanup functionality
#############################################################################
ivlrun_oemm_main_script_version="V1"

SetLogFile()
{

LOG_FILE="${ivllog}/IVLDPLY_OEMM_FOLDER_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

LogIWSInfo() {
echo "IWS related info:" >> $LOG_FILE
echo "Workstation: $UNISON_HOST" >> $LOG_FILE
echo "Jobname:     $UNISON_JOB" >> $LOG_FILE
echo "Jobnumber:   $UNISON_JOBNUM" >> $LOG_FILE
echo "Run number:  $UNISON_RUN" >> $LOG_FILE
echo "End of IWS related info" >> $LOG_FILE
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
  source ${ivlini}/${ivloem_code_version}_ivl_dply.properties
  source ${ivlini}/${ivloem_code_version}_ivl_dply_credentials.properties
}


DoCleanupFolder()
{
  SUBROUTINE=$0
  source ${ivlsh}/${ivloem_code_version}_ivldply_functions.sh

  ivldply_initialize

  # Check if archive directory exist
  if [ ! -d ${ivloem_arch_dir} ]; then
    Log "ProcessFolder: parameter ivloem_arch_dir ${ivloem_arch_dir} bestaat niet en kan dus niet gecleaned worden"
    exit 0
  fi

  Log "Start with cleanup folder: ${ivloem_arch_dir}"
  cd ${ivloem_arch_dir}
  
  export days_changed=30

  for clear_directory in $(find ${ivloem_arch_dir} -name "DT*" -type d -mtime +${days_changed})
  do 
    Log "remove: ${clear_directory}"
    rm -rf ${clear_directory}

    RC=$?
    if [ $RC -ne 0 ]; then
      ## we have an error, return to caller
      Log "There was an error during the cleanup"
      exit 1
    fi
  done
  Log "End Cleanup folder: ${ivloem_arch_dir}"

}

DoProcessFolder()
{

  SUBROUTINE=$0
  source ${ivlsh}/${ivloem_code_version}_ivldply_functions.sh

  ivldply_initialize

  # Check the status file first
  # Should be set to START or RESTART

  ivloem_status_file_content="unkonwn"
  
  ReadOEMMStatusFile
  
  if [ ! $ivldply_error == "0" ]; then
    Log "There was an error reading the status file"
    Failure "OEMMM folder processing failed with error $ivldply_error"
  fi

  # Check if the config file does contain a START and not a STOP or ERROR
  if [ ! "${ivloem_status_file_content}" = "${ivloem_status_start}" ] && [ ! "${ivloem_status_file_content}" = "${ivloem_status_restart}" ]; then
     Log "Status file content not set to start for the oemm deploy: ${ivloem_status_file_content}"
     exit 0
  fi

  Log "Source directory: "${ivloem_src_dir}

  ivloem_status_after_deploy="${ivloem_status_file_content}"

  # Set the status to running in the config file
  ivloem_new_status="${ivloem_status_running}"
  SetOEMMStatusFile 
  
  if [ ! $ivldply_error == "0" ]; then
    Log "There was an error during the set of the status file to running"
    Failure "OEMMM folder processing failed with error $ivldply_error"
  fi
  
  # Process now the folders, all checks should be ok now

  ProcessFolder

  if [ ! $ivldply_error == "0" ]; then
 
    Log "There was an error during the execution of the OEMM folder processing"

	ivloem_new_status="${ivloem_status_error}"
    SetOEMMStatusFile 
  
    if [ ! $ivldply_error == "0" ]; then
      Log "There was an error during the set of the status file to running"
      exit 1
      #Failure "OEMMM folder processing failed with error $ivldply_error"
    fi

    exit 1
    # Failure "OEMMM folder processing failed with error $ivldply_error"
 
  else  

    # Set the status to Start in the config file
    ivloem_new_status="${ivloem_status_after_deploy}"
    SetOEMMStatusFile
  
  fi

  if [ ! $ivldply_error == "0" ]; then
    Log "There was an error during the set of the status file again to start"
    exit 1
    #Failure "OEMMM folder processing failed with error $ivldply_error"
  fi
}

SetLogFile

LogIWSInfo

Initialise

## process command line options

ArgTarget="X"
ArgAction="X"
ArgEnvironment="X"

Log "Parsing options ..."
while getopts :hT:E:V: option; do
  case $option
    in
    h) print_help;;
    T) ArgTarget=${OPTARG};;
    E) ArgEnvironment=${OPTARG};;
	V) ArgVersion=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done

Log "checking version"

#Check tussen VERSION (parameter) en oemm_script_version => moeten gelijk zijn
if [ ! "${ivlrun_oemm_main_script_version}" = "${ArgVersion}" ]; then
  Log "Wrong version of script. (${ivlrun_oemm_main_script_version} vs ${ArgVersion})" 
  exit 1
#  Failure "bad version."
fi 

ivloem_code_version="${ArgVersion}"

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
  Log "Invalid value for -E parameter. Only ACC, SIM, PRD or SIC are allowed. Use -h for help."
  exit 1
  #Failure "bad options."
fi

Log "Started with process"

ivloem_target="${ArgTarget}"
ivloem_env="${ArgEnvironment}"

# Load the values used in the code according the information given as parameter
LoadIniFiles

# Check if ivloem is active on this environment
if [ "${ivloem_active}" = "NO" ]; then
  Log "IVL OEMM for ${ivloem_target}/${ivloem_env} is inactive according to the properties files. Nothing to do."
  exit 0
fi

# Check if directory is available
if [ ! -d $ivloem_src_dir ]; then
  Log "IVL OEMM directory ${ivloem_src_dir} does not exist"
  exit 0
fi

Log "Started cleanup folder"

DoCleanupFolder

Log "Started with Process folder"

DoProcessFolder

exit 0

