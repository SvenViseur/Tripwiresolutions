#!/bin/bash
#### runSchedule.sh script
# This script is to be run from IWS using /cola/run
# typical call is:
#
# /cola/run tblsh runSchedule.sh <options>
#
# Command line options:
# option          mand.     value (all values are case sensitive!!!)
# -S<site>         ALL      the site in Tableau to connect to
# -C<schedule>     ALL      the schedule to access (can contain spaces or the & character)
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Aug/2021      # 1.0.0   # Initial version
#############################################################################
#

SetLogFile()
{

LOG_FILE="${tbllog}/runSchedule_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
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

}

LoadIniFiles()
{
  source ${tblini}/talex.properties
  source ${tblini}/talex_cred.properties

}

DoRunSchedule()
{
  SUBROUTINE=$0
  source ${tblsh}/talex_functions.sh

  talex_contentUrl="$ArgSite"
  talex_schedule_name="$Argschedule"
  talex_max_age=1

  talex_temp_folder="${tbltmp}/J${UNISON_JOBNUM}"
  rm -rf ${talex_temp_folder}
  mkdir -p ${talex_temp_folder}

  declare -a talex_job_ids
  talex_job_ids=()

  talex_initialize

  Log "calling talex_get_token"
  talex_get_token
  Log "returned from talex_get_token"
  Log "talex_error=$talex_error"

  if [ ! $talex_error == "0" ]; then
    Log "talex_contentUrl     = $talex_contentUrl"
    Log "talex_tableau_url    = $talex_tableau_url"
    Log "talex_usr            = $talex_usr"
    Log "talex_api_vrs        = $talex_api_vrs"
    Failure "failed to obtain token (errorid: ${talex_error}) \n ${talex_error_msg}"
  fi

  Log "calling talex_get_schedule_id"
  talex_get_schedule_id
  Log "returned from talex_get_schedule_id"
  Log "talex_error=$talex_error"

  if [ ! $talex_error == "0" ]; then
    Log "talex_contentUrl     = $talex_contentUrl"
    Log "talex_tableau_url    = $talex_tableau_url"
    Log "talex_usr            = $talex_usr"
    Log "talex_api_vrs        = $talex_api_vrs"
    Log "talex_schedule_name  = $talex_schedule_name"
    Failure "failed to obtain schedule id (error: ${talex_error}) \n ${talex_error_msg}"
  fi

  # Get the extract tasks only
  talex_get_extract_tasks
  Log "returned from talex_get_extract_tasks"
  Log "flow retrieved $talex_schedule_flow"
  Log "talex_error=$talex_error"

  if [ ! $talex_error == "0" ]; then
    Log "talex_contentUrl         = $talex_contentUrl"
    Log "talex_tableau_url        = $talex_tableau_url"
    Log "talex_usr                = $talex_usr"
    Log "talex_api_vrs            = $talex_api_vrs"
    Log "talex_schedule_name      = $talex_schedule_name"
    Log "talex_schedule_id        = $talex_schedule_id"
    Failure "failed to get the extract tasks error: ${talex_error}) \n ${talex_error_msg}"
  fi

  if [ "$talex_schedule_flow" == "Parallel" ]
  then

  # If the schedule is defined as parallel, we can execute the extract tasks in batch, ordered by priority

    talex_launch_extract_tasks_parallel
    Log "returned from talex_launch_extract_tasks_parallel"
    Log "talex_error=$talex_error"

    if [ ! $talex_error == "0" ]; then
      Log "talex_contentUrl         = $talex_contentUrl"
      Log "talex_tableau_url        = $talex_tableau_url"
      Log "talex_usr                = $talex_usr"
      Log "talex_api_vrs            = $talex_api_vrs"
      Log "talex_schedule_name      = $talex_schedule_name"
      Log "talex_schedule_id        = $talex_schedule_id"
      Failure "failed to launch extract tasks Parallel (error: ${talex_error})  \n ${talex_error_msg}"
    fi

    talex_check_job_status
    Log "returned from talex_check_job_status"
    Log "talex_error=$talex_error"

    if [ ! $talex_error == "0" ]; then
      Log "talex_contentUrl         = $talex_contentUrl"
      Log "talex_tableau_url        = $talex_tableau_url"
      Log "talex_usr                = $talex_usr"
      Log "talex_api_vrs            = $talex_api_vrs"
      Log "talex_schedule_name      = $talex_schedule_name"
      Log "talex_schedule_id        = $talex_schedule_id"
      Failure "failed to check jobs parallel (error: ${talex_error})  \n ${talex_error_msg}"
    fi

  else

  # If the schedule is defined as parallel, we can execute the extract tasks in batch, ordered by priority

    talex_launch_extract_tasks_serial
    Log "returned from talex_launch_extract_tasks_parallel"
    Log "talex_error=$talex_error"

    if [ ! $talex_error == "0" ]; then
      Log "talex_contentUrl         = $talex_contentUrl"
      Log "talex_tableau_url        = $talex_tableau_url"
      Log "talex_usr                = $talex_usr"
      Log "talex_api_vrs            = $talex_api_vrs"
      Log "talex_schedule_name      = $talex_schedule_name"
      Log "talex_schedule_id        = $talex_schedule_id"
      Failure "failed to launch extract tasks Parallel (error: ${talex_error})  \n ${talex_error_msg}"
    fi

   # If the schedule is defined as Serial, we  execute the extract tasks in serial, ordered by priority

  fi

  rm -rf ${talex_temp_folder}
}

SetLogFile

LogIWSInfo

Initialise

## process command line options

ArgSite="X"
Argschedule="X"

Log "Parsing options ..."
while getopts :hS:C: option; do
  case $option
    in
    h) print_help;;
    S) ArgSite=${OPTARG};;
    C) Argschedule=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done

if [ "${ArgSite}" = "X" ]; then
  Log "Missing -S <Site> parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${Argschedule}" = "X" ]; then
  Log "Missing -C <schedule name> parameter. Use -h for help."
  Failure "bad options."
fi

LoadIniFiles

# Check if talex/tableau exists on this environment
if [ "${talex_active}" = "NO" ]; then
  Log "talex is inactive according to the properties files. Nothing to do."
  exit 0
fi

DoRunSchedule
exit 0

