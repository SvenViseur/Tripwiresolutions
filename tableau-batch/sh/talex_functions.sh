# talex_functions.sh
# A library of callable functions to interact with Tableau servers
# to produce reports for further processing
#
#
#
#################################################################
# Change history
#################################################################
# visv  # Sep/2021    #   1.0.0  # initial version
#################################################################
talex_Functions_ScriptVersion="1.0.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   talex_usr                  : the userid
#   talex_pwd                  : the password
#   talex_tableau_url          : the base URL of the tableau server
#   talex_api_vrs              : the API version to specify in the calls
#   talex_contentUrl           : the value for XML field contentUrl to provide in credential calls
#
#
# General option is talex_debug. Set this to "1" and you will get extra info
#
# Each call uses the $talex_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

talex_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

talex_make_Log_work

talex_error="0"
talex_error_msg=""
talex_initialized="1"
}

talex_make_Log_work() {
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
if [ "$talex_debug" = "1" ]; then
  Log "$1"
fi
}

talex_get_token() {
#
# IN: talex_usr           : username
#     talex_psw           : password
#     talex_contentUrl    : the URL within the server
#     talex_tableau_url   : the base URL to call
#     talex_api_vrs       : the API version to use
#     talex_temp_folder   : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#      talex_token        : the result token
#      talex_sitid        : the site id
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

local tempfilename="${talex_temp_folder}/tempgettoken.xml"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  talex_error=998
  talex_error_msg="Temp folder already contains an output file. Cannot continue"
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

printf -v data '<tsRequest>
  <credentials name="%s" password="%s" >
    <site contentUrl="%s" />
  </credentials>
</tsRequest>' "${talex_usr}" "${talex_pwd}" "${talex_contentUrl}"

printf -v data_obfuscated '<tsRequest>
  <credentials name="%s" password="%s" >
    <site contentUrl="%s" />
  </credentials>
</tsRequest>' "${talex_usr}" "XXXXXXXX" "${talex_contentUrl}"

LogDebug $data_obfuscated

local pre_token=""
LogDebug "Issuing curl call: curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/auth/signin -X POST -d \"${data_obfuscated}\"  "
curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/auth/signin -X POST -d "$data" -o "$tempfilename"
RC=$?
LogDebug "RC=$RC"
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  Log "call was:"
  Log "curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/auth/signin -X POST -d \"${data_obfuscated}\""
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  return
fi

## check of er een error in het antwoord staat
talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi
if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML contains an error code:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi
#Extract the token
talex_token=$(grep -oP '(?<=token\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_token" = "" ]; then
  talex_error=999
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML doesn't contain a token:"
  Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML doesn't contain a token:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  return
fi
#Extract the SiteID
talex_sitid=$(grep -oP '(?<=site\ id\=\").*?(?=\")' "$tempfilename")
if [ "$talex_sitid" = "" ]; then
  talex_error=999
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML doesn't contain a site ID:"
  Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML doesn't contain a site ID:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  return
fi

}

talex_get_schedule_id() {
#
# IN: talex_schedule_name   : the fully qualified name of the schedule
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#      talex_schedule_id  : the schedule id
#      talex_schedule_flow: Parallel/not parallel

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi
tempfilename="${talex_temp_folder}/tempschedules.xml"
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
rm -f $tempfilename

LogDebug "curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/schedules  -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename"

curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/schedules  -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename

## check of er een error in het antwoord staat
talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi
if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML contains an error code:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi

searchString='string(//schedule[@name="'${talex_schedule_name}'"]/@id)'

talex_schedule_id=$(cat $tempfilename | xmllint --format - | sed -n '/<schedules/,/<\/schedules\>/p' | xmllint --xpath "${searchString}" -)

Log "talex_schedule_id: "$talex_schedule_id

##
## Get the schedule information
##

tempfilename="${talex_temp_folder}/tempschedule_info.xml"
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
rm -f $tempfilename

LogDebug "curl -s -k "${talex_tableau_url}/api/${talex_api_vrs}/schedules/${talex_schedule_id}" -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename"
curl -s -k "${talex_tableau_url}/api/${talex_api_vrs}/schedules/${talex_schedule_id}" -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename

## check of er een error in het antwoord staat
talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi
if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML contains an error code:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi

##
## Get parallel or serial
# executionOrder="Parallel"
##
talex_schedule_flow=$(grep -oP '(?<=executionOrder\=\").*?(?=\"\>)' "$tempfilename")

Log "talex_schedule_flow : " $talex_schedule_flow
}

talex_get_extract_tasks() {
#
# IN:
#     talex_schedule_id   : the schedule id we need to extract the task info
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error


if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

tempfilename="${talex_temp_folder}/temptaskschedule_extracts.xml"
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
rm -f $tempfilename

LogDebug "curl -s -k --location --request GET "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/schedules/${talex_schedule_id}/extracts" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -o $tempfilename"

curl -s -k --location --request GET "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/schedules/${talex_schedule_id}/extracts" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -o $tempfilename

## check of er een error in het antwoord staat
talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi

if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML contains an error code:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi

## Get the extract ID's + Priority
export tempfilename_extracts="${talex_temp_folder}/temp_extracts_priority.xml"

# Check if we can create the temp file
touch $tempfilename_extracts
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
rm -f $tempfilename_extracts

cat "$tempfilename" | xmllint --format - | sed -n '/<extracts>/,/<\/extracts\>/p' | sed 's/^ *//g' | grep '<extract id' | sed "s/<extract id=//g" | sed "s/priority=//g" | sed "s/\"//g" | cut -d " " -f1-2 | awk -F' ' '{print $2,$1}' | sed "s/\ /\|/g" > $tempfilename_extracts

}

talex_launch_extract_tasks_parallel() {
#
# IN:
#     talex_schedule_id   : the schedule id we need to extract the task info
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#      talex_job_ids      : all the job id's to check the progress later


if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

printf -v empty_request '<tsRequest> </tsRequest>'

for talex_extract_exec_lijn in $(cat $tempfilename_extracts | sort)
do
  talex_extract_id=$(echo $talex_extract_exec_lijn | cut -d '|' -f2)
  Log "Extract ID : $talex_extract_id"

  tempfilename="${talex_temp_folder}/temptasksextract"_${talex_extract_id}.xml

  # Check if we can create the temp file
  touch $tempfilename_extracts
  RC=$?
  if [ $RC -ne 0 ]; then
    ## we have an error, return to caller
    Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
    talex_error=$RC
    talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
    return
  fi
  rm -f $tempfilename
  
  # Run the specific task
  LogDebug "curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/tasks/extractRefreshes/${talex_extract_id}/runNow"  --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename"

  curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/tasks/extractRefreshes/${talex_extract_id}/runNow"  --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename

  ## check of er een error in het antwoord staat
  talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")

  if [ "$talex_error" = "" ]; then
    talex_error=0
  fi

  if [ $talex_error -ne 0 ]; then
    ## we have an error, return to caller
    Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML contains an error code:"
    local xmlfmt=$(xmllint --format "$tempfilename")
    Log "$xmlfmt"
    talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
    Log "$talex_error_msg"
    return
  fi

  # Get the job-id from the refreshed task
  talex_task_job_id=$(grep -oP '(?<=job\ id\=\").*?(?=\")' "$tempfilename")

  Log "Job id retreived : [${talex_task_job_id}]"

  # Add the job-id to the array for check later
  talex_job_ids=("${talex_job_ids[@]}" ${talex_task_job_id})

done

}

talex_check_job_status() {
#
# IN:
#      talex_job_ids      : all the job id's to check the progress later
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

if [ ${#talex_job_ids[@]} -eq 0 ]
then
  Log "No job ids found!!"
  talex_error=19999
  talex_error_msg="No job ids found!!"
  return
fi

declare -a talex_job_status_results
talex_job_status_results=()

talex_still_looping=true

Log "Started check job ..."

while [ $talex_still_looping == true ]
do

  LogDebug "All Job ids: "${#talex_job_ids[@]}

  for talex_check_job_id in "${talex_job_ids[@]}"
  do
     LogDebug "Processing ... "$talex_job_id
     tempfilename="${talex_temp_folder}/tempjob_"${talex_check_job_id}".xml"

     # Check if we can create the temp file
     touch $tempfilename
     RC=$?
     if [ $RC -ne 0 ]; then
       ## we have an error, return to caller
       Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
       talex_error=$RC
       talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
       return
     fi
     rm -f $tempfilename

     LogDebug "curl -s -k --location --request GET "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/jobs/${talex_check_job_id}" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml"   -o $tempfilename"

     curl -s -k --location --request GET "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/jobs/${talex_check_job_id}" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml"   -o $tempfilename

     ## check of er een error in het antwoord staat
     talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
     if [ "$talex_error" = "" ]; then
       talex_error=0
     fi

     if [ $talex_error -ne 0 ]; then
       ## we have an error, return to caller
       Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML contains an error code:"
       local xmlfmt=$(xmllint --format "$tempfilename")
       Log "$xmlfmt"
       talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
       Log "$talex_error_msg"
       return
     fi

     talex_job_status=$(grep -oP '(?<=finishCode\=\").*?(?=\")' "$tempfilename")
     if [ "${talex_job_status}" == "0" ]
     then
         talex_job_status_results=("${talex_job_status_results[@]}" "${talex_job_status} - Finished succes"})
     fi

     if [ "${talex_job_status}" == "1" ]
     then
         talex_job_error=$(cat $tempfilename |  sed -n '/<notes>/,/<\/notes\>/p')
         talex_job_status_results=("${talex_job_status_results[@]}" "${talex_job_status} - Error: ${talex_job_error}"})
         talex_still_looping=false
         Log "Failure on job status checkup: "$talex_job_error
         Failure "Failure on job status checkup: "$talex_job_error" - "$talex_job_status_results
         talex_error=20000
         talex_error_msg="Failure on job status checkup: "$talex_job_error
         return
     fi
  done

  if [  ${#talex_job_status_results[@]} -ge ${#talex_job_ids[@]} ]
  then
     talex_still_looping=false
  fi

  sleep 2
done

}

talex_launch_extract_tasks_serial() {
#
# IN:
#     talex_schedule_id   : the schedule id we need to extract the task info
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error


if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

printf -v empty_request '<tsRequest> </tsRequest>'

for talex_extract_exec_lijn in $(cat $tempfilename_extracts | sort)
do
  talex_extract_id=$(echo $talex_extract_exec_lijn | cut -d '|' -f2)
  LogDebug "Extract ID : $talex_extract_id"

  tempfilename="${talex_temp_folder}/temptasksextract"_${talex_extract_id}.xml

  # Check if we can create the temp file
  touch $tempfilename
  RC=$?
  if [ $RC -ne 0 ]; then
    ## we have an error, return to caller
    Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
    talex_error=$RC
    talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
    return
  fi
  rm -f $tempfilename

  # Run the specific task
  LogDebug "curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/tasks/extractRefreshes/${talex_extract_id}/runNow"  --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename"

  curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/tasks/extractRefreshes/${talex_extract_id}/runNow"  --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename

  ## check of er een error in het antwoord staat
  talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
  if [ "$talex_error" = "" ]; then
    talex_error=0
  fi

  if [ $talex_error -ne 0 ]; then
    ## we have an error, return to caller
    Log "Error in ${FUNCNAME[0]}: curl call was OK, but resulting XML contains an error code:"
    local xmlfmt=$(xmllint --format "$tempfilename")
    Log "$xmlfmt"
    talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
    Log "$talex_error_msg"
    return
  fi

  # Get the job-id from the refreshed task
  talex_task_job_id=$(grep -oP '(?<=job\ id\=\").*?(?=\")' "$tempfilename")

  LogDebug "Job id retreived : [${talex_task_job_id}]"

  # Add the job-id to the array for check later, but this time clear the array before adding an element (serial execution)
  talex_job_ids=()
  talex_job_ids=("${talex_job_ids[@]}" ${talex_task_job_id})

  talex_check_job_status

done

}

talex_get_datasource_id() {
#
# IN: talex_datasource_name   : datasource name (can contains blanks)
#     talex_project_name      : the name of the project where the datasource reside
#     talex_tableau_url       : the base URL to call
#     talex_api_vrs           : the API version to use
#     talex_token             : the token, obtained from talex_get_token
#     talex_sitid             : the site id, obtained from talex_get_token
#     talex_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#      talex_datasource_id    : the datasource id for use in further calls
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

local tempfilename="${talex_temp_folder}/tempdatasource.xml"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  talex_error=998
  talex_error_msg="Temp folder already contains an output file. Cannot continue"
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

#get the curl return
local pre_datasource-info=""

LogDebug "curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/datasources  -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename"

curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/datasources  -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename

RC=$?
LogDebug $RC
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  return
fi

local ds_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$ds_info_fmtd"

talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi
LogDebug "talex_error: $talex_error"
if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call returned an XML error code."
  Log "$ds_info_fmtd"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi

#no error, try to find the datasource id
# new:
LogDebug "Datasource name: ${talex_datasource_name}"
LogDebug "Project name   : ${talex_project_name}"

searchString='string(//datasource[@name="'${talex_datasource_name}'"] //project[@name="'${talex_project_name}'"]/../@id)'

LogDebug "cat $tempfilename | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | xmllint --xpath "${searchString}" -"

talex_datasource_id=$(cat $tempfilename  | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | xmllint --xpath "$searchString" -)

if [ "$talex_datasource_id" = "" ]; then
  talex_error=999
  Log "Error in ${FUNCNAME[0]}: curl call did not return a datasource id but no error was issued either."
  Log "Please verify that the specified datasource '${talex_datasource_name}' exists and is accessible to the account '${talex_usr}'."
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call did not return a datasource id but no error was issued either."
  return
fi

#ensure we only have 1 entry
ds_count=$(echo "$talex_datasource_id" | wc -l)
LogDebug "ds_count=${ds_count}"
if [ ! "$ds_count" = "1" ]; then
  talex_error=989
  Log "the call for the required datasource returned more than one matching datasource!"
  Log "The xml result was:"
  Log "$ds_info_fmtd"
  Log "The resulting list of matching datasource ids is:"
  Log "$talex_datasource_id"
  Log "The number of matching datasources is: $ds_count"
  talex_error_msg="the call for the required datasource returned more than one matching datasource!"
  return
fi
LogDebug "datasource_id => "${talex_datasource_id}

}

talex_refresh_datasource_id() {
#
# IN: talex_datasource_id     : datasource id
#     talex_tableau_url       : the base URL to call
#     talex_api_vrs           : the API version to use
#     talex_token             : the token, obtained from talex_get_token
#     talex_sitid             : the site id, obtained from talex_get_token
#     talex_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

printf -v empty_request '<tsRequest> </tsRequest>'

local tempfilename="${talex_temp_folder}/temprefreshdatasource.xml"

# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  talex_error=998
  talex_error_msg="Temp folder already contains an output file. Cannot continue"
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

#Start the refresh now

# POST /api/api-version/sites/site-id/datasources/datasource-id/refresh
LogDebug "curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/datasources/${talex_datasource_id}/refresh" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename"

curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/datasources/${talex_datasource_id}/refresh" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename

RC=$?
LogDebug $RC
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  return
fi

local ds_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$ds_info_fmtd"

talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi
LogDebug "talex_error: $talex_error"
if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call returned an XML error code."
  Log "$ds_info_fmtd"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi

# Get the job-id from the refreshed task
talex_task_job_id=$(grep -oP '(?<=job\ id\=\").*?(?=\")' "$tempfilename")

LogDebug "Job id retreived : [${talex_task_job_id}]"

# Add the job-id to the array for check later, but this time clear the array before adding an element (serial execution)
talex_job_ids=()
talex_job_ids=("${talex_job_ids[@]}" ${talex_task_job_id})

talex_check_job_status

}


talex_get_flow_id() {
#
# IN: talex_flow_name   : flow name (can contains blanks)
#     talex_project_name      : the name of the project where the flow reside
#     talex_tableau_url       : the base URL to call
#     talex_api_vrs           : the API version to use
#     talex_token             : the token, obtained from talex_get_token
#     talex_sitid             : the site id, obtained from talex_get_token
#     talex_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#      talex_flow_id    : the flow id for use in further calls
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

local tempfilename="${talex_temp_folder}/tempflow.xml"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  talex_error=998
  talex_error_msg="Temp folder already contains an output file. Cannot continue"
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

#get the curl return
local pre_flow_info=""

LogDebug "curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/flows  -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename"

curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/flows  -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename

RC=$?
LogDebug $RC
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  return
fi

local ds_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$ds_info_fmtd"

talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi
LogDebug "talex_error: $talex_error"
if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call returned an XML error code."
  Log "$ds_info_fmtd"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi

#no error, try to find the flow id
# new:
LogDebug "Flow name: ${talex_flow_name}"
LogDebug "Project name   : ${talex_project_name}"

searchString='string(//flow[@name="'${talex_flow_name}'"] //project[@name="'${talex_project_name}'"]/../@id)'

LogDebug "cat $tempfilename | xmllint --format - | sed -n '/<flows>/,/<\/flows\>/p' | xmllint --xpath "${searchString}" -"

talex_flow_id=$(cat $tempfilename  | xmllint --format - | sed -n '/<flows>/,/<\/flows\>/p' | xmllint --xpath "$searchString" -)

if [ "$talex_flow_id" = "" ]; then
  talex_error=999
  Log "Error in ${FUNCNAME[0]}: curl call did not return a flow id but no error was issued either."
  Log "Please verify that the specified flow '${talex_flow_name}' exists and is accessible to the account '${talex_usr}'."
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call did not return a flow id but no error was issued either."
  return
fi

#ensure we only have 1 entry
ds_count=$(echo "$talex_flow_id" | wc -l)
LogDebug "ds_count=${ds_count}"
if [ ! "$ds_count" = "1" ]; then
  talex_error=989
  Log "the call for the required flow returned more than one matching flow!"
  Log "The xml result was:"
  Log "$ds_info_fmtd"
  Log "The resulting list of matching flow ids is:"
  Log "$talex_flow_id"
  Log "The number of matching flow is: $ds_count"
  talex_error_msg="the call for the required flow returned more than one matching flow!"
  return
fi
LogDebug "flow_id => "${talex_flow_id}

}

talex_refresh_flow_id() {
#
# IN: talex_flow_id           : flow_id
#     talex_tableau_url       : the base URL to call
#     talex_api_vrs           : the API version to use
#     talex_token             : the token, obtained from talex_get_token
#     talex_sitid             : the site id, obtained from talex_get_token
#     talex_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

printf -v empty_request '<tsRequest> </tsRequest>'

local tempfilename="${talex_temp_folder}/temprefreshflow.xml"

# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  talex_error=998
  talex_error_msg="Temp folder already contains an output file. Cannot continue"
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

#Start the flow now

# POST /api/api-version/sites/site-id/flows/Flow-id/run
LogDebug "curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/flows/${talex_flow_id}/run" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename"

curl -s -k --location --request POST "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/flows/${talex_flow_id}/run" --header "X-Tableau-Auth:${talex_token}" --header "Content-Type: application/xml" -d "${empty_request}" -o $tempfilename

RC=$?
LogDebug $RC
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: curl call issued a RC=$RC. Cannot continue."
  return
fi

local ds_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$ds_info_fmtd"

talex_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$talex_error" = "" ]; then
  talex_error=0
fi
LogDebug "talex_error: $talex_error"
if [ $talex_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: curl call returned an XML error code."
  Log "$ds_info_fmtd"
  talex_error_msg=$(grep -oP '(?<=<detail>).*?(?=</detail>)' "$tempfilename")
  Log "$talex_error_msg"
  return
fi

# Get the job-id from the refreshed task
talex_task_job_id=$(grep -oP '(?<=job\ id\=\").*?(?=\")' "$tempfilename")

LogDebug "Job id retreived : [${talex_task_job_id}]"

# Add the job-id to the array for check later, but this time clear the array before adding an element (serial execution)
talex_job_ids=()
talex_job_ids=("${talex_job_ids[@]}" ${talex_task_job_id})

talex_check_job_status

}

tabasco_get_all_projects()
{
#
# IN: 
#     talex_tableau_url       : the base URL to call
#     talex_api_vrs           : the API version to use
#     talex_token             : the token, obtained from talex_get_token
#     talex_sitid             : the site id, obtained from talex_get_token
#     talex_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

##############################################################################
# Get ALL projects
##############################################################################

loop_running=true
loop_counter=1
local tempfilename="${talex_temp_folder}/all_projects.xml"
local tempfilename_copy="${talex_temp_folder}/projects_loop.xml"

# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

while [ "$loop_running" = "true" ]
do

  #get all the projects first
  curl -s -k "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/projects?fields=_all_&pageSize=1000&pageNumber=${loop_counter}" -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename
  number_return_rows=$(cat $tempfilename | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | wc -l)
  if [[ "$number_return_rows" -gt 0 ]]
  then
     loop_counter=$(( $loop_counter + 1 ))
     cat $tempfilename | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | egrep -v '<projects>|<\/projects>'>> ${tempfilename_copy}
  else
     loop_running=false
  fi
done

echo '<projects>' > $tempfilename
cat ${tempfilename_copy}  >> $tempfilename
echo '</projects>' >> $tempfilename

}

tabasco_get_all_datasources() {
#
# IN:
#     talex_tableau_url       : the base URL to call
#     talex_api_vrs           : the API version to use
#     talex_token             : the token, obtained from talex_get_token
#     talex_sitid             : the site id, obtained from talex_get_token
#     talex_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

##############################################################################
# Get ALL DATASOURCES
##############################################################################

loop_running=true
loop_counter=1
local tempfilename="${talex_temp_folder}/all_datasources.xml"
local tempfilename_copy="${talex_temp_folder}/datasources_loop.xml"

# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

while [ "$loop_running" = "true" ]
do

  #get all the datasources first
  curl -s -k "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/datasources?pageSize=1000&pageNumber=${loop_counter}" -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename
  number_return_rows=$(cat $tempfilename | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | wc -l)
  if [[ "$number_return_rows" -gt 0 ]]
  then
     loop_counter=$(( $loop_counter + 1 ))
     cat $tempfilename | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | egrep -v '<datasources>|<\/datasources>'>> ${tempfilename_copy}
  else
     loop_running=false
  fi
done

echo '<datasources>' > $tempfilename
cat ${tempfilename_copy}  >> $tempfilename
echo '</datasources>' >> $tempfilename

}

tabasco_get_all_workbooks() {
#
# IN:
#     talex_tableau_url       : the base URL to call
#     talex_api_vrs           : the API version to use
#     talex_token             : the token, obtained from talex_get_token
#     talex_sitid             : the site id, obtained from talex_get_token
#     talex_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error
#

if [ ! "$talex_initialized" = "1" ]; then
  talex_error="not_initialized"
  talex_error_msg="not_initialized"
  return
fi

##############################################################################
# Get ALL projects
##############################################################################

loop_running=true
loop_counter=1
local tempfilename="${talex_temp_folder}/all_workbooks.xml"
local tempfilename_copy="${talex_temp_folder}/workbooks_loop.xml"

# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create temporary file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tempfilename

while [ "$loop_running" = "true" ]
do

  #get all the workbooks first
  curl -s -k "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/workbooks?pageSize=1000&pageNumber=${loop_counter}" -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename
  number_return_rows=$(cat $tempfilename | xmllint --format - | sed -n '/<workbooks>/,/<\/workbooks\>/p' | wc -l)
  if [[ "$number_return_rows" -gt 0 ]]
  then
     loop_counter=$(( $loop_counter + 1 ))
     cat $tempfilename | xmllint --format - | sed -n '/<workbooks>/,/<\/workbooks\>/p' | egrep -v '<workbooks>|<\/workbooks>'>> ${tempfilename_copy}
  else
     loop_running=false
  fi
done

echo '<workbooks>' > $tempfilename
cat ${tempfilename_copy}  >> $tempfilename
echo '</workbooks>' >> $tempfilename
}

tabasco_select_projects() {
#
# The limitation of name will be applied only at loplevel.
#
# Limitation of names are eg:
# + or - (include or exclude)
# wildcard can be used eg:
# *_DATASOURCES
# PRODUCTION_*
# *SANDBOX
#
#
# Limitation must be case-insensitive !!
#
# All subfolders will be included when the projectname is a hit
#

export in_tempfilename="${talex_temp_folder}/all_projects.xml"
local out_tempfilename="${talex_temp_folder}/temp_projects.xml"
local out_incl_list_tempfilename="${talex_temp_folder}/include_toplevel_projects.lst"
local out_excl_list_tempfilename="${talex_temp_folder}/exclude_toplevel_projects.lst"

local out_incl_list_project="${talex_temp_folder}/include_all_projects.lst"
local out_excl_list_project="${talex_temp_folder}/exclude_all_projects.lst"

local tbl_include_projecten="${talex_temp_folder}/include_projecten.lijst"
local tbl_exclude_projecten="${talex_temp_folder}/exclude_projecten.lijst"

# Check if we can create the temp file
touch $tbl_include_projecten
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ${FUNCNAME[0]}: Could not create tbl_include_projecten file (error=${RC})."
  talex_error=$RC
  talex_error_msg="Error in ${FUNCNAME[0]}: Could not create tbl_include_projecten file (error=${RC})."
  return
fi
# Delete the touched file
rm -f $tbl_include_projecten

# Get the correct project file for the proper content Url
tblrc_file=${tbltabasco_cfg_folder}/${talex_contentUrl}_projecten.cfg

if [ ! -f "${tblrc_file}" ]; then
    Failure "File ${tblrc_file} does not exist"
fi

# Split the list between include and exclude
cat $tblrc_file | egrep "^\-|^\+" | grep "^\+" | cut -c2- > $tbl_include_projecten
cat $tblrc_file | egrep "^\-|^\+" | grep "^\-" | cut -c2- > $tbl_exclude_projecten

# Process the include projects first

while read -r tabasco_project_in;
do
 if [ ! "$tabasco_project_in" == "" ]
 then
   Log "Included Toplevel Projects filter: ["$tabasco_project_in"]"

   #Convert all * to # (wildcard issue in Linux)
   export tabasco_project="${tabasco_project_in//\*/#}"

   #Convert to upper string
   export tabasco_project=$(echo $tabasco_project | tr [:lower:] [:upper:])
   export only_one_pattern=$(echo -n $tabasco_project | tr -cd '#' | wc -c)

   Log "project : ["$tabasco_project"]"
   Log "pattern : ["$only_one_pattern"]"

   case ${only_one_pattern} in
    "2")
        # voorbeeld: *PRODUCTION* => alles wat PRODUCTION bevat
        export tmp_tabasco_project=$(echo $tabasco_project | sed "s/#//g")
        export searchString='//project[@topLevelProject="true" and contains(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'),"'${tmp_tabasco_project}'")]/@id'
     ;;
    "1")
        Log "in => ["${tabasco_project}"]"
        if [ "$tabasco_project" == "#" ]
        then
           # get ALL projects
           export searchString='//project[@topLevelProject="true"]/@id'
           Log "is one character only"
        else
           if  [[ "$tabasco_project" =~ ^#.*  ]]
           then
              # voorbeeld: *PRODUCTION => alles wat eindigt met PRODUCTION
              export tmp_tabasco_project=$(echo $tabasco_project | cut -d '#' -f2)
              export searchString='//project[@topLevelProject="true" and substring(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'), string-length(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')) - string-length("'${tmp_tabasco_project}'") + 1) = "'${tmp_tabasco_project}'"]/@id'
           else
              # voorbeeld: PRODUCTION* => alles wat start met PRODUCTION
              export tmp_tabasco_project=$(echo $tabasco_project | cut -d '#' -f1)
              export searchString='//project[@topLevelProject="true" and starts-with(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'),"'${tmp_tabasco_project}'")]/@id'
           fi
        fi
     ;;
    "0")
        # voorbeeld: PRODUCTION => alles wat gelijk is aan PRODUCTION
        export searchString='//project[@topLevelProject="true" and translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')="'${tabasco_project}'"]/@id'
     ;;
   esac

   Log "searchString returned include: "${searchString}

   #Select now the projects that meat the name condition
   cat $in_tempfilename | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | xmllint --xpath "${searchString}" - | cut -d " " -f2- | sed "s/id\=/\n/g" | sed "s/\"//g" | sed "/^$/d" | sed 's/ //' >> ${out_incl_list_tempfilename}
   
 fi
