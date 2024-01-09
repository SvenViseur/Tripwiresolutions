#!/bin/bash
#### ivliws_run_loadplan.sh script
# This script is to be run from IWS using /cola/run
# typical call is:
#
# /cola/run ivlsh ivliws_run_loadplan.sh <options>
#
# Command line options:
# option          mand.     value (all values are case sensitive!!!)
# -T<target>        YES      the target application, either "IVL" or "CIVL"
# -P<loadplan>      YES      the loadplan or scenario to run
# -L<loglevel>      NO       the loglevel, value from 1 to 6
#
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Oct/2020      # 1.0.0   # initial version
# visv  # Aug/2021      # 1.1.0   # Added parameters
#############################################################################
SetLogFile()
{

LOG_FILE="${ivllog}/runLoadplan_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE
export >> $LOG_FILE

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
  source ${ivlini}/ivl_loadplan.properties
  source ${ivlini}/ivl_loadplan_cred.properties

}

DoRunLoadplan()
{

  SUBROUTINE=$0
  source ${ivlsh}/ivliws_functions.sh

  ivliws_loglevel=${ivliws_default_loglevel}
  if [ ! "${ArgLogLevel}" = "X" ]; then
    ivliws_loglevel=${ArgLogLevel}
  fi
  ivliws_odi_loadplan="${ArgLoadplan}"
  ivliws_groovy_folder="/${platform}/ivl/lib"
  ivliws_groovy_conf="${ivlini}/ivliws-groovy-${ivliws_target^^}.cfg"

  ivliws_temp_folder="${ivltmp}/J${UNISON_JOBNUM}"

  if [ ! "$ArgParamFile" == "X" ]
  then
    if [ -f $ArgParamFile ]
    then
      while read line
      do
        ArgParam=("${ArgParam[@]}" "$line")
      done < $ArgParamFile

      ivliws_reading_error=$?
      if [ $ivliws_reading_error -ne 0 ]
      then
        Log "There was an error reading $ArgParamFile ($ivliws_reading_error)"
        Failure "Error reading $ArgParamFile ($ivliws_reading_error)"
      fi
    else
      Log "There was an error with the parameter file: $ArgParamFile does not exist."
      Failure "File $ArgParamFile does not exist"
    fi
  fi

  declare -a ivliws_odi_parameters

  for param_element in "${ArgParam[@]}"
  do
     ivliws_odi_parameters=("${ivliws_odi_parameters[@]}" "$param_element")
  done

  rm -rf ${ivliws_temp_folder}
  mkdir -p ${ivliws_temp_folder}

  ivliws_initialize

  RunLoadplan

  if [ ! $ivliws_error == "0" ]; then
    Log "There was an error during the execution of the Loadplan."
    Failure "Loadplan failed with error $ivliws_error"
  fi
  rm -rf ${ivliws_temp_folder}

}

SetLogFile

LogIWSInfo

Initialise

## process command line options

ArgTarget="X"
ArgLogLevel="X"
ArgLoadplan="X"
ArgParamFile="X"
declare -a ArgParam

Log "Parsing options ..."

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h)
       print_help;;
    -T)
       ArgTarget=$2
       shift ;;
    -L)
       ArgLogLevel=$2
       shift ;;
    -P)
       ArgLoadplan=$2
       shift ;;
    -I0)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I1)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I2)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I3)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I4)
       ArgParam=("${ArgParam[@]}" "$2") 
       shift ;;
    -I5)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I6)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I7)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I8)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -I9)
       ArgParam=("${ArgParam[@]}" "$2")
       shift ;;
    -If)
       ArgParamFile=$2
       shift ;;
esac
shift

done

if [ "${ArgTarget}" = "X" ]; then
  Log "Missing -T parameter. Use -h for help."
  Failure "bad options."
fi
if [ ! "${ArgTarget}" = "CIVL" ] && [ ! "${ArgTarget}" = "IVL" ]; then
  Log "Invalid value for -T parameter. Only CIVL or IVL are allowed. Use -h for help."
  Failure "bad options."
fi
if [ ! "${ArgLogLevel}" = "X" ]; then
  if ! [[ "${ArgLogLevel}" =~ ^[1-6]$ ]]; then
    Log "Invalid value for -L parameter. Only 1 to 6 allowed. Use -h for help."
    Failure "bad options."
  fi
fi
if [ "${ArgLoadplan}" = "X" ]; then
  Log "Missing -P parameter. Use -h for help."
  Failure "bad options."
fi

ivliws_target="${ArgTarget}"

LoadIniFiles

# Check if ivliws is active on this environment
if [ "${ivliws_active}" = "NO" ]; then
  Log "IVL IWS is inactive according to the properties files. Nothing to do."
  exit 0
fi

DoRunLoadplan

exit 0


