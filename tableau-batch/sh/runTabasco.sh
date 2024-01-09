#!/bin/bash
#### runTabasco script
# This script is to be run from IWS using /cola/run
# typical call is:
#
# /cola/run tblsh runTabasco.sh <options>
#
# Command line options:
# option          mand.     value (all values are case sensitive!!!)
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Sep/2021      # 1.0.0   # Initial version
#############################################################################
#

SetLogFile()
{

LOG_FILE="${tbllog}/runTabasco_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
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

DoTabasco()
{
  SUBROUTINE=$0
  source ${tblsh}/talex_functions.sh

  talex_temp_folder="${tbltmp}/J${UNISON_JOBNUM}"
  
  rm -rf ${talex_temp_folder}
  mkdir -p ${talex_temp_folder}

  declare -a talex_job_ids
  talex_job_ids=()

  talex_initialize

  ## check if file Sites exists
  if [ ! -f "${tbltabasco_sites}" ]; then
    Failure "File ${tbltabasco_sites} does not exist"
  fi
 
  while read -r talex_contentUrl;
  do

    Log "calling talex_get_token for contentUrl: ${talex_contentUrl}"
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

    runTabasco

  done < ${tbltabasco_sites}

  rm -rf ${talex_temp_folder}
}


SetLogFile

LogIWSInfo

Initialise

Log "Started Tabasco"

## process command line options

LoadIniFiles

# Check if talex/tableau exists on this environment
if [ "${talex_active}" = "NO" ]; then
  Log "Tabasco is inactive according to the properties files. Nothing to do."
  exit 0
fi

DoTabasco

Log "Script executed"

exit 0

