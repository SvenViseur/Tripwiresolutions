# ivlclean_functions.sh
# A library of callable functions to interact with IVL servers
# to run scenarios or load plans
#
#
#
#################################################################
# Change history
#################################################################
# dexa  # Oct/2020    #   1.0.0  # initial version
#################################################################
ivlclean_Functions_ScriptVersion="1.0.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   ivlclean_usr                  : the userid
#   ivlclean_psw                  : the password
#   ivlclean_master_usr           : the master userid
#   ivlclean_master_psw           : the master password
#   ivlclean_jdbc_odi_url         : the jdbc odi URL string
#   ivlclean_default_odi_agent    : the default ODI agent
#   ivlclean_default_context      : the default context
#
# Mandatory option for most calls:
#   ivlclean_target               : either "IVL" or "CIVL"
#   ivlclean_groovy_folder        : the location where the groovy code resides
#
#
# General option is ivlclean_debug. Set this to "1" and you will get extra info
#
# Each call uses the $ivlclean_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

ivlclean_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

ivlclean_make_Log_work

ivlclean_error="0"
ivlclean_initialized="1"
}

ivlclean_make_Log_work() {
# Internal function. If the function Log exists or if Log is an alias, then do nothing
# If Log is not a function nor an alias, the set Log as an alias of echo
if [ -n "$(LC_ALL=C type -t Log)" ] && [ "$(LC_ALL=C type -t Log)" = "function" ]; then
  return
fi
if [ -n "$(LC_ALL=C type -t Log)" ] && [ "$(LC_ALL=C type -t Log)" = "alias" ]; then
  return
fi
echo "Log will be set as a function that simply calls echo"

  Log() {
    echo "$1"
  }
}

LogDebug() {
if [ "$ivlclean_debug" = "1" ]; then
  Log "$1"
fi
}

runODICleanup() {

# OUT: ivlclean_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivlclean_initialized" = "1" ]; then
  ivlclean_error="not_initialized"
  return
fi

Log "temp folder:"${ivlclean_temp_folder}

ivlclean_log_file="${ivlclean_temp_folder}/run_clean.log"
touch $ivlclean_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in runODICleanup: Could not create temporary file (error=${RC})."
  ivlclean_error=$RC
  return
fi
if [ -z $ODI_URL ]; then
  Log "Error in runODICleanup: parameter ODI_URL is verplicht"
  ivlclean_error=999
  return
fi
if [ -z $ODI_MASTER_USER ]; then
  Log "Error in runODICleanup: parameter ODI_MASTER_USER is verplicht"
  ivlclean_error=999
  return
fi
if [ -z $ODI_USER ]; then
  Log "Error in runODICleanup: parameter ODI_USER is verplicht"
  ivlclean_error=999
  return
fi
if [ -z $GROOVY_CONF ]; then
  Log "Error in ODICleanup: parameter GROOVY_CONF is verplicht"
  ivlclean_error=999
  return
fi
if [ ! -d "${ivlclean_temp_folder}" ]; then
  ## we have an error, return to caller
  Log "Error in runODICleanup: Could not find the specified temporary folder '$ivlclean_temp_folder'."
  ivlclean_error=990
  return
fi
ivlclean_log_file="${ivlclean_temp_folder}/run_clean.log"
touch $ivlclean_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in runODICleanup: Could not create temporary file (error=${RC})."
  ivlclean_error=$RC
  return
fi

Log "${ivlclean_groovy_path}/groovy $ivlclean_groovy_folder/${ivlrun_clean_main_script_version}_civl_read_and_remove.groovy -p CIVL -f ${ivlclean_input_file} -t ${ivlclean_cleanuptype}"

Log "logfile="${ivlclean_log_file}
${ivlclean_groovy_path}/groovy $ivlclean_groovy_folder/${ivlrun_clean_main_script_version}_civl_read_and_remove.groovy -p CIVL -f ${ivlclean_input_file} -t ${ivlclean_cleanuptype}  >> ${ivlclean_log_file} 2>&1

RC=$?

Log "DoODICleanup functie beëindigd"

# now send the output of the log file to the Log function

the_log=$(cat ${ivlclean_log_file})
Log "$the_log"
rm $ivlclean_log_file

if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODICleanup: The groovy script encountered an error during execution. Please check the above log."
  ivlclean_error=980
  return
fi

ivlclean_error=0
return
}