done < ${tbl_include_projecten}

# Process the exclude projects 

while read -r tabasco_project_in;
do
 if [ ! "$tabasco_project_in" == "" ]
 then
   Log "Excluded Toplevel Projects filter: ["$tabasco_project_in"]"

   #Convert all * to # (wildcard issue in Linux)
   export tabasco_project="${tabasco_project_in//\*/#}"

   #Convert to upper string
   export tabasco_project=$(echo $tabasco_project | tr [:lower:] [:upper:])
   export only_one_pattern=$(echo -n $tabasco_project | tr -cd '#' | wc -c)

   Log "project : ["$tabasco_project"]"
   Log "pattern : ["$only_one_pattern"]"

   case ${only_one_pattern} in
    "2")
        # voorbeeld: *PRODUCTION* => alles wat PRODUCTION bevat
        export tmp_tabasco_project=$(echo $tabasco_project | sed "s/#//g")
        export searchString='//project[@topLevelProject="true" and contains(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'),"'${tmp_tabasco_project}'")]/@id'
     ;;
    "1")
        if [ "$tabasco_project" == "#" ]
        then
           # get ALL projects
           export searchString='//project[@topLevelProject="true"]/@id'
           Log "is one character only"
        else
           if  [[ "$tabasco_project" =~ ^#.*  ]]
           then
              # voorbeeld: *PRODUCTION => alles wat eindigt met PRODUCTION
              export tmp_tabasco_project=$(echo $tabasco_project | cut -d '#' -f2)
              export searchString='//project[@topLevelProject="true" and substring(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'), string-length(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')) - string-length("'${tmp_tabasco_project}'") + 1) = "'${tmp_tabasco_project}'"]/@id'
        else
           # voorbeeld: PRODUCTION* => alles wat start met PRODUCTION
           export tmp_tabasco_project=$(echo $tabasco_project | cut -d '#' -f1)
           export searchString='//project[@topLevelProject="true" and starts-with(translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'),"'${tmp_tabasco_project}'")]/@id'
        fi
     fi
     ;;
    "0")
     # voorbeeld: PRODUCTION => alles wat gelijk is aan PRODUCTION
     export searchString='//project[@topLevelProject="true" and translate(@name, 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')="'${tabasco_project}'"]/@id'
     ;;
   esac

   Log "searchString returned exclude: "${searchString}
   
   #Select now the projects that meat the name condition
   cat $in_tempfilename | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | xmllint --xpath "${searchString}" - | cut -d " " -f2- | sed "s/id\=/\n/g" | sed "s/\"//g" | sed "/^$/d" | sed 's/ //' >> ${out_excl_list_tempfilename}

 fi
