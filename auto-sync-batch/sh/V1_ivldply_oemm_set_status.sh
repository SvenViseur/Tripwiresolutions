#!/bin/bash
#### ivldply_oemm_set_status.sh script
# This script is to be run from ths main script ivlrun_oemm_dply.sh
#
# Command line options:
# option          mand.     value (all values are case sensitive!!!)
# -T<target>        YES      the target application, either "IVL" or "CIVL"
# -E<environment>   YES      the target Environment, either "ACC","SIM","PRD","SIC"
# -V<version>       YES      the version should be the same as the script version
# -A<action>        YES      Set the correct action to the config file: STOP,START,RESTART
#
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Jan/2021      # 1.0.0   # initial version
#############################################################################
ivlrun_oemm_main_script_version="V1"

SetLogFile()
{

LOG_FILE="${ivllog}/OEMM_dply_status_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
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
}

DoReadOEMMStatusFile()
{

  SUBROUTINE=$0
  source ${ivlsh}/${ivloem_code_version}_ivldply_functions.sh

  ivldply_initialize

  ivloem_status_file_content="unknown"

  ReadOEMMStatusFile_Status

  if [ ! $ivldply_error == "0" ]; then
    Log "There was an error during the set of the status file again to start"
    Failure "OEMMM folder processing failed with error $ivldply_error"
  fi

}

DoSetOEMMStatusFileStart()
{

# Set the status to START

  SUBROUTINE=$0
  source ${ivlsh}/${ivloem_code_version}_ivldply_functions.sh

  ivldply_initialize

  ivlchange_status="NO"
  ivloem_new_status="${ivloem_status_start}"


  Log "Current status : " ${ivloem_status_file_content}

  if [ "${ivloem_status_file_content}" = "${ivloem_status_stop}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already STOPPED" 
    ivlchange_status="YES"
  fi
  if [ "${ivloem_status_file_content}" = "unknown" ]; then
    Log "OEMM Status change initialized and set to ${ivloem_new_status}"
    ivlchange_status="YES"
  fi

  if [ "${ivloem_status_file_content}" = "${ivloem_status_start}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already START" 
    ivlchange_status="NO"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_restart}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already RESTART" 
    ivlchange_status="NO"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_running}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already RUNNNING" 
    ivlchange_status="NO"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_error}" ]; then
    ivlchange_status="NO"
    Log "OEMM status in Error. Should be changed by RESTART"
	exit 1
  fi

  if [ "${ivlchange_status}" = "YES" ]; then
    Log "OEMM Status change from ${ivloem_status_file_content} to ${ivloem_new_status}"
    SetOEMMStatusFile
    if [ ! $ivldply_error == "0" ]; then
      Log "There was an error during the set of the status file to ${ivloem_new_status}"
      Failure "OEMMM status processing failed with error $ivldply_error"
    fi
  fi


}

DoSetOEMMStatusFileStop()
{

# Set the status to STOP 

  SUBROUTINE=$0
  source ${ivlsh}/${ivloem_code_version}_ivldply_functions.sh

  ivldply_initialize

  ivlchange_status="NO"
  ivloem_new_status="${ivloem_status_stop}"

  Log "Current status : " ${ivloem_status_file_content}

  if [ "${ivloem_status_file_content}" = "${ivloem_status_stop}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already STOPPED" 
	exit 0
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_start}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already START" 
    ivlchange_status="YES"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_restart}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already RESTART" 
    ivlchange_status="YES"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_running}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already RUNNING" 
    ivlchange_status="YES"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_error}" ]; then
    Log "OEMM status in Error. Should be changed by RESTART"
    ivlchange_status="NO"
	exit 1
  fi

  if [ "${ivlchange_status}" = "YES" ]; then
    Log "OEMM Status change from ${ivloem_status_file_content} to ${ivloem_new_status}"
    SetOEMMStatusFile
    if [ ! $ivldply_error == "0" ]; then
      Log "There was an error during the set of the status file to ${ivloem_new_status}"
      Failure "OEMMM status processing failed with error $ivldply_error"
    fi
  fi

}

