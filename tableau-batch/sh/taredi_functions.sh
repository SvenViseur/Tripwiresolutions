# taredi_functions.sh
# A library of callable functions to interact with Tableau servers
# to produce reports for further processing
#
#
#
#################################################################
# Change history
#################################################################
# dexa  # Aug/2020    #   1.0.0  # initial version
#       # Sep/2020    #   1.1.0  # crosstab xlsx only for >=3.9
#       #             #          # extend use of Log fctn
#       # Oct/2020    #   1.2.0  # all curl outputs in temp files
#       # Oct/2020    #   1.2.1  # adapt tempfilename to the type of data
#       # Oct/2020    #   1.2.2  # change csv tests
#       # Nov/2020    #   1.2.3  # change xlsx tests
#       # Jan/2021    #   1.3.0  # Allow now empty files for CSV
#       #    /20..    #   x.x.x  #
#       #    /20..    #   x.x.x  #
#################################################################
Taredi_Functions_ScriptVersion="1.3.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   taredi_usr                  : the userid
#   taredi_pwd                  : the password
#   taredi_tableau_url          : the base URL of the tableau server
#   taredi_api_vrs              : the API version to specify in the calls
#   taredi_contentUrl           : the value for XML field contentUrl to provide in credential calls
#
#
# General option is taredi_debug. Set this to "1" and you will get extra info
#
# Each call uses the $taredi_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

taredi_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

taredi_make_Log_work

taredi_error="0"
taredi_initialized="1"
}

taredi_make_Log_work() {
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
if [ "$taredi_debug" = "1" ]; then
  Log "$1"
fi
}

