# ivliws_functions.sh
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
ivliws_Functions_ScriptVersion="1.0.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   ivliws_usr                  : the userid
#   ivliws_psw                  : the password
#   ivliws_master_usr           : the master userid
#   ivliws_master_psw           : the master password
#   ivliws_jdbc_odi_url         : the jdbc odi URL string
#   ivliws_default_odi_agent    : the default ODI agent
#   ivliws_default_context      : the default context
#
# Mandatory option for most calls:
#   ivliws_target               : either "IVL" or "CIVL"
#   ivliws_groovy_folder        : the location where the groovy code resides
#
#
# General option is ivliws_debug. Set this to "1" and you will get extra info
#
# Each call uses the $ivliws_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

ivliws_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

ivliws_make_Log_work

ivliws_error="0"
ivliws_initialized="1"
}

ivliws_make_Log_work() {
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
if [ "$ivliws_debug" = "1" ]; then
  Log "$1"
fi
}

RunLoadplan() {

#
# IN: ivliws_usr                 : username
#     ivliws_psw                 : password
#     ivliws_odi_loadplan        : the load plan to run
#     ivliws_default_context     : the context to use
#     ivliws_default_odi_agent   : the agent to use
#     ivliws_loglevel            : the loglevel (1-6) to use
#     ivliws_target              : either "IVL" or "CIVL"
#     ivliws_jdbc_odi_url        : the jdbc connection string to the odi server
#     ivliws_groovy_conf         : the location of the groovy conf file
#     ivliws_groovy_folder       : the location where the groovy code resides
#     ivliws_timeout_minutes     : the timeout value after which to fail if execution is not ended
#     ivliws_temp_folder         : an empty temp folder that may be used
#     ivliws_odi_parameters      : array with all parameters used if needed
#
# OUT: ivliws_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivliws_initialized" = "1" ]; then
  ivliws_error="not_initialized"
  return
fi
if [ -z $ivliws_jdbc_odi_url ]; then
  Log "Error in RunLoadplan: parameter ivliws_jdbc_odi_url is verplicht"
  ivliws_error=999
  return
fi
if [ -z $ivliws_master_user ]; then
  Log "Error in RunLoadplan: parameter ivliws_master_user is verplicht"
  ivliws_error=999
  return
fi
if [ -z $ivliws_user ]; then
  Log "Error in RunLoadplan: parameter ivliws_user is verplicht"
  ivliws_error=999
  return
fi
if [ -z $ivliws_groovy_conf ]; then
  Log "Error in RunLoadplan: parameter ivliws_groovy_conf is verplicht"
  ivliws_error=999
  return
fi
if [ -z $ivliws_temp_folder ]; then
  Log "Error in RunLoadplan: parameter ivliws_temp_folder is verplicht"
  ivliws_error=999
  return
fi

export ODI_URL="${ivliws_jdbc_odi_url}"
export ODI_MASTER_USER="${ivliws_master_user}"
export ODI_MASTER_PWD="${ivliws_master_psw}"
export ODI_WORKREP="WORKREP"
export ODI_USER="${ivliws_user}"
export ODI_PWD="${ivliws_psw}"
export GROOVY_CONF="${ivliws_groovy_conf}"

if [ ! -d "${ivliws_temp_folder}" ]; then
  ## we have an error, return to caller
  Log "Error in RunLoadplan: Could not find the specified temporary folder '$ivliws_temp_folder'."
  ivliws_error=990
  return
fi
ivliws_log_file="${ivliws_temp_folder}/run_lp.log"
touch $ivliws_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in RunLoadplan: Could not create temporary file (error=${RC})."
  ivliws_error=$RC
  return
fi

for param_element in "${ivliws_odi_parameters[@]}"
do
   echo $param_element >> ${ivliws_temp_folder}/parameter_file.par
done

ivliws_groovy_parameter_line=${ivliws_odi_loadplan}"#"${ivliws_default_context}"#"${ivliws_default_odi_agent}"#"${ivliws_loglevel}"#"${ivliws_default_wait}

Log "starting groovy script odi_run_lp.groovy ..."
echo "Logfile started - Starting script odi_run_lp.groovy" > ${ivliws_log_file}

#export JAVA_OPTS="-Xmx1g"
#export JAVA_OPTS="-Xms512m -Xmx1024m"

# tune glibc memory allocation, optimize for low fragmentation
# limit the number of arenas
#export MALLOC_ARENA_MAX=4
# disable dynamic mmap threshold, see M_MMAP_THRESHOLD in "man mallopt"
#export MALLOC_MMAP_THRESHOLD_=131072
#export MALLOC_TRIM_THRESHOLD_=131072
#export MALLOC_TOP_PAD_=131072
#export MALLOC_MMAP_MAX_=65536

#65536 -> 16384
#131072 -> 32768

#export JAVA_OPTS="-Xss1024k -XX:+DisableExplicitGC -XX:+HeapDumpOnOutOfMemoryError -XX:+UseParallelGC -XX:GCTimeRatio=9 -XX:MaxMetaspaceSize=512m -Xms128m -Xmx1024m"

#export JAVA_OPTS="-Xmx256m"

if [ -f ${ivliws_temp_folder}/parameter_file.par ]
then
   ${ivliws_groovy_path}/groovy $ivliws_groovy_folder/odi_run_lp.groovy -p ${ivliws_groovy_parameter_line} -i ${ivliws_temp_folder}/parameter_file.par >> ${ivliws_log_file} 2>&1
else
   ${ivliws_groovy_path}/groovy $ivliws_groovy_folder/odi_run_lp.groovy -p ${ivliws_groovy_parameter_line} >> ${ivliws_log_file} 2>&1
fi

RC=$?

# now send the output of the log file to the Log function

the_log=$(cat ${ivliws_log_file})
Log "$the_log"
rm $ivliws_log_file

if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in RunLoadplan: The groovy script encountered an error during execution. Please check the above log."
  ivliws_error=980
  return
fi

ivliws_error=0
return
}