done < ${tbl_exclude_projecten}

Log " "
Log "=== include project folders"
Log " "

# Get now the sub-folders of the include folders
while read -r tabasco_toplevel_project_id;
do
    export export_temp_output=${out_incl_list_project}
    export parentproject_id=${tabasco_toplevel_project_id}
    export main_project_id=${tabasco_toplevel_project_id}
    export tabasco_selection="Included"

    searchName='string(//project[@id="'${parentproject_id}'"]/@name)'
    projectname=$(cat ${in_tempfilename} | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | xmllint --xpath "${searchName}" - )

    Log "${tabasco_selection}: Top project : ["$projectname"], id : ["$parentproject_id"]"

    echo ${parentproject_id}  >> ${export_temp_output}

    tabasco_get_sub_projects 

done < ${out_incl_list_tempfilename}

Log " "
Log "=== exclude project folders"
Log " "

# Get now the sub-folders of the exclude folders
while read -r tabasco_toplevel_project_id;
do
    export export_temp_output=${out_excl_list_project}
    export parentproject_id=${tabasco_toplevel_project_id}
    export main_project_id=${tabasco_toplevel_project_id}
    export tabasco_selection="Excluded"

    searchName='string(//project[@id="'${parentproject_id}'"]/@name)'
    projectname=$(cat ${in_tempfilename} | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | xmllint --xpath "${searchName}" - )

    Log "${tabasco_selection}: Toplevel folder : ["$projectname"], id : ["$parentproject_id"]"

    echo ${parentproject_id}  >> ${export_temp_output}

    tabasco_get_sub_projects