taredi_get_token() {
#
# IN: taredi_usr           : username
#     taredi_psw           : password
#     taredi_contentUrl    : the URL within the server
#     taredi_tableau_url   : the base URL to call
#     taredi_api_vrs       : the API version to use
#     taredi_temp_folder   : the fully qualified path to a temp folder that is unique to this call
#
# OUT: taredi_error        : 0 if no error
#                            <>0 if error
#      taredi_token        : the result token
#      taredi_sitid        : the site id
#

if [ ! "$taredi_initialized" = "1" ]; then
  taredi_error="not_initialized"
  return
fi

local tempfilename="${taredi_temp_folder}/tempgettoken.xml"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  taredi_error=998
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_file_workbook: Could not create temporary file (error=${RC})."
  taredi_error=$RC
  return
fi
# Delete the touched file
rm -f $tempfilename

printf -v data '<tsRequest>
  <credentials name="%s" password="%s" >
    <site contentUrl="%s" />
  </credentials>
</tsRequest>' "${taredi_usr}" "${taredi_pwd}" "${taredi_contentUrl}"
printf -v data_obfuscated '<tsRequest>
  <credentials name="%s" password="%s" >
    <site contentUrl="%s" />
  </credentials>
</tsRequest>' "${taredi_usr}" "XXXXXXXXXXXX" "${taredi_contentUrl}"

LogDebug $data_obfuscated

local pre_token=""
LogDebug "Issuing curl call: curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/auth/signin -X POST -d \"${data_obfuscated}\"  "
curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/auth/signin -X POST -d "$data" -o "$tempfilename"
RC=$?
LogDebug "RC=$RC"
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_token: curl call issued a RC=$RC. Cannot continue."
  Log "call was:"
  Log "curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/auth/signin -X POST -d \"${data_obfuscated}\""
  taredi_error=$RC
  return
fi

## check of er een error in het antwoord staat
taredi_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$taredi_error" = "" ]; then
  taredi_error=0
fi
if [ $taredi_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_token: curl call was OK, but resulting XML contains an error code:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  return
fi
#Extract the token
taredi_token=$(grep -oP '(?<=token\=\").*?(?=\"\>)' "$tempfilename")
if [ "$taredi_token" = "" ]; then
  taredi_error=999
  Log "Error in taredi_get_token: curl call was OK, but resulting XML doesn't contain a token:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  return
fi
#Extract the SiteID
taredi_sitid=$(grep -oP '(?<=site\ id\=\").*?(?=\")' "$tempfilename")
if [ "$taredi_sitid" = "" ]; then
  taredi_error=999
  Log "Error in taredi_get_token: curl call was OK, but resulting XML doesn't contain a site ID:"
  local xmlfmt=$(xmllint --format "$tempfilename")
  Log "$xmlfmt"
  return
fi

}

taredi_get_workbook_id() {
#
# IN: taredi_workbook_name     : the workbook to use (can contain blanks!)
#     taredi_project_name      : the name of the project where the workbook reside
#     taredi_tableau_url       : the base URL to call
#     taredi_api_vrs           : the API version to use
#     taredi_token             : the token, obtained from taredi_get_token
#     taredi_sitid             : the site id, obtained from taredi_get_token
#     taredi_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: taredi_error        : 0 if no error
#                            <>0 if error
#      taredi_workbook_id      : the workbook id for use in further calls
#

if [ ! "$taredi_initialized" = "1" ]; then
  taredi_error="not_initialized"
  return
fi

local tempfilename="${taredi_temp_folder}/tempworkbook.xml"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  taredi_error=998
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_workbook_id: Could not create temporary file (error=${RC})."
  taredi_error=$RC
  return
fi
# Delete the touched file
rm -f $tempfilename

# convert to url format for spaces
local workbook_name_filter_url=$( echo "filter%3Dname%3Aeq%3A${taredi_workbook_name}" | sed "s/ /%20/g" )
LogDebug "converted workbook name filter: $workbook_name_filter_url"
Log "converted workbook name filter: $workbook_name_filter_url"

#get the curl return
local pre_workbook_info=""
LogDebug "curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/workbooks?${workbook_name_filter_url} -X GET -H \"X-Tableau-Auth:${taredi_token}\""
curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/workbooks?${workbook_name_filter_url} -X GET -H "X-Tableau-Auth:${taredi_token}" -o "$tempfilename"
RC=$?
LogDebug $RC
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_workbook_id: curl call issued a RC=$RC. Cannot continue."
  taredi_error=$RC
  return
fi

local wb_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$wb_info_fmtd"

taredi_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$taredi_error" = "" ]; then
  taredi_error=0
fi
LogDebug "taredi_error: $taredi_error"
if [ $taredi_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_workbook_id: curl call returned an XML error code."
  Log "$wb_info_fmtd"
  return
fi

#no error, try to find the workbook id
# old : taredi_workbook_id=$(grep -oP '(?<=workbook\ id\=\").*?(?=\")' "$tempfilename")
# new:
LogDebug "Workbook name: ${taredi_workbook_name}"
LogDebug "Project name : ${taredi_project_name}"

searchString='string(//workbook[@name="'${taredi_workbook_name}'"] //project[@name="'${taredi_project_name}'"]/../@id)'

LogDebug "cat $tempfilename | xmllint --format - | sed -n '/<workbooks>/,/<\/workbooks\>/p' | xmllint --xpath "${searchString}" -"

# taredi_workbook_id=$(cat $tempfilename | xmllint --format - | sed -n '/<workbooks>/,/<\/workbooks\>/p' | xmllint --xpath 'string(//workbook[@name="'${taredi_workbook_name}'"] //project[@name="'${taredi_project_name}'"]/../@id)' -)

taredi_workbook_id=$(cat $tempfilename  | xmllint --format - | sed -n '/<workbooks>/,/<\/workbooks\>/p' | xmllint --xpath "$searchString" -)

if [ "$taredi_workbook_id" = "" ]; then
  taredi_error=999
  Log "Error in taredi_get_workbook_id: curl call did not return a workbook id but no error was issued either."
  Log "Please verify that the specified workbook '${taredi_workbook_name}' exists and is accessible to the account '${taredi_usr}'."
  return
fi

#ensure we only have 1 entry
wb_count=$(echo "$taredi_workbook_id" | wc -l)
LogDebug "wb_count=${wb_count}"
if [ ! "$wb_count" = "1" ]; then
  taredi_error=989
  Log "the call for the required workbook returned more than one matching workbook!"
  Log "The xml result was:"
  Log "$wb_info_fmtd"
  Log "The resulting list of matching workbook ids is:"
  Log "$taredi_workbook_id"
  Log "The number of matching workbooks is: $wb_count"
  return
fi
LogDebug "workbook_id => "${taredi_workbook_id}

}

taredi_get_view_id() {
#
# IN:
#     taredi_tableau_url       : the base URL to call
#     taredi_api_vrs           : the API version to use
#     taredi_token             : the token, obtained from taredi_get_token
#     taredi_sitid             : the site id, obtained from taredi_get_token
#     taredi_workbook_id       : the workbook id, obtained from taredi_get_workbook_id
#     taredi_view_name         : the view to select from the workbook
#     taredi_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: taredi_error        : 0 if no error
#                            <>0 if error
#      taredi_view_id          : the view id for use in further calls
#

if [ ! "$taredi_initialized" = "1" ]; then
  taredi_error="not_initialized"
  return
fi

local tempfilename="${taredi_temp_folder}/tempviewid.xml"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  taredi_error=998
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_view_id: Could not create temporary file (error=${RC})."
  taredi_error=$RC
  return
fi
# Delete the touched file
rm -f $tempfilename

#echo "Curl call:"
LogDebug "curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/workbooks/${taredi_workbook_id}/views -X GET -H \"X-Tableau-Auth:${taredi_token}\" "
local pre_view_info=""
curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/workbooks/${taredi_workbook_id}/views -X GET -H "X-Tableau-Auth:${taredi_token}" -o "$tempfilename"
#get the curl return
RC=$?
LogDebug "RC of curl call: $RC"
local vw_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$vw_info_fmtd"

if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_view: curl call issued a RC=$RC. Cannot continue."
  Log "curl answer:"
  Log "$vw_info_fmtd"
  taredi_error=$RC
  return
fi

taredi_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$taredi_error" = "" ]; then
  taredi_error=0
fi
LogDebug "taredi_error: $taredi_error"
if [ $taredi_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_view_id: curl call returned an XML error code."
  Log "$vw_info_fmtd"
  return
fi

taredi_view_id=$(grep -oP '(?<=view\ id\=\").*?(?=view)' "$tempfilename" | grep "${taredi_view_name}" | cut -d '"' -f 1)
if [ "$taredi_view_id" = "" ]; then
  taredi_error=999
  Log "Error in taredi_get_view_id: curl call did not return a view id but no error was issued either."
  Log "Please verify that the specified view '${taredi_view_name}' exists and is accessible to the account '${taredi_usr}'."
  Log "The list of available views is:"
  Log "$vw_info_fmtd"
  Log "End of available views."
  return
fi

#ensure we only have 1 entry
vw_count=$(echo "$taredi_view_id" | wc -l)
LogDebug "vw_count=${vw_count}"
if [ ! "$vw_count" = "1" ]; then
  taredi_error=989
  Log "the call for the required view returned more than one matching view!"
  Log "The xml result was:"
  Log "$vw_info_fmtd"
  Log "The resulting list of matching view ids is:"
  Log "$taredi_view_id"
  Log "The number of matching views is: $vw_count"
  return
fi

LogDebug "view_id => ${taredi_view_id}"

}


taredi_get_file_one_view() {
#
# IN:
#     taredi_tableau_url       : the base URL to call
#     taredi_api_vrs           : the API version to use
#     taredi_token             : the token, obtained from taredi_get_token
#     taredi_sitid             : the site id, obtained from taredi_get_token
#     taredi_workbook_id       : the workbook id, obtained from taredi_get_workbook_id
#     taredi_view_id           : the view id, obtained from taredi_get_view_id
#     taredi_format_type       : the file format to produce: pdf, xlsx, csv, png
#                                    Note: xlsx requires api_vrs >= 3.9
#     taredi_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#     taredi_filename          : the fully qualified file name to produce
#     taredi_max_age           : the maximum age in minutes of cached reports
#
#     depending on format type (mandatory values!)
#       taredi_pdf_page_orientation   : the page orientation: landscape, portrait
#       taredi_pdf_page_type          : the page size: A4, A3, A5, Letter, Legal, Executive, ...
#       taredi_png_resolution         : the required image resolution
#
#     optional parameters
#       taredi_filter            : a valid filter expression to pass on to Tableau (e.g. jaar=2020)
#
#
# OUT: taredi_error        : 0 if no error
#                            <>0 if error
#

if [ ! "$taredi_initialized" = "1" ]; then
  taredi_error="not_initialized"
  return
fi

if [ -z $taredi_max_age ]; then
  Log "Error in taredi_get_file_one_view: parameter taredi_max_age is verplicht"
  taredi_error=999
  return
fi
if [ -z $taredi_format_type ]; then
  Log "Error in taredi_get_file_one_view: parameter taredi_format_type is verplicht"
  taredi_error=999
  return
fi
if [ -z $taredi_temp_folder ]; then
  Log "Error in taredi_get_file_one_view: parameter taredi_temp_folder is verplicht"
  taredi_error=999
  return
fi
if [ -z $taredi_filename ]; then
  Log "Error in taredi_get_file_one_view: parameter taredi_filename is verplicht"
  taredi_error=999
  return
fi

LogDebug "workbook_id => ${taredi_workbook_id}"
LogDebug "view_id => ${taredi_view_id}"
local tempfilename="${taredi_temp_folder}/tempoutput.data"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  taredi_error=998
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_file_one_view: Could not create temporary file (error=${RC})."
  taredi_error=$RC
  return
fi
# Delete the touched file
rm -f $tempfilename

local url_spec=""
local url_filter_pre="&"  ## the prefix before the filter expression, if any
local exp_file_info=""    ## the output of file command on a good data file
local allow_empty=0       ## by default, do not allow empty files
case "$taredi_format_type" in
  pdf)
    url_spec="pdf?page_type=${taredi_pdf_page_type}&orientation=${taredi_pdf_page_orientation}&"
    exp_file_info="PDF document"
    ;;
  xlsx)
    url_spec="crosstab/excel?"
    exp_file_info="Excel" ## the returned string is normally  Microsoft Excel 2007+ but we accept all Excel files
    if [ "${taredi_api_vrs}" = "3.8" ]; then
      Log "Error: crosstab xlsx asked but the api version 3.8 does not support that!"
      taredi_error=990
      return
    fi
    ;;
  csv)
    url_spec="data?"
    exp_file_info="CSV"
    allow_empty=1
    ;;
  png)
    if [ "${taredi_png_resolution}" = "standard" ]; then
      url_spec="image?"
    else
      url_spec="image?resolution=${taredi_png_resolution}&"
    fi
    exp_file_info="PNG image data"
    ;;
  *)
    echo "Error in taredi_get_file_one_view: unknown taredi_format_type requested: ${taredi_format_type}"
    taredi_error=997
    return
    ;;
