#!/bin/bash

#### delphiinst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# vevi     # 27/09/2018    # 1.0-0 initial POC versie
# dexa     # 08/03/2019    # 1.0.1 corr typo in cp and fetch RC
# dexa     # 11/03/2019    # 1.0.2 remove trailing / in cp command
# dexa     # 07/05/2019    # 1.1.0 activate Metadata update
# lekri    # 12/11/2021    # 1.1.1 # ondersteuning ACC & SIM TraceIT/4me
#############################################################################
#

ScriptName="delphiinst.sh"
ScriptVersion="1.1.1"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

DebugLevel=3
ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3
ArgDoel=$4
ArgExtraOpts=$5

echo "Script ${ScriptName} started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"
echo "  DOEL = '${ArgDoel}'"
echo "  EXTRA OPTIONS = '${ArgExtraOpts}'"

## Call GetEnvData
GetEnvData

#SshCommand="${SshScriptsFolder}/ssh_srv_taccdeps_key.sh"
#ScpPutCommand="${SshScriptsFolder}/scp_srv_tzfaccdeps_put.sh"
#ScpGetCommand="${SshScriptsFolder}/scp_srv_toptoa_get.sh"
SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="delphi-inst"
MaakTmpTicketFolder
cd ${TmpTicketFolder}

TmpFld=$TmpTicketFolder
TheEnv=$ArgEnv
TheADC=$ArgAppl
## Get default settings based on the ENV and ADC
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level
EchoDeployITSettings

StapDoelBepalen $ArgDoel

Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_ACTIVATE ]; then
  echo "WARN: Activatiefase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi



## Call Handover tool to download ticket material
Handover_Download_Local

# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

OnlyDeletes=0 ## Default value
SQLCommand=""
SQLOutput=""
# Check the contents of the deleted and downloaded files
# Test 1: ensure deleted.txt AND downloaded.txt are NOT BOTH empty
if [ ! -s ${HandoverDownloadedList} ]; then
  if [ ! -s ${HandoverDeletedList} ]; then
    echo "ERROR: Ticket bevat geen data files (geen nieuwe, gewijzigde of verwijderde files). DeployIT kan dus niets doen."
  fi
  ## Als we dit punt bereiken, dan is er GEEN downloaded file maar wel deleted files.
  ## Dus heeft het geen zin om de downloaded file te parsen.
  OnlyDeletes=1
fi


UpdateMetadataForFiles()
{
##Execute exiftool command
LogLineINFO "Starting updating of metadata for files"
LowerADC=${TheADC,,}
SqlPath=${TheEnv}\\${LowerADC/_exe/''}
LogLineDEBUG "Sql field NWK_PTH value=\"${SqlPath}\"."

cd "${TmpTicketFolder}/${TheADC,,}"
for fileName in $(find . -type f -name '*.exe' ); do
  LogLineDEBUG "Start metadata processing for file $fileName"
  fileExtension=${fileName##*.}
  fileExtension=${fileExtension,,}
  ExifInfo=$(perl "${ScriptPath}/tools/exiftool/exiftool" -FileSize -FileVersion -FileModifyDate $fileName)
  readarray -t ExifInfoArray <<<"$ExifInfo"

  InfoFileSize=${ExifInfoArray[0]##*:}
  InfoFileVersion=${ExifInfoArray[1]##*:}
  LogLineDEBUG "Obtained file size: $InfoFileSize"
  LogLineDEBUG "Obtained file vrs : $InfoFileVersion"
    ## Removing trailing whitespace
  InfoFileVersion="$(echo -e "${InfoFileVersion}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  InfoFileCreated=${ExifInfoArray[2]#*:}

    ## Convert date format
  InfoFileDate=$(echo $InfoFileCreated | awk '{print $1;}')
  InfoFileDate=${InfoFileDate/:/-}
  InfoFileDate=${InfoFileDate/:/-}

  InfoFileDate=$(date -d "${InfoFileDate}" "+%d-%b-%y")
  InfoFileDate=${InfoFileDate^^}
  LogLineDEBUG "Obtained file date: $InfoFileDate"

  ## Convert to KB if MB size
  if [[ $(echo ${InfoFileSize^^} | grep 'MB') ]]; then
    InfoFileSize=${InfoFileSize^^}
    FileSizeMb=${InfoFileSize/MB/''}
    FileSizeKb=$(awk "BEGIN {print $FileSizeMb*1024}") 
    FileSizeKb=$(echo $FileSizeKb |  awk '{print int($1+0.5)}')
    FileSizeKb=$(echo "$FileSizeKb" | rev | sed "s#[[:digit:]]\{3\}#&.#g" | rev) 
    InfoFileSize="${FileSizeKb}KB"
    LogLineDEBUG "Converted file size: $InfoFileSize"
  fi

  filebaseName=$(basename $fileName)
  SQLCommand="SELECT APPL_CDE,NAM_EXE,NWK_PTH FROM APL WHERE NWK_PTH LIKE '%${SqlPath}%' AND NAM_EXE LIKE '${filebaseName}';"
  ExecuteSqlCommand
  ## Check if we have matching records in the DB for this EXE
  if [[ ! $(echo $SQLOutput | grep "no rows selected") ]]; then
     SQLCommand="UPDATE APL SET SZE_EXE='${InfoFileSize}',VRS_EXE='${InfoFileVersion}',DTE_EXE='${InfoFileDate}'  WHERE NWK_PTH LIKE '%${SqlPath}%' AND NAM_EXE LIKE '${filebaseName}';"
    ExecuteSqlCommand
    LogLineINFO "MetaData has been updated for \"$fileName\"."
  else
    LogLineWARN "For file \"$fileName\" no record was found in de APL table! Hence, no update was performed."
  fi

done


}




CopyFilesToMount()
{

LogLineInfo "Starting copy files"

TargetFolder=${TheADC,,}
TargetFolder=${TargetFolder/_exe/''}
TheDelphiTargetPath="/mnt/win-apps-${ArgEnv,,}/${TargetFolder}"
if [[ ! -d ${TheDelphiTargetPath} ]]; then
  echo "Deploy folder \"${TheDelphiTargetPath}\" does not exist, cannot continue deployment"
  exit 16
fi
LogLineDEBUG "Copying files from \"${TmpTicketFolder}/${TheADC,,}\" to \"${TheDelphiTargetPath}\""
cp -r  ${TmpTicketFolder}/${TheADC,,}/* ${TheDelphiTargetPath}/
RC=$?
if [ $RC -ne 0 ]; then
    echo "Could not copy the files to the mounted folder."
    exit 16
else
  LogLineINFO "Alle bestanden werden goed gecopieerd."
fi
}

ConfirmTicket()
{
  cd ${TmpTicketFolder}
  Handover_Confirm
}

ExecuteSqlCommand()
{

GetDBConfig
LogLineDEBUG "Sending SQL command: $SQLCommand"
SQLOutput=$(echo "set heading off;
${SQLCommand}" | ${SQLPLUS_PATH})
SQLRC=$?
  LogLineDEBUG "SQL RC    : $SQLRC"
  LogLineDEBUG "SQL output: $SQLOutput"
}
GetDBConfig()
{
#  DB_HOST="TLS_PRD"
  DB_USER="/"
  DB_PWD=""
  DB_HOST="ARG_${TheEnv^^}"
  SQLPLUS_PATH="/usr/bin/sqlplus -s ${DB_USER}@${DB_HOST}"

}

CopyFilesToMount
UpdateMetadataForFiles

echo "All scripts have been executed to all target machines"

TmpFolder=${TmpTicketFolder}
CleanTmpFolder
echo "Script" ${ScriptName}  "ended."