done < ${out_excl_list_tempfilename}

#Keep now only the project that should be included in the list minus the exclude id's
if [ -f ${out_excl_list_project} ]
then
  grep -vxFf ${out_excl_list_project}  ${out_incl_list_project} | sort | uniq > ${tabasco_final_selected_projects}
else
  cat ${out_incl_list_project} | sort | uniq > ${tabasco_final_selected_projects}
fi

}

tabasco_get_sub_projects() {
#
# OUT: talex_error        : 0 if no error
#                            <>0 if error


#local searchName='string(//project[@id="'${parentproject_id}'"]/@name)'
#local projectname=$(cat ${in_tempfilename} | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | xmllint --xpath "${searchName}" - )

#Log "${tabasco_selection}: Start project : ["$projectname"], id : ["$parentproject_id"]"

local out_tempfilename="${talex_temp_folder}/temp_subprojects.lst"

local searchString='//project[@parentProjectId="'${parentproject_id}'"]/@id'

cat ${in_tempfilename} | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | xmllint --xpath "${searchString}" - | cut -d " " -f2- | sed "s/id\=/\n/g" | sed "s/\"//g" | sed "/^$/d" | sed 's/ //' > ${out_tempfilename}

readarray -t project_list < ${out_tempfilename}

for project_id in "${project_list[@]}"
do
    searchName='string(//project[@id="'${project_id}'"]/@name)'
    projectname=$(cat ${in_tempfilename} | xmllint --format - | sed -n '/<projects>/,/<\/projects\>/p' | xmllint --xpath "${searchName}" - )
    Log "${tabasco_selection} --> Sub project:  [" $projectname"], id : ["$project_id"]"

    echo ${project_id} >> ${export_temp_output}
    export parentproject_id=${project_id}

    tabasco_get_sub_projects

done

}

