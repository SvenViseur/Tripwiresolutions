# ivldply_functions.sh
# A library of callable functions to interact with IVL servers
# to deploy oemm related code
#
#
#
#################################################################
# Change history
#################################################################
# vis  # Jan/2021    #   1.0.0  # initial version
#################################################################
ivldply_Functions_ScriptVersion="1.0.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   ivldply_usr                  : the userid
#   ivldply_psw                  : the password
#   ivldply_master_usr           : the master userid
#   ivldply_master_psw           : the master password
#   ivldply_jdbc_odi_url         : the jdbc odi URL string
#   ivldply_default_odi_agent    : the default ODI agent
#   ivldply_default_context      : the default context
#
# Mandatory option for most calls:
#   ivldply_target               : either "IVL" or "CIVL"
#   ivldply_groovy_folder        : the location where the groovy code resides
#
# General option is ivldply_debug. Set this to "1" and you will get extra info
#
# Each call uses the $ivldply_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

ivldply_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

ivldply_make_Log_work

ivldply_error="0"
ivldply_initialized="1"
}

ivldply_make_Log_work() {
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
if [ "$ivldply_debug" = "1" ]; then
  Log "$1"
fi
}

ProcessFolder() {

#
# IN: ivloem_src_dir                 : source directory to process
#     ivloem_arch_dir                : archive directory
#
# OUT: ivldply_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivldply_initialized" = "1" ]; then
  ivldply_error="not_initialized"
  return
fi
if [ -z $ivloem_src_dir ]; then
  Log "Error in ProcessFolder: parameter ivloem_src_dir is verplicht"
  ivldply_error=999
  return
fi
if [ -z $ivloem_arch_dir ]; then
  Log "Error in ProcessFolder: parameter ivloem_arch_dir is verplicht"
  ivldply_error=999
  return
fi

# Check if src directory = NVT. Indien = NVT, dan stopt de verwerking hier al
if [ "$ivloem_src_dir" = "NVT" ]; then
  Log "Nothing to process for ${ivloem_src_dir}"
  ivldply_error=0
  return
fi

# Check if arch directory value <> NVT (na check of src_dir <> NVT)
if [ "$ivloem_arch_dir" = "NVT" ]; then
  Log "Error in ProcessFolder: parameter ivloem_arch_dir is verplicht"
  ivldply_error=999
  return
fi

# Check if archive directory exist
if [ ! -d ${ivloem_arch_dir} ]; then
  Log "ProcessFolder: parameter ivloem_arch_dir ${ivloem_arch_dir} bestaat niet en wordt aangemaakt"
  mkdir ${ivloem_arch_dir}
fi

Log "Processing complete directory now for oemm deploy: "${ivloem_src_dir}

for ivldirectory in `find ${ivloem_src_dir} -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort`
do

  Log "Processing oem directory: "${ivloem_src_dir}/${ivldirectory}

  ivloem_log_file="${ivloem_src_dir}/${ivldirectory}/IVLOEMM_FOLDER_DEPLOY.log"

  touch $ivloem_log_file
  RC=$?
  if [ $RC -ne 0 ]; then
    ## we have an error, return to caller
    Log "Error in ProcessFolder: Could not create log file (error=${RC})."
    ivldply_error=$RC
    Log "deploy error: "${ivldply_error}
    return
  fi

  #Extract the data from the directory name:
  ivloem_directory_date=$(echo $ivldirectory | cut -d "_" -f1)
  ivloem_directory_time=$(echo $ivldirectory | cut -d "_" -f2)
  ivloem_traceIT_ticket=$(echo $ivldirectory | cut -d "_" -f3)
  ivloem_deploy_file=$(basename $( find ${ivloem_src_dir}/$ivldirectory -name "*.zip") )
  
  Log "Info directory: ${ivldirectory}: Directory Date: "${ivloem_directory_date}
  Log "Info directory: ${ivldirectory}: Directory Time: "${ivloem_directory_time}
  Log "Info directory: ${ivldirectory}: TraceIT ticket: "${ivloem_traceIT_ticket}
  Log "Info directory: ${ivldirectory}: Deploy File   : "${ivloem_deploy_file}

  echo "Start date folder movement: "$(date +"%Y-%m-%d_%H:%M:%S") >> $ivloem_log_file
  echo "Info directory: ${ivldirectory}: Directory Date: "${ivloem_directory_date} >> $ivloem_log_file
  echo "Info directory: ${ivldirectory}: Directory Time: "${ivloem_directory_time} >> $ivloem_log_file
  echo "Info directory: ${ivldirectory}: TraceIT ticket: "${ivloem_traceIT_ticket} >> $ivloem_log_file
  echo "Info directory: ${ivldirectory}: Deploy File   : "${ivloem_deploy_file} >> $ivloem_log_file

##### BEGIN FAKE TESTING
  ######
  ###### TEMPORARY TEST TO FAKE AN ERROR AND STOP THE PROCESS
  ######
#  if [ "${ivldirectory}" = "DT2020-12-29_15-51-01_TI101657" ]; then
#    ivldply_error=888
#  fi
  ######
  ###### TEMPORARY TEST TO FAKE A STOP OF THE PROCESS
  ######
#  if [ "${ivldirectory}" = "DT2021-01-04_15-09-17_TI101199" ]; then
#     #Sleep for 30 seconds but execute the stop cola-run command in another shell
#     sleep 30s
#  fi
##### END FAKE TESTING
  
  #Process Fake deploy (dummy script)
  Log "Start with the deploy. Using next command:"
  Log "${ivlsh}/${ivloem_code_version}_ivldply_deploy.sh -T${ivloem_target} -E${ivloem_env} -D${ivldirectory} -F${ivloem_deploy_file} -AOEMM -N${ivloem_traceIT_ticket} -V${ivloem_code_version}"

  ${ivlsh}/${ivloem_code_version}_ivldply_deploy.sh -T${ivloem_target} -E${ivloem_env} -D${ivloem_src_dir}/${ivldirectory} -F${ivloem_deploy_file} -AOEMM -N${ivloem_traceIT_ticket} -V${ivloem_code_version}
  RC=$?

  Log "End with the deploy."

  if [ $RC -ne 0 ]; then
    ## we have an error, return to caller
    Log "Error in ProcessFolder: Failure to deploy the oemm code (error: ${RC})"
    ivldply_error=$RC
    return
  fi
  
  #After success deploy, move the src directory to the archive directory
  if [ "${ivldply_error}" = "0" ]; then

    echo "End date folder movement: "$(date +"%Y-%m-%d_%H:%M:%S") >> $ivloem_log_file

    mv ${ivloem_src_dir}/${ivldirectory} ${ivloem_arch_dir}

    RC=$?
    if [ $RC -ne 0 ]; then
      ## we have an error, return to caller
      Log "Error in ProcessFolder: Could not move directory (error=${RC}) from: ${ivloem_src_dir}/${ivldirectory} to ${ivloem_arch_dir}."
      ivldply_error=$RC
      return
    fi 
  fi

  #Read the status file agean
  #If the content is set to STOP, then stop the proces also but without an error

  ivloem_status_file_content="unkonwn"

  ReadOEMMStatusFile

  if [ ! $ivldply_error == "0" ]; then
    Log "There was an error reading the status file"
    return
    #Failure "OEMMM folder processing failed with error $ivldply_error"
  fi

  # Check if the config file does contain a STOP
  if [ "${ivloem_status_file_content}" = "${ivloem_status_stop}" ]; then
    Log "Status file content is set to STOP for the oemm deploy: ${ivloem_status_file_content}"
    # Stopping the process
    ivldply_error=0
    ivloem_status_after_deploy=${ivloem_status_stop}
    return
  fi

done;

ivldply_error=0
return
}

