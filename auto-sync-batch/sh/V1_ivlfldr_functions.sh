# ivlfldr_functions.sh
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
ivlfldr_Functions_ScriptVersion="1.0.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   ivlfldr_usr                  : the userid
#   ivlfldr_psw                  : the password
#   ivlfldr_master_usr           : the master userid
#   ivlfldr_master_psw           : the master password
#   ivlfldr_jdbc_odi_url         : the jdbc odi URL string
#   ivlfldr_default_odi_agent    : the default ODI agent
#   ivlfldr_default_context      : the default context
#
# Mandatory option for most calls:
#   ivlfldr_target               : either "IVL" or "CIVL"
#   ivlfldr_groovy_folder        : the location where the groovy code resides
#
#
# General option is ivlfldr_debug. Set this to "1" and you will get extra info
#
# Each call uses the $ivlfldr_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

ivlfldr_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

ivlfldr_make_Log_work

ivlfldr_error="0"
ivlfldr_initialized="1"
}

ivlfldr_make_Log_work() {
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
if [ "$ivlfldr_debug" = "1" ]; then
  Log "$1"
fi
}

#############################
## Get Folders information ##
#############################

runODIFolderSync_GetFolders() {

# OUT: ivlfldr_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivlfldr_initialized" = "1" ]; then
  ivlfldr_error="not_initialized"
  return
fi

Log "temp folder:"${ivlfldr_temp_folder}

ivlfldr_log_file="${ivlfldr_temp_folder}/run_fldrsync_GetFolders.log"
touch $ivlfldr_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODIFolderSync: Could not create temporary file (error=${RC})."
  ivlfldr_error=$RC
  return
fi

if [ -z $ODI_URL ]; then
  Log "Error in ODIFolderSync: parameter ODI_URL is verplicht"
  ivlfldr_error=999
  return
fi
if [ -z $ODI_MASTER_USER ]; then
  Log "Error in ODIFolderSync: parameter ODI_MASTER_USER is verplicht"
  ivlfldr_error=999
  return
fi
if [ -z $ODI_USER ]; then
  Log "Error in ODIFolderSync: parameter ODI_USER is verplicht"
  ivlfldr_error=999
  return
fi
if [ -z $GROOVY_CONF ]; then
  Log "Error in ODIFolderSync: parameter GROOVY_CONF is verplicht"
  ivlfldr_error=999
  return
fi
if [ ! -d "${ivlfldr_temp_folder}" ]; then
  ## we have an error, return to caller
  Log "Error in ODIFolderSync: Could not find the specified temporary folder '$ivlfldr_temp_folder'."
  ivlfldr_error=990
  return
fi

ivlfldr_file_folders="FLDR_SYNC_INFO.lst"

Log "runODIFolderSync_GetFolders functie gestart"
Log "Start get folders groovy script"
Log "${ivlfldr_groovy_path}/groovy $ivlfldr_groovy_folder/${ivlrun_fldrsync_main_script_version}_civl_folder_get_sync_info.groovy -d ${ivlfldr_folders_directory}/ -f ${ivlfldr_file_folders} -x ${ivlfldr_exclude_folders}"
Log "logfile="${ivlfldr_log_file}

${ivlfldr_groovy_path}/groovy $ivlfldr_groovy_folder/${ivlrun_fldrsync_main_script_version}_civl_folder_get_sync_info.groovy -d ${ivlfldr_folders_directory}/ -f ${ivlfldr_file_folders} -x ${ivlfldr_exclude_folders} >> ${ivlfldr_log_file} 2>&1

Log "runODIFolderSync_GetFolders functie beëindigd"

# now send the output of the log file to the Log function

the_log=$(cat ${ivlfldr_log_file})
Log "$the_log"
rm $ivlfldr_log_file

if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODIFolderSync_GetFolders: The groovy script encountered an error during execution. Please check the above log."
  ivlfldr_error=980
  return
fi

ivlfldr_error=0
return
}

########################
## Set Folder correct ##
########################

runODIFolderSync_SetFolders() {

# OUT: ivlfldr_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivlfldr_initialized" = "1" ]; then
  ivlfldr_error="not_initialized"
  return
fi

Log "temp folder:"${ivlfldr_temp_folder}

ivlfldr_log_file="${ivlfldr_temp_folder}/run_fldrsync_SetFolders.log"
touch $ivlfldr_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODIFolderSync: Could not create temporary file (error=${RC})."
  ivlfldr_error=$RC
  return
fi
if [ -z $ODI_URL ]; then
  Log "Error in ODIFolderSync: parameter ODI_URL is verplicht"
  ivlfldr_error=999
  return
fi
if [ -z $ODI_MASTER_USER ]; then
  Log "Error in ODIFolderSync: parameter ODI_MASTER_USER is verplicht"
  ivlfldr_error=999
  return
fi
if [ -z $ODI_USER ]; then
  Log "Error in ODIFolderSync: parameter ODI_USER is verplicht"
  ivlfldr_error=999
  return
fi
if [ -z $GROOVY_CONF ]; then
  Log "Error in ODIFolderSync: parameter GROOVY_CONF is verplicht"
  ivlfldr_error=999
  return
fi
if [ ! -d "${ivlfldr_temp_folder}" ]; then
  ## we have an error, return to caller
  Log "Error in ODIFolderSync: Could not find the specified temporary folder '$ivlfldr_temp_folder'."
  ivlfldr_error=990
  return
fi

ivlfldr_file_folders="${ivlfldr_folders_directory}/FLDR_SYNC_INFO.lst"

Log "runODIFolderSync_SetFolders functie gestart"
Log "Start Set folders groovy script"
Log "${ivlfldr_groovy_path}/groovy $ivlfldr_groovy_folder/${ivlrun_fldrsync_main_script_version}_civl_folder_set_sync_info.groovy -f ${ivlfldr_file_folders}"
Log "logfile="${ivlfldr_log_file}

${ivlfldr_groovy_path}/groovy $ivlfldr_groovy_folder/${ivlrun_fldrsync_main_script_version}_civl_folder_set_sync_info.groovy -f ${ivlfldr_file_folders} >> ${ivlfldr_log_file} 2>&1

Log "runODIFolderSync_SetFolders functie beëindigd"

# now send the output of the log file to the Log function

the_log=$(cat ${ivlfldr_log_file})
Log "$the_log"
rm $ivlfldr_log_file

if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODIFolderSync_SetFolders: The groovy script encountered an error during execution. Please check the above log."
  ivlfldr_error=980
  return
fi

ivlfldr_error=0
return
}