esac

local url_filter=""
if [ ! -z ${taredi_filter+x} ]; then
  local filter_url=$( echo "${taredi_filter}" | sed "s/ /%20/g")
  url_filter="${url_filter_pre}${filter_url}"
fi

#Build full URL
local full_url="${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/views/${taredi_view_id}/${url_spec}maxAge=${taredi_max_age}${url_filter}"
local curl_RC
LogDebug "Curl call:"
LogDebug "curl -s -k \"${full_url}\" -X GET -H \"X-Tableau-Auth:${taredi_token}\" -o ${tempfilename}"
curl -s -k ${full_url} -X GET -H "X-Tableau-Auth:${taredi_token}" -o ${tempfilename}
#get the curl return
curl_RC=$?

local file_info
file_info=$(file $tempfilename)
file_size=$(stat -c%s $tempfilename)

LogDebug "File_info: $file_info"
LogDebug "File_size: $file_size"

LogDebug $curl_RC
if [ $curl_RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_file_one_view: curl call issued a RC=$curl_RC. Cannot continue."
  taredi_error=$curl_RC
  return
fi

# If the resulting file is XML, then it is always possible it contains an error reply
if [[ "$file_info" == *"XML 1.0 document text"* ]]; then
  LogDebug "XML result, check for error"
  grep 'xmlns="http://tableau.com/api"' $tempfilename > /dev/null
  if [ $? -eq 0 ]; then
    LogDebug "XML result is a tableau XML, find error"
    taredi_error=$(cat $tempfilename | grep -oP '(?<=error\ code\=\").*?(?=\"\>)')
    if [ "$taredi_error" = "" ]; then
      Log "We receive a tableau XML, but there is no error code present! It is unclear what the problem is."
      taredi_error=995
    fi
    Log "Please check the contents of this temporary file for more info: $tempfilename"
    Log "XML error result from Tableau call:"
    local vw_tmp_fmtd=$(xmllint --format $tempfilename)
    Log "$vw_tmp_fmtd"
    Log "end of XML error result."
    return
  fi
fi

# validate resulting file type
## check 1: empty file
if [[ "$file_info" == *"empty"* || $file_size -lt 5 ]]; then
  Log "resulting file is empty."
  if [[ $allow_empty -ne 1 ]]; then
    Log "Empty file is not allowed for this type. returning error."
    taredi_error=994
    return
  fi
else
  ## not empty: check 2: compare file info
  if [[ ! "$file_info" == *"$exp_file_info"* ]]; then
    ## file_info does not match. Extra checks for CSV which could show up as ascii
    if [[ "CSV" == "$exp_file_info" ]]; then
      # CSV specific checks. This is needed as CSV files can be analysed by the file command as
      # multiple types: ASCII text, UniCode, UTF-8, even Python code
      # Hence, we will check that the file is a CSV by ensuring each line has at least one comma
      # Please note that single column CSV files will therefore FAIL this test. That case is currently
      # not supported.
      grep -v "," "$tempfilename"
      RC=$?
      if [ $RC -eq 0 ]; then
        Log "Error in taredi_get_file_one_view: we received a file, but it is not in the expected format."
        Log "The expected file typeis a CSV but we could not find a comma on each line of the file."
        Log "Hence, the file cannot be a CSV file and processing will stop here. You can examine the"
        Log "file at this location: $tempfilename"
        taredi_error=996
        return
      fi
    else
      ## no file_info match and not a CSV
      if [[ "Microsoft Excel 2007+" == "$exp_file_info" ]]; then
        ## how can we be sure that it is a valid Excel file? Some Excel files can hide as XML files
        if [[ ! "$file_info" == *"XML"* ]]; then
          ## file_info is not XML nor Excel. Cannot be good then.
          Log "Error in taredi_get_file_one_view: we received a file, but it is not in the expected format."
          Log "The expected file type is an Excel but we received data that indicated that most likely the"
          Log "file is not an EXcel file. You can examine the file at this"
          Log "location: $tempfilename"
          Log "Received file info: $file_info"
          taredi_error=996
          return
        fi
      else
        ## not empty, no file_info match, not a CSV or Excel: Error
        Log "Error in taredi_get_file_one_view: we received a file, but it is not in the expected format"
        Log "Received file info: $file_info"
        Log "Expected file type: $exp_file_info"
        taredi_error=996
        return
      fi
    fi
  fi
fi

## We have no curl RC error, no error in the reply and the file type matches: copy the data file!
cp "$tempfilename" "$taredi_filename"
RC=$?
LogDebug "RC of cp: $RC"
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_file_one_view: copy of the temp file to the output file failed. RC=$RC."
  taredi_error=$RC
  return
fi

##ls -l ${taredi_filename}

}