DoSetOEMMStatusFileRestart()
{
# Set the status to RESTART 

  SUBROUTINE=$0
  source ${ivlsh}/${ivloem_code_version}_ivldply_functions.sh

  ivldply_initialize

  ivlchange_status="NO"
  ivloem_new_status="${ivloem_status_restart}"
  
  Log "Current status : " ${ivloem_status_file_content}

  if [ "${ivloem_status_file_content}" = "${ivloem_status_stop}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already STOPPED" 
    ivlchange_status="NO"
	exit 1
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_start}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already START" 
    ivlchange_status="NO"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_restart}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Already RESTART" 
    ivlchange_status="NO"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_running}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: RUNNNING" 
    ivlchange_status="NO"
  fi
  if [ "${ivloem_status_file_content}" = "${ivloem_status_error}" ]; then
    Log "OEMM Status change to ${ivloem_new_status}: Change from ERROR" 
    ivlchange_status="YES"
  fi

  if [ "${ivlchange_status}" = "YES" ]; then
    Log "OEMM Status change from ${ivloem_status_file_content} to ${ivloem_new_status}"
    SetOEMMStatusFile
    if [ ! $ivldply_error == "0" ]; then
      Log "There was an error during the set of the status file to ${ivloem_new_status}"
      Failure "OEMMM status processing failed with error $ivldply_error"
    fi
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
while getopts :hT:E:V:A: option; do
  case $option
    in
    h) print_help;;
    T) ArgTarget=${OPTARG};;
    E) ArgEnvironment=${OPTARG};;
    V) ArgVersion=${OPTARG};;
    A) ArgAction=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done


Log "Param target: "$ArgTarget
Log "Param Environment: "$ArgEnvironment
Log "Param Version: "$ArgVersion
Log "Param Action: "$ArgAction

#Check tussen VERSION (parameter) en oemm_script_version => moeten gelijk zijn
if [ ! "${ivlrun_oemm_main_script_version}" == "${ArgVersion}" ]; then
  Log "Wrong version of script."
  Failure "bad version."
fi

ivloem_code_version="${ArgVersion}"

# Check ArgTarget value
if [ "${ArgTarget}" = "X" ]; then
  Log "Missing -T parameter. Use -h for help."
  Failure "bad options."
fi
if [ ! "${ArgTarget}" = "CIVL" ] && [ ! "${ArgTarget}" = "IVL" ]; then
  Log "Invalid value for -T parameter. Only CIVL or IVL are allowed. Use -h for help."
  Failure "bad options."
fi

# Check ArgEnvironment value
if [ "${ArgEnvironment}" = "X" ]; then
  Log "Missing -E parameter. Use -h for help."
  Failure "bad options."
fi
if [ ! "${ArgEnvironment}" = "ACC" ] && [ ! "${ArgEnvironment}" = "SIM" ] && [ ! "${ArgEnvironment}" = "PRD" ] && [ ! "${ArgEnvironment}" = "SIC" ]; then
  Log "Invalid value for -E parameter. Only ACC, SIM or PRD are allowed. Use -h for help."
  Failure "bad options."
fi

ivloem_target="${ArgTarget}"
ivloem_env="${ArgEnvironment}"

# Load the values used in the code according the information given as parameter
LoadIniFiles

# Check ArgAction value
if [ "${ArgAction}" = "X" ]; then
  Log "Missing -A parameter. Use -h for help."
  Failure "bad options."
fi
if [ ! "${ArgAction}" = "${ivloem_status_stop}" ] && [ ! "${ArgAction}" = "${ivloem_status_start}" ] && [ ! "${ArgAction}" = "${ivloem_status_restart}" ]; then
  Log "${ArgAction}""-""${ivloem_status_stop}""-""${ivloem_status_start}""-""${ivloem_status_restart}"
  Log "Invalid value for -A parameter. Only START, STOP or RESTART are allowed. Use -h for help."
  Failure "bad options."
fi

ivloem_action="${ArgAction}"

if [ ! -d $ivloem_src_dir ]; then
  Log "IVL directory does not exist: "$ivloem_src_dir
fi

# Check if ivliws is active on this environment
if [ "${ivliws_active}" = "NO" ]; then
  Log "IVL IWS is inactive according to the properties files. Nothing to do."
  exit 0
fi

# Check if ivloem is active on this environment
if [ "${ivloem_active}" = "NO" ]; then
  Log "IVL OEMM for ${ivloem_target}/${ivloem_env} is inactive according to the properties files. Nothing to do."
  exit 0
fi

DoReadOEMMStatusFile

case $ivloem_action
  in
  h) print_help;;
  "${ivloem_status_stop}") DoSetOEMMStatusFileStop;;
  "${ivloem_status_start}") DoSetOEMMStatusFileStart;;
  "${ivloem_status_restart}") DoSetOEMMStatusFileRestart;;
  *) Failure "Unknown option $OPTARG given.";;
esac

exit 0

