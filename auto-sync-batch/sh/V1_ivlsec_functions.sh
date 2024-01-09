# ivlsec_functions.sh
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
ivlsec_Functions_ScriptVersion="1.0.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   ivlsec_usr                  : the userid
#   ivlsec_psw                  : the password
#   ivlsec_master_usr           : the master userid
#   ivlsec_master_psw           : the master password
#   ivlsec_jdbc_odi_url         : the jdbc odi URL string
#   ivlsec_default_odi_agent    : the default ODI agent
#   ivlsec_default_context      : the default context
#
# Mandatory option for most calls:
#   ivlsec_target               : either "IVL" or "CIVL"
#   ivlsec_groovy_folder        : the location where the groovy code resides
#
#
# General option is ivlsec_debug. Set this to "1" and you will get extra info
#
# Each call uses the $ivlsec_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

ivlsec_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

ivlsec_make_Log_work

ivlsec_error="0"
ivlsec_initialized="1"
}

ivlsec_make_Log_work() {
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
if [ "$ivlsec_debug" = "1" ]; then
  Log "$1"
fi
}

RunODISecurity() {

# OUT: ivlsec_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivlsec_initialized" = "1" ]; then
  ivlsec_error="not_initialized"
  return
fi

Log "temp folder:"${ivlsec_temp_folder}

ivlsec_log_file="${ivlsec_temp_folder}/run_sec.log"
touch $ivlsec_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODISecurity: Could not create temporary file (error=${RC})."
  ivlsec_error=$RC
  return
fi
if [ -z $ODI_URL ]; then
  Log "Error in ODISecurity: parameter ODI_URL is verplicht"
  ivlsec_error=999
  return
fi
if [ -z $ODI_MASTER_USER ]; then
  Log "Error in ODISecurity: parameter ODI_MASTER_USER is verplicht"
  ivlsec_error=999
  return
fi
if [ -z $ODI_USER ]; then
  Log "Error in ODISecurity: parameter ODI_USER is verplicht"
  ivlsec_error=999
  return
fi
if [ -z $GROOVY_CONF ]; then
  Log "Error in ODISecurity: parameter GROOVY_CONF is verplicht"
  ivlsec_error=999
  return
fi
if [ ! -d "${ivlsec_temp_folder}" ]; then
  ## we have an error, return to caller
  Log "Error in ODISecurity: Could not find the specified temporary folder '$ivlsec_temp_folder'."
  ivlsec_error=990
  return
fi
ivlsec_log_file="${ivlsec_temp_folder}/run_sec.log"
touch $ivlsec_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODISecurity: Could not create temporary file (error=${RC})."
  ivlsec_error=$RC
  return
fi

Log "DoODISecurity functie gestart"

Log "Create users groovy script"
Log "${ivlsec_groovy_path}/groovy $ivlsec_groovy_folder/${ivlrun_sec_main_script_version}_odi_user_create.groovy -f ${user_profile_file} -t ${tech_user_file}"

Log "groovy conf= "$GROOVY_CONF
Log "ODI_MASTER_USER="$ODI_MASTER_USER
Log "ODI_URL="$ODI_URL
Log "ODI_USER="$ODI_USER
Log "ODI_MASTER_PWD="$ODI_MASTER_PWD
Log "ODI_PWD="$ODI_PWD

Log "logfile="${ivlsec_log_file}
${ivlsec_groovy_path}/groovy $ivlsec_groovy_folder/${ivlrun_sec_main_script_version}_odi_user_create.groovy -f ${user_profile_file} -t ${tech_user_file} >> ${ivlsec_log_file} 2>&1

Log "Modify user profile groovy script"
Log "${ivlsec_groovy_path}/groovy $ivlsec_groovy_folder/${ivlrun_sec_main_script_version}_odi_user_profile.groovy -f ${user_profile_file} -p ${iam_odi_file}"

${ivlsec_groovy_path}/groovy $ivlsec_groovy_folder/${ivlrun_sec_main_script_version}_odi_user_profile.groovy -f ${user_profile_file} -p ${iam_odi_file} >> ${ivlsec_log_file} 2>&1

Log "DoODISecurity functie beëindigd"

# now send the output of the log file to the Log function

the_log=$(cat ${ivlsec_log_file})
Log "$the_log"
rm $ivlsec_log_file

if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODISecurity: The groovy script encountered an error during execution. Please check the above log."
  ivlsec_error=980
  return
fi

ivlsec_error=0
return
}