taredi_get_file_workbook() {
#
# IN:
#     taredi_tableau_url       : the base URL to call
#     taredi_api_vrs           : the API version to use
#     taredi_token             : the token, obtained from taredi_get_token
#     taredi_sitid             : the site id, obtained from taredi_get_token
#     taredi_workbook_id       : the workbook id, obtained from taredi_get_workbook_id
#     taredi_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#     taredi_filename          : the fully qualified file name to produce
#     taredi_max_age           : the maximum age in minutes of cached reports
#
#     this type must use PDF format. Therefore, these options are also mandatory
#       taredi_pdf_page_orientation   : the page orientation: landscape, portrait
#       taredi_pdf_page_type          : the page size: A4, A3, A5, Letter, Legal, Executive, ...
#
#     optional parameters
#       taredi_filter            : a valid filter expression to pass on to Tableau (e.g. jaar=2020)
#
# OUT: taredi_error        : 0 if no error
#                            <>0 if error

if [ ! "$taredi_initialized" = "1" ]; then
  taredi_error="not_initialized"
  return
fi

if [ -z $taredi_max_age ]; then
  Log "Error in taredi_get_file_workbook: parameter taredi_max_age is verplicht"
  taredi_error=999
  return
fi
if [ -z $taredi_temp_folder ]; then
  Log "Error in taredi_get_file_workbook: parameter taredi_temp_folder is verplicht"
  taredi_error=999
  return
fi
if [ -z $taredi_filename ]; then
  Log "Error in taredi_get_file_workbook: parameter taredi_filename is verplicht"
  taredi_error=999
  return
fi

# echo "workbook_id => "${taredi_workbook_id}
local tempfilename="${taredi_temp_folder}/tempoutput.data"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  taredi_error=998
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_file_workbook: Could not create temporary file (error=${RC})."
  taredi_error=$RC
  return
fi
# Delete the touched file
rm -f $tempfilename

local url_filter_pre="&"  ## the prefix before the filter expression, if any
local url_spec="pdf?page_type=${taredi_pdf_page_type}&orientation=${taredi_pdf_page_orientation}&"
local exp_file_info="PDF document"

local url_filter=""
if [ ! -z ${taredi_filter+x} ]; then
  local filter_url=$( echo "${taredi_filter}" | sed "s/ /%20/g")
  url_filter="${url_filter_pre}${filter_url}"
fi

#Build full URL
local full_url="${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/workbooks/${taredi_workbook_id}/${url_spec}maxAge=${taredi_max_age}${url_filter}"
local curl_RC
#echo "Curl call:"
# ADD LOG SVEN
Log "curl -s -k \"${full_url}\" -X GET -H \"X-Tableau-Auth:${taredi_token}\" -o ${tempfilename}"
curl -s -k ${full_url} -X GET -H "X-Tableau-Auth:${taredi_token}" -o ${tempfilename}
#get the curl return
curl_RC=$?

local file_info
file_info=$(file $tempfilename)

LogDebug "File_info: $file_info"

LogDebug "curl RC: $curl_RC"
if [ $curl_RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_file_workbook: curl call issued a RC=$RC. Cannot continue."
  taredi_error=$curl_RC
  return
fi

# If the resulting file is XML, then it is always possible it contains an error reply
if [[ "$file_info" == *"XML 1.0 document text"* ]]; then
  LogDebug "XML result, check for error"
  grep 'xmlns="http://tableau.com/api"' $tempfilename > /dev/null
  if [ $? -eq 0 ]; then
    LogDebug "XML result is a tableau XML, find error"
    taredi_error=$(cat $tempfilename | grep -oP '(?<=error\ code\=\").*?(?=\"\>)')
    if [ "$taredi_error" = "" ]; then
      Log "We receive a tableau XML, but there is no error code present! It is unclear what the problem is."
      taredi_error=995
    fi
    Log "XML error result from Tableau call:"
    local wb_tmp_fmtd=$(xmllint --format $tempfilename)
    Log "$wb_tmp_fmtd"
    xmllint --format $tempfilename
    Log "end of XML error result."
    return
  fi
fi

# validate resulting file type
# empty file processing nog toe te voegen!!!!
if [[ "$file_info" == *"empty"* ]]; then
  Log "resulting file is empty. This case is not yet covered. Returning error"
  taredi_error=995
  return
fi
if [[ ! "$file_info" == *"$exp_file_info"* ]]; then
  Log "Error in taredi_get_file_workbook: we received a file, but it is not in the expected format"
  Log "Received file info: $file_info"
  Log "Expected file type: $exp_file_info"
  taredi_error=996
  return
fi

## We have no curl RC error, no error in the reply and the file type matches: copy the data file!
cp $tempfilename $taredi_filename
RC=$?
LogDebug "RC of cp: $RC"
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_file_workbook: copy of the temp file to the output file failed. RC=$RC."
  taredi_error=$RC
  return
fi

}

taredi_get_datasource_id() {
#
# IN: taredi_datasource_name   : datasource name (can contains blanks)
#     taredi_project_name      : the name of the project where the datasource reside
#     taredi_tableau_url       : the base URL to call
#     taredi_api_vrs           : the API version to use
#     taredi_token             : the token, obtained from taredi_get_token
#     taredi_sitid             : the site id, obtained from taredi_get_token
#     taredi_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: taredi_error        : 0 if no error
#                            <>0 if error
#      taredi_datasource_id    : the datasource id for use in further calls
#

if [ ! "$taredi_initialized" = "1" ]; then
  taredi_error="not_initialized"
  return
fi

local tempfilename="${taredi_temp_folder}/tempdatasource.xml"
# Check the temp file does not exist yet
if [ -f "$tempfilename" ]; then
  Log "Temp folder already contains an output file. Cannot continue"
  taredi_error=998
  return
fi
# Check if we can create the temp file
touch $tempfilename
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_datasource_id: Could not create temporary file (error=${RC})."
  taredi_error=$RC
  return
fi
# Delete the touched file
rm -f $tempfilename

#get the curl return
local pre_datasource-info=""

LogDebug "curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/datasources  -X GET -H "X-Tableau-Auth:${taredi_token}" -o $tempfilename"

curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/datasources  -X GET -H "X-Tableau-Auth:${taredi_token}" -o $tempfilename

RC=$?
LogDebug $RC
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_datasource_id: curl call issued a RC=$RC. Cannot continue."
  taredi_error=$RC
  return
fi

local ds_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$ds_info_fmtd"

taredi_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$taredi_error" = "" ]; then
  taredi_error=0
fi
LogDebug "taredi_error: $taredi_error"
if [ $taredi_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_datasource_id: curl call returned an XML error code."
  Log "$ds_info_fmtd"
  return
fi

#no error, try to find the datasource id
# new:
LogDebug "Datasource name: ${taredi_datasource_name}"
LogDebug "Project name   : ${taredi_project_name}"

searchString='string(//datasource[@name="'${taredi_datasource_name}'"] //project[@name="'${taredi_project_name}'"]/../@id)'

LogDebug "cat $tempfilename | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | xmllint --xpath "${searchString}" -"

taredi_datasource_id=$(cat $tempfilename  | xmllint --format - | sed -n '/<datasources>/,/<\/datasources\>/p' | xmllint --xpath "$searchString" -)

if [ "$taredi_datasource_id" = "" ]; then
  taredi_error=999
  Log "Error in taredi_get_datasource_id: curl call did not return a datasource id but no error was issued either."
  Log "Please verify that the specified datasource '${taredi_datasource_name}' exists and is accessible to the account '${taredi_usr}'."
  return
fi

#ensure we only have 1 entry
ds_count=$(echo "$taredi_datasource_id" | wc -l)
LogDebug "ds_count=${ds_count}"
if [ ! "$ds_count" = "1" ]; then
  taredi_error=989
  Log "the call for the required datasource returned more than one matching datasource!"
  Log "The xml result was:"
  Log "$ds_info_fmtd"
  Log "The resulting list of matching datasource ids is:"
  Log "$taredi_datasource_id"
  Log "The number of matching datasources is: $ds_count"
  return
fi
LogDebug "datasource_id => "${taredi_datasource_id}

}

taredi_refresh_datasource_id() {
#
# IN: taredi_datasource_id     : datasource id
#     taredi_tableau_url       : the base URL to call
#     taredi_api_vrs           : the API version to use
#     taredi_token             : the token, obtained from taredi_get_token
#     taredi_sitid             : the site id, obtained from taredi_get_token
#     taredi_temp_folder       : the fully qualified path to a temp folder that is unique to this call
#
# OUT: taredi_error        : 0 if no error
#                            <>0 if error
#

if [ ! "$taredi_initialized" = "1" ]; then
  taredi_error="not_initialized"
  return
fi

#Start the refresh now
LogDebug "curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/datasources${taredi_datasource_id}/refresh  -X POST -H "X-Tableau-Auth:${taredi_token}" -o $tempfilename"

curl -s -k ${taredi_tableau_url}/api/${taredi_api_vrs}/sites/${taredi_sitid}/datasources/${taredi_datasource_id}/refresh  -X POST -H "X-Tableau-Auth:${taredi_token}" -o $tempfilename

RC=$?
LogDebug $RC
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_datasource_id: curl call issued a RC=$RC. Cannot continue."
  taredi_error=$RC
  return
fi

local ds_info_fmtd=$(xmllint --format "$tempfilename")
LogDebug "$ds_info_fmtd"

taredi_error=$(grep -oP '(?<=error\ code\=\").*?(?=\"\>)' "$tempfilename")
if [ "$taredi_error" = "" ]; then
  taredi_error=0
fi
LogDebug "taredi_error: $taredi_error"
if [ $taredi_error -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in taredi_get_datasource_id: curl call returned an XML error code."
  Log "$ds_info_fmtd"
  return
fi

}