ReadOEMMStatusFile() {

#
# IN: ivloem_src_dir                 : source directory to process
#     ivloem_status_file             : file name where status is stored
#     ivloem_status_stop             : stop status
#     ivloem_status_start            : start status
#     ivloem_status_restart          : restart status
#     ivloem_status_error            : error status in case of an error
#
# OUT: ivldply_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivldply_initialized" = "1" ]; then
  Log "Not initialized"
  ivldply_error="not_initialized"
  return
fi
if [ -z $ivloem_src_dir ]; then
  Log "Error in ProcessFolder: parameter ivloem_src_dir is verplicht"
  ivldply_error=999
  return
fi

tmp_status_file="$ivloem_src_dir/${ivloem_status_file}"

# Check if status file exist
if [ ! -f "${tmp_status_file}" ]; then
  Log "Status file missing: for ${tmp_status_file}"
  ivldply_error=999
  return
fi

# Read content now of the status_file
ivloem_status_file_content=$(cat ${tmp_status_file} | sed "s/ //g")

}

ReadOEMMStatusFile_Status() {

#
# IN: ivloem_src_dir                 : source directory to process
#     ivloem_status_file             : file name where status is stored
#     ivloem_status_stop             : stop status
#     ivloem_status_start            : start status
#     ivloem_status_restart          : restart status
#     ivloem_status_error            : error status in case of an error
#
# OUT: ivldply_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivldply_initialized" = "1" ]; then
  Log "Not initialized"
  ivldply_error="not_initialized"
  return
fi
if [ -z $ivloem_src_dir ]; then
  Log "Error in ProcessFolder: parameter ivloem_src_dir is verplicht"
  ivldply_error=999
  return
fi

tmp_status_file="$ivloem_src_dir/${ivloem_status_file}"

#so we do not get an error when we perform a cat function
touch ${tmp_status_file}

# Read content now of the status_file
ivloem_status_file_content=$(cat ${tmp_status_file} | sed "s/ //g")

if [ "${ivloem_status_file_content}" = "" ]; then
  # Status file was not existing so we set it by default to STOP
  ivloem_status_file_content="${ivloem_status_stop}"
fi
}

SetOEMMStatusFile() {
#
# IN: ivloem_src_dir                 : source directory to process
#     ivloem_status_file             : file name where status is stored
#     ivloem_new_status              : New status

Log "SetOEMMStatusFile entered"

tmp_status_file="$ivloem_src_dir/${ivloem_status_file}"

Log "status file: "${tmp_status_file}
Log "status new: "${ivloem_new_status}

echo "${ivloem_new_status}" > "${tmp_status_file}"

RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ProcessFolder: Could not set the correct status to the file: ${tmp_status_file}"
  ivldply_error=$RC
  return
fi
}

##End functions##