runTabasco() {

  export tabasco_final_selected_projects="${talex_temp_folder}/projects_selection.lst"
  local tempfilename_datasources="${talex_temp_folder}/all_datasources.xml"
  local tempfilename_workbooks="${talex_temp_folder}/all_workbooks.xml"
  local tempfilename_out_datasources="${talex_temp_folder}/project_datasources.lst"
  local tempfilename_out_workbooks="${talex_temp_folder}/project_workbooks.lst"


  #Get All the projects
  tabasco_get_all_projects

  #Get All datasources
  tabasco_get_all_datasources

  #Get All workbooks
  tabasco_get_all_workbooks

  #Select now the projects to process
  tabasco_select_projects

  while read -r tabasco_project;
  do 

     ######################################################
     # PROCESSING DATASOURCES FIRST LIMITATION OF PROJECT #
     ######################################################

     export searchProjectString='//project[@id="'${tabasco_project}'"]/../@id'

     Log "#######################"
     Log "# PROCESS DATASOURCES #"
     Log "#######################"

     cat ${tempfilename_datasources} | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | xmllint --xpath "${searchProjectString}" - | cut -d " " -f2- | sed "s/id\=/\n/g" | sed "s/\"//g" | sed "/^$/d" | sed 's/ //' > ${tempfilename_out_datasources}

     while read -r tabasco_datasource;
     do

        export searchDatasource='string(//datasource[@id="'${tabasco_datasource}'"]/@contentUrl)'

        export Datasource_name=$(cat ${tempfilename_datasources} | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | xmllint --xpath "${searchDatasource}" -)

        Log "tabasco_datasource: ["${tabasco_datasource}"]"

        local tempfilename="${talex_temp_folder}/datasources_connections_${tabasco_datasource}.xml"

        curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/datasources/${tabasco_datasource}/connections -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename

        export OutConnections="${talex_temp_folder}/all_connections.xml"
        # Get first all the connection id's in a list
        export searchString="//connection/@id"
        cat $tempfilename | xmllint --format - | sed -n '/<connections>/,/<\/connections\>/p' | xmllint --xpath "${searchString}" - | cut -d " " -f2-| sed "s/id\=/\n/g" | sed "s/\"//g" | sed "/^$/d" | sed 's/ //' > $OutConnections

        #############################################
        ######### MULTIPLE CONNECTION ###############
        #############################################

        while read -r tabasco_connection;
        do

          Log "tabasco_connection id=> ["$tabasco_connection"]"

          # get serverAddress from connection

          export searchString='string(//connection[@id="'${tabasco_connection}'"]/@serverAddress)'

          export serverAddress=$(cat $tempfilename | xmllint --format - | sed -n '/<connections>/,/<\/connections\>/p' | xmllint --xpath "${searchString}" -)

          # Search serverAddress in .._security.cfg (case insensitive !!) to get the correct connection key
          export serverKeyAdressFound=$(cat ${tbltabasco_cfg_folder}/${talex_contentUrl}_security.cfg | grep -i "^${serverAddress}" | head -n1 | cut -d '|' -f2)

          Log "serverAddress + found? => ["$serverAddress"], Key found => ["$serverKeyAdressFound"]"

          if [ ! "${serverKeyAdressFound}" == "" ]
          then

            # If found then
            # get the password from that user and serveraddress via gnp

            export tabasco_vault_info=$(gpg -d ${tbltabasco_vault} | grep "^${serverKeyAdressFound}" | head -n1)

            if [ ! "${tabasco_vault_info}" == "" ]
            then

              export tabasco_servername=$(echo ${tabasco_vault_info} | cut -d '|' -f2)
              export tabasco_username=$(echo ${tabasco_vault_info} | cut -d '|' -f3)
              export tabasco_new_password=$(echo ${tabasco_vault_info} | cut -d '|' -f5)
              export tabasco_new_port=$(echo ${tabasco_vault_info} | cut -d '|' -f4)

              # Update now the connection
              if [ "$tabasco_new_port" == "" ]
              then
                 printf -v data '<tsRequest>
 <connection serverAddress="%s" userName="%s" password="%s" embedPassword="true" /> </tsRequest>' "${tabasco_servername}" "${tabasco_username}" "${tabasco_new_password}"
              else
                 printf -v data '<tsRequest>
 <connection serverAddress="%s" serverPort="%s" userName="%s" password="%s" embedPassword="true" /> </tsRequest>' "${tabasco_servername}" "${tabasco_new_port}" "${tabasco_username}" "${tabasco_new_password}"
              fi

              curl -s -k "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/datasources/${tabasco_datasource}/connections/${tabasco_connection}" -X PUT -H "X-Tableau-Auth:${talex_token}" -H "Content-Type: application/xml" -d "$data" > ${talex_temp_folder}/adapted_${tabasco_connection}.xml

              Log "Datasource adapted: ["${Datasource_name}"]"
            fi

          fi
        done < ${OutConnections}

     done < ${tempfilename_out_datasources}


     ############################
     ##### END DATASOURCES ######
     ############################

     Log "##########################"
     Log "## PROCESS WORKBOOKS NOW #"
     Log "##########################"

     ##########################
     ## PROCESS WORKBOOKS NOW #
     ##########################

     cat $tempfilename_workbooks | xmllint --format - | sed -n '/<workbooks>/,/<\/workbooks\>/p' | xmllint --xpath "${searchProjectString}" - | cut -d " " -f2- | sed "s/id\=/\n/g" | sed "s/\"//g" | sed "/^$/d" | sed 's/ //' > ${tempfilename_out_workbooks}

     ###
     # Loop every workbooks and get all connections for that workbook
     ###

     while read -r tabasco_workbook
     do

       export searchWorkbook='string(//workbook[@id="'${tabasco_workbook}'"]/@name)'

       export Workbook_name=$(cat ${tempfilename_workbooks} | xmllint --format - | sed -n '/<workbooks>/,/<\/workbooks\>/p' | xmllint --xpath "${searchWorkbook}" -)

       Log "tabasco_workbook: ["${tabasco_workbook}"] ["${Workbook_name}"]"

       local tempfilename="${talex_temp_folder}/workbook_connections_${tabasco_workbook}.xml"

       curl -s -k ${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/workbooks/${tabasco_workbook}/connections -X GET -H "X-Tableau-Auth:${talex_token}" -o $tempfilename

       export OutConnections="${talex_temp_folder}/all_wb_connections.xml"
       # Get first all the connection id's in a list
       # exclude all sqlproxy as these are connections in the datasource list and should not be updated
       #
       export searchString='//connection[@type!="sqlproxy"]/@id'
       cat $tempfilename | xmllint --format - | sed -n '/<connections>/,/<\/connections\>/p' | xmllint --xpath "${searchString}" - | cut -d " " -f2-| sed "s/id\=/\n/g" | sed "s/\"//g" | sed "/^$/d" | sed 's/ //' > $OutConnections

       #############################################
       ######### MULTIPLE CONNECTION ###############
       #############################################

       Log "connections:" $(cat $OutConnections | wc -l)

       while read -r tabasco_wb_connection;
       do

         Log "tabasco_connection id=> ["$tabasco_wb_connection"]"

         # get serverAddress from connection
         export searchString='string(//connection[@id="'${tabasco_wb_connection}'"]/@serverAddress)'
         export serverAddress=$(cat $tempfilename | xmllint --format - | sed -n '/<connections>/,/<\/connections\>/p' | xmllint --xpath "${searchString}" -)

         Log "serverAddress: ["$serverAddress"]"

         if [ ! "$serverAddress" == "" ]
          then

             export searchString='string(//connection[@id="'${tabasco_wb_connection}'"]/datasource/@name)'
             export connection_name=$(cat $tempfilename | xmllint --format - | sed -n '/<connections>/,/<\/connections\>/p' | xmllint --xpath "${searchString}" -)

             # Search serverAddress in .._security.cfg (case insensitive !!) to get the correct connection key
             export serverKeyAdressFound=$(cat ${tbltabasco_cfg_folder}/${talex_contentUrl}_security.cfg | grep -i "^${serverAddress}" | head -n1 | cut -d '|' -f2)

             Log "serverAddress + found? => ["$serverAddress"], Key found => ["$serverKeyAdressFound"]"

             if [ ! "${serverKeyAdressFound}" == "" ]
             then

               # If found then
               # get the password from that user and serveraddress via gnp

               export tabasco_vault_info=$(gpg -d ${tbltabasco_vault} | grep "^${serverKeyAdressFound}" | head -n1)

               if [ ! "${tabasco_vault_info}" == "" ]
               then

                  export tabasco_servername=$(echo ${tabasco_vault_info} | cut -d '|' -f2)
                  export tabasco_username=$(echo ${tabasco_vault_info} | cut -d '|' -f3)
                  export tabasco_new_password=$(echo ${tabasco_vault_info} | cut -d '|' -f5)
                  export tabasco_new_port=$(echo ${tabasco_vault_info} | cut -d '|' -f4)

                  # Update now the connection

                  if [ "$tabasco_new_port" == "" ]
                  then
                     printf -v data '<tsRequest>
 <connection serverAddress="%s" userName="%s" password="%s" embedPassword="true" /> </tsRequest>' "${tabasco_servername}" "${tabasco_username}" "${tabasco_new_password}"
                  else
                     printf -v data '<tsRequest>
 <connection serverAddress="%s" serverPort="%s" userName="%s" password="%s" embedPassword="true" /> </tsRequest>' "${tabasco_servername}" "${tabasco_new_port}" "${tabasco_username}" "${tabasco_new_password}"
                  fi

                  curl -s -k "${talex_tableau_url}/api/${talex_api_vrs}/sites/${talex_sitid}/workbooks/${tabasco_workbook}/connections/${tabasco_wb_connection}" -X PUT -H "X-Tableau-Auth:${talex_token}" -H "Content-Type: application/xml" -d "$data" > ${talex_temp_folder}/adapted_${tabasco_connection}.xml

                  Log " ---->  Workbook connection adapted: ["${Workbook_name}"]"
               fi
            fi

          fi
        done < ${OutConnections}

      done < ${tempfilename_out_workbooks}


  done < ${tabasco_final_selected_projects}

}

