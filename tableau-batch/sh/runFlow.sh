#!/bin/bash
#### runFlow.sh script
# This script is to be run from IWS using /cola/run
# typical call is:
#
# /cola/run tblsh runFlow.sh <options>
#
# Command line options:
# option          mand.     value (all values are case sensitive!!!)
# -S<site>         ALL      the site in Tableau to connect to
# -F<flow>         ALL      the name of the flow
# -J<project>      ALL      the project in Tableau where the flow reside
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Mar/2022      # 1.0.0   # Initial version
#############################################################################
#

SetLogFile()
{

LOG_FILE="${tbllog}/runFlow_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
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

DoRunFlow()
{
  SUBROUTINE=$0
  source ${tblsh}/talex_functions.sh

  talex_contentUrl="$ArgSite"
  talex_flow_name="$ArgFlow"
  talex_project_name="$ArgProject"
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
    Failure "failed to obtain token (error: ${talex_error}) \n ${talex_error_msg}"
  fi

  Log "calling talex_get_flow_id"
  talex_get_flow_id
  Log "returned from talex_get_flow_id"
  Log "talex_error=$talex_error"

  if [ ! $talex_error == "0" ]; then
    Log "talex_contentUrl       = $talex_contentUrl"
    Log "talex_tableau_url      = $talex_tableau_url"
    Log "talex_usr              = $talex_usr"
    Log "talex_api_vrs          = $talex_api_vrs"
    Log "talex_project_name     = $talex_project_name"
    Log "talex_flow_name  = $talex_flow_name"
    Failure "failed to obtain flow id (error: ${talex_error}) \n ${talex_error_msg}"
  fi

  # Refresh flow
  talex_refresh_flow_id
  Log "returned from talex_refresh_flow_id"
  Log "talex_error=$talex_error"

  if [ ! $talex_error == "0" ]; then
    Log "talex_contentUrl           = $talex_contentUrl"
    Log "talex_tableau_url          = $talex_tableau_url"
    Log "talex_usr                  = $talex_usr"
    Log "talex_api_vrs              = $talex_api_vrs"
    Log "talex_project_name         = $talex_project_name"
    Log "talex_flow_name            = $talex_flow_name"
    Log "talex_flow_id              = $talex_flow_id"
    Failure "failed to refresh a flow id (error: ${talex_error}) \n ${talex_error_msg}"
  fi

  rm -rf ${talex_temp_folder}
}


SetLogFile

LogIWSInfo

Initialise

## process command line options

ArgSite="X"
ArgFlow="X"
ArgProject="X"

Log "Parsing options ..."
while getopts :hS:F:J: option; do
  case $option
    in
    h) print_help;;
    S) ArgSite=${OPTARG};;
    F) ArgFlow=${OPTARG};;
    J) ArgProject=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done
if [ "${ArgSite}" = "X" ]; then
  Log "Missing -S parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgFlow}" = "X" ]; then
  Log "Missing -F parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgProject}" = "X" ]; then
  Log "Missing -J parameter. Use -h for help."
  Failure "bad options."
fi

LoadIniFiles

# Check if talex/tableau exists on this environment
if [ "${talex_active}" = "NO" ]; then
  Log "talex is inactive according to the properties files. Nothing to do."
  exit 0
fi

DoRunFlow

exit 0

