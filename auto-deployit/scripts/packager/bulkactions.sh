#!/bin/bash

#### bulkactions.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script processes a list of ticket numbers
#
# Mandatory arguments are:
#  ENV                     : De omgeving waarvoor gewerkt wordt
#  ACTION                  : De uit te voeren actie
#
# Currently implemented actions are:
# "05 init release"
# "10 validatie tickets"
# "20 stage download"
# "30 stop"
# "31 stop one ADC"
# "40 deploy blok"
# "50 validatie blok"
# "60 start"
# "61 start one ADC"
# "80 clean"
#
#
#################################################################
# Change history
#################################################################
# dexa # 01/07/18   #
# vevi # 07/09/18   # Added '05 init release' and '80 clean'
# vevi # 13/09/18   # Auto-create blokfiles-folder and use tee during validation
#################################################################
#

ScriptName="bulkactions.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

####### Get Arguments

ArgEnv=$1
ArgAction=$2
## ArgRelease=$3
Arg4=$3 ## Will be used as release name for '05 init release'
Arg5=$4

####### Initialisations

SshCommand="SSH_to_appl_srv"
BulkActionsRootFolder="/data/deploy-it/bulk-actions"
ReleaseFile="${BulkActionsRootFolder}/current_release.txt"
## Below file is used in legacy code
ReleaseMappingsFile="${BulkActionsRootFolder}/release-mapping.csv"
##ArgRelease="Indep - 2017 December 1 - 13/12"
ArgRelease=""

TmpFld=""
declare -a TAStatus
declare -a TARelease
declare -a TAADC
declare -a TAADCType
declare -a TAOK
ADCArrayCount=0
declare -a AAADC
TicketArrayCount=0
declare -a TicketArray
declare -a TABlokId

####### Functions

AddTicketToArray()
{
  local NewTicketNr=$1
  local BlokId=$2
  local i=0
  local found=0
  for ((i=0;i<$TicketArrayCount;i++)) do
    if [ "${TicketArray[$i]}" == "$NewTicketNr" ]; then
      echo "Duplicate on ticket Nr $NewTicketNr"
      if [ "{$TABlokId[$i]}" == "$BlokId" ]; then
        echo "WARNING: duplicate ticket $NewTicketNr !"
      else
        deploy_error $DPLERR_BulkActionsDupTicketinBlokfiles $NewTicketNr $BlokId ${TABlokId[$i]}
      fi
      found=1
    fi
  done
  if  [ "$found" -eq "0" ]; then
    TicketArray[$TicketArrayCount]=$NewTicketNr
    TABlokId[$TicketArrayCount]=$BlokId
    TicketArrayCount=$((TicketArrayCount + 1))
  fi
  echo "Ticket $NewTicketNr added."
}

AddADC()
{
  local i=0
  local found=0
  for ((i=0;i<$ADCArrayCount;i++)) do
    if [ "${AAADC[$i]}" == "$NewADC" ]; then
      echo "Have it already"
      found=1
    fi
  done
  if  [ "$found" -eq "0" ]; then
    AAADC[$ADCArrayCount]=$NewADC
    ADCArrayCount=$((ADCArrayCount + 1))
  fi
}

DeployOneTicket()
{
  local TheTicket=$1
  echo "Deploying ticket $TheTicket"
  cd "$TmpFld"
  TmpFld="./"
  ArgTicketNr=$TheTicket
  Handover_GetTicketInfo
  TmpFld=$(pwd)
  echo "$TmpFld"
  local TheStatus=$TicketStatus
  local TheRelease=$TicketReleaseNm
  ###TraceIT ADC naamgeving omzetten naar DeployIT
  ADCTRC=$TicketADCTRC
  ConvertADCTRCToDeployITADC
  local TheADC=$DeployITADC
  local TheADCType=$DeployITType
  local TheADCJob=$DeployITJob
  ## Inlezen van Svn credentials
  source ${ConfigDataFolder}/credentials/svn.password.properties
  ## Samenstellen van alle Svn opties
  local URLCredentials=" -u ${SvnUsername}:${SvnPassword} "
  local DeployTarget="ACTIVATE"
  curl -X POST $URLCredentials "${JENKINS_URL}job/${ArgEnv}/job/Deploy/job/${TheADCJob}/buildWithParameters?TICKETNR=${TheTicket}&DEPLOY_TARGET=${DeployTarget}&delay=0sec"

}

ValidateOneTicket()
{
  local TheTicket=$1
  echo "Validating ticket $TheTicket"
  cd "$TmpFld"
  TmpFld="./"
  ArgTicketNr=$TheTicket
  Handover_GetTicketInfo
  TmpFld=$(pwd)
  echo "$TmpFld"
  local TheStatus=$TicketStatus
  local TheRelease=$TicketReleaseNm
  ###TraceIT ADC naamgeving omzetten naar DeployIT
  ADCTRC=$TicketADCTRC
  ConvertADCTRCToDeployITADC
  local TheADC=$DeployITADC
  local TheADCType=$DeployITType
  ## Inlezen van Svn credentials
  source ${ConfigDataFolder}/credentials/svn.password.properties
  ## Samenstellen van alle Svn opties
  local URLCredentials=" -u ${SvnUsername}:${SvnPassword} "
  local LastBuildNumber=$(curl -X POST $URLCredentials "${JENKINS_URL}job/${ArgEnv}/job/Deploy/job/${TheADC^^}%20${TheADCType}/lastBuild/buildNumber")
  local LastSuccessfulBuildNumber=$(curl -X POST $URLCredentials "${JENKINS_URL}job/${ArgEnv}/job/Deploy/job/${TheADC^^}%20${TheADCType}/lastSuccessfulBuild/buildNumber")
  if [ $LastBuildNumber -ne $LastSuccessfulBuildNumber ]; then
    echo "Warning: For the ADC $TheADC deploy type $TheADCType there seems to be a failed deployment. Please investigate that job:"
    echo "${JENKINS_URL}job/${ArgEnv}/job/Deploy/job/${TheADC^^}%20${TheADCType}/"
  fi
}

ProcessBlokFile()
{
BlokFile=$1
local Action=$2
echo "Processing $BlokFile with action $Action"
local linecount=1
local BlokId=${BlokFile%.*}
while read ticketnr rest || [[ -n "$ticketnr" ]]; do
  if [ "$ticketnr" = "" ]; then
    echo "Warning - blank line detected in blok file. Skipping."
  else
    if [ "$rest" != "" ]; then
      deploy_error $DPLERR_BulkActionsSyntaxBlokfiles $BlokFile $linecount
    else
      if [ "$Action" = "AddTicketArray" ]; then
        AddTicketToArray $ticketnr $BlokId
      fi
      if [ "$Action" = "DeployTickets" ]; then
        DeployOneTicket $ticketnr
      fi
      if [ "$Action" = "ValidateTickets" ]; then
        ValidateOneTicket $ticketnr
      fi
    fi
  fi
  linecount=$((linecount + 1))
done < ${BlokFile}

}

ProcessAllBlokFiles()
{

if [ ! -d "${ReleaseBaseFolder}/blokfiles" ]; then
  deploy_error $DPLERR_BulkActionsMissingBlokfiles  "${ReleaseBaseFolder}/blokfiles"
fi
cd "${ReleaseBaseFolder}/blokfiles"
for fname in *.txt
do
  if [ ! -e "$fname" ]; then
    ## als we hier komen, dan is fname = "*.txt" en dus is er geen .txt file gevonden
    deploy_error $DPLERR_BulkActionsMissingBlokfiles  "${ReleaseBaseFolder}/blokfiles"
  fi

  ProcessBlokFile $fname "AddTicketArray"
done

}

ProcessTicketArray() {
local i=0
CountOK=0
CountNOK=0
for ((i=0;i<$TicketArrayCount;i++)) do
  ArgTicketNr=${TicketArray[$i]}
  echo "lookup for ticket $ArgTicketNr"
  cd "$TmpFld"
  TmpFld="./"
  Handover_GetTicketInfo
  TmpFld=$(pwd)
  echo "$TmpFld"
  TAStatus[$i]=$TicketStatus
  TARelease[$i]=$TicketReleaseNm
  ###TraceIT ADC naamgeving omzetten naar DeployIT
  ADCTRC=$TicketADCTRC
  ConvertADCTRCToDeployITADC
  TAADC[$i]=$DeployITADC
  TAADCType[$i]=$DeployITType
  ### Voeg ADC toe aan AAADC
  NewADC=$DeployITADC
  AddADC
  ###    Tests
  IsOK=1
  if [ "${TicketStatus:0:3}" == "$ArgEnv" ]; then
    ## We hebben een status binnen dezelfde omgeving als waarvoor we werken.
    SubStatus="${TicketStatus:4}"
  else
    ## Rapporteer foute status
    echo "foute ticket status gevonden voor ticket $ArgTicketNr."
    IsOK=0
  fi
  TAOK[$i]=$IsOK
  if [ "$IsOK" -eq "1" ]; then
    CountOK=$((CountOK + 1))
  else
    CountNOK=$((CountNOK + 1))
  fi
  ###    Specific actions
  if [ "$TicketAction" == "Download" ]; then
    cd "$ReleaseBaseFolder"
    mkdir -p "Tickets/TI${ArgTicketNr}"
    cd "Tickets/TI${ArgTicketNr}"
    ### Call Handover tool for download
    Handover_Download_Local
  fi
  if [ "$TicketAction" == "Confirm" ]; then
    cd "$ReleaseBaseFolder"
    cd "Tickets/TI${ArgTicketNr}"
    ### Call Handover tool for confirm
    Handover_Confirm
  fi
done
}

WriteStartStopDeck() {
cd "$ReleaseBaseFolder"
mkdir -p "start_stop"
cd "start_stop"
rm -f "stop.txt"
touch "stop.txt"
  local i=0
  for ((i=0;i<$ADCArrayCount;i++)) do
    echo "${AAADC[$i]}" >> "stop.txt"
  done
cp "stop.txt" "start.txt"
}

WriteValidatie() {
cd "$ReleaseBaseFolder"
rm -rf "validatie"
mkdir -p "validatie"

local i=0
for ((i=0;i<$TicketArrayCount;i++)) do
  ArgTicketNr=${TicketArray[$i]}
  TicketStatus=${TAStatus[$i]}
  InfoLine="${ArgTicketNr};${TicketStatus};${TARelease[$i]};${TAADC[$i]};${TABlokId[$i]}"
  echo "$InfoLine" >> "validatie/${TABlokId[$i]}_info.txt"
  ## Test 1 - matching Release
  if [ "${TARelease[$i]}" != "$ArgRelease" ]; then
    echo "Ticket ${ArgTicketNr} in blok ${TABlokId[$i]} zit in een andere release." | tee -a  "validatie/warning.txt"
  fi
  if [ "${TicketStatus:0:3}" != "$ArgEnv" ]; then
    echo "Ticket ${ArgTicketNr} staat niet in een geldige status (foute omgeving)." | tee -a "validatie/warning.txt"
  else
    if [ ${TicketStatus:4:10} = "Uitgevoerd" ]; then
      echo "Ticket ${ArgTicketNr} staat niet in een geldige status (reeds uitgevoerd)." | tee -a "validatie/warning.txt"
    fi
  fi
done
}

DoStopADC()
{
local ADCtostop=$1
local ADCtostopUpperCase=${ADCtostop^^}
## Inlezen van Svn credentials
source ${ConfigDataFolder}/credentials/svn.password.properties
## Samenstellen van alle Svn opties
local URLCredentials=" -u ${SvnUsername}:${SvnPassword} "
curl -X POST $URLCredentials "${JENKINS_URL}job/${ArgEnv}/job/Bulk%20Actions/job/31%20stop%20one%20ADC/buildWithParameters?ADC=${ADCtostopUpperCase}&delay=0sec"
### curl -X POST $URLCredentials ${ArgURL}/build?delay=0sec

}

ExecuteStopDeck()
{
cd "$ReleaseBaseFolder"
cd "start_stop"
echo "Reading stop.txt"
if [ ! -e "stop.txt" ]; then
    deploy_error $DPLERR_FileNotFound "$ReleaseBaseFolder/start_stop/stop.txt"
fi
local linecount=1
while read ADCtostop || [[ -n "$ADCtostop" ]]; do
  if [ "$ADCtostop" = "" ]; then
    echo "Warning - blank line detected in blok file. Skipping."
  else
    DoStopADC $ADCtostop
  fi
  linecount=$((linecount + 1))
done < "stop.txt"

}

ExecuteOneStop()
{
cd "$ReleaseBaseFolder"
ArgAppl=$Arg4
echo "Requesting stop for ADC $ArgAppl"
GetCntInfo
## Output: $TheCnt, $TheUsr, $TheFld
GetSrvList
##     output variables : $SrvCount, $SrvList[1..$SrvCount]
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    $SshCommand $TargetServer "sudo /etc/rc.d/init.d/jboss-${TheUsr}.sh stop"
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_StopContainerFailed $TargetServer $TheUsr $RC
    fi
  done
}


DoStartADC()
{
local ADCtostart=$1
local ADCtostartUpperCase=${ADCtostart^^}
## Inlezen van Svn credentials
source ${ConfigDataFolder}/credentials/svn.password.properties
## Samenstellen van alle Svn opties
local URLCredentials=" -u ${SvnUsername}:${SvnPassword} "
curl -X POST $URLCredentials "${JENKINS_URL}job/${ArgEnv}/job/Bulk%20Actions/job/61%20start%20one%20ADC/buildWithParameters?ADC=${ADCtostartUpperCase}&delay=0sec"

}

ExecuteStartDeck()
{
cd "$ReleaseBaseFolder"
cd "start_stop"
echo "Reading start.txt"
if [ ! -e "start.txt" ]; then
    deploy_error $DPLERR_FileNotFound "$ReleaseBaseFolder/start_stop/start.txt"
fi
local linecount=1
while read ADCtostart || [[ -n "$ADCtostart" ]]; do
  if [ "$ADCtostart" = "" ]; then
    echo "Warning - blank line detected in blok file. Skipping."
  else
    DoStartADC $ADCtostart
  fi
  linecount=$((linecount + 1))
done < "start.txt"

}

ExecuteOneStart()
{
cd "$ReleaseBaseFolder"
ArgAppl=$Arg4
echo "Requesting start for ADC $ArgAppl"
GetCntInfo
## Output: $TheCnt, $TheUsr, $TheFld
GetSrvList
##     output variables : $SrvCount, $SrvList[1..$SrvCount]
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    $SshCommand $TargetServer "sudo /etc/rc.d/init.d/jboss-${TheUsr}.sh manualstart"
    RC=$?
    if [ $RC -ne 0 ]; then
      if [ $RC -eq 1 ]; then
        echo "Warning: Container was probably already started."
      else
        deploy_error $DPLERR_StartContainerFailed $TargetServer $TheUsr $RC
      fi
    fi
  done
}

ExecuteDeployBlok()
{
cd "$ReleaseBaseFolder"
ArgBlokFile=$Arg4
cd "${ReleaseBaseFolder}/blokfiles"
local fname="${ArgBlokFile}"
if [ ! -e "$fname" ]; then
  ## als we hier komen, dan is fname = "*.txt" en dus is er geen .txt file gevonden
  deploy_error $DPLERR_BulkActionsMissingBlokfiles  "${ReleaseBaseFolder}/blokfiles/${fname}"
fi
ProcessBlokFile $fname "DeployTickets"

}

ValidateDeployBlok()
{
cd "$ReleaseBaseFolder"
ArgBlokFile=$Arg4
cd "${ReleaseBaseFolder}/blokfiles"
local fname="${ArgBlokFile}"
if [ ! -e "$fname" ]; then
  ## als we hier komen, dan is fname = "*.txt" en dus is er geen .txt file gevonden
  deploy_error $DPLERR_BulkActionsMissingBlokfiles  "${ReleaseBaseFolder}/blokfiles/${fname}"
fi
ProcessBlokFile $fname "ValidateTickets"

}
CreateReleaseFolder()
{
## Write release folder, and if necessary also the ENV folder (eg. ACC)

EnvBaseFolder="${BulkActionsRootFolder}/${ArgEnv}"
if [ ! -d "$EnvBaseFolder" ]; then
  echo "**INFO** Enviroment folder missing, creating folder for ${ArgEnv}."
  mkdir -p "$EnvBaseFolder"
fi

ReleaseBaseFolder="${EnvBaseFolder}/${TheReleaseFolder}"

if [  -d "$ReleaseBaseFolder" ]; then
  echo "**INFO** Release folder already created, skipping creation."
else
    echo "**INFO** Creating release folder: ${TheReleaseFolder}."

  mkdir -p "$ReleaseBaseFolder/blokfiles"

fi
chmod g+rw -R $ReleaseBaseFolder

cd "$BulkActionsRootFolder"
}

WriteReleaseFile()
 {
WriteValidatie
 cd "$BulkActionsRootFolder"

if [ -e ${ReleaseFile} ]; then
  local ReleaseFileContent=$(<$ReleaseFile)
  echo "**WARN** current_release.txt already exists, previous content: ${ReleaseFileContent}"
fi
echo "$ArgRelease" > "$ReleaseFile"
echo "**INFO** current_release.txt created with release: ${ArgRelease}"

}

CheckAndSetReleaseName()
{
  ## Read release from paramater provided
ArgReleaseName="$Arg4"
if [ -z "$ArgReleaseName" ]; then
        echo "**ERROR** Release name not provided, cannot continue."
        exit 16
fi
ArgRelease="$ArgReleaseName"
}
ReadReleaseFromFile()
{
  ## Read release fron current_release.txt
cd "$BulkActionsRootFolder"
if [ -e ${ReleaseFile} ]; then
  ArgRelease=$(<$ReleaseFile)
  echo "**INFO** Current release is set to: ${ArgRelease}"
else
    echo "**ERROR** No release found since current_release.txt is missing. Please run action '05 init release' or create this file manually at \'${BulkActionsRootFolder}\'."
    exit 16
fi

}
SetCleanReleaseFolderName()
{
  TheReleaseFolder=$(echo "$ArgRelease" | sed -e 's/[^A-Za-z0-9._-]/_/g')
}
CleanupFiles()
{

 echo "**INFO** Cleaning up files"
 echo "**INFO** Removing all files for release ${ArgRelease}"
 rm -rf "$ReleaseBaseFolder"
 echo "**INFO** Removing current_release.txt"
 cd "$BulkActionsRootFolder"
 rm -rf "$ReleaseFile"

}

######### Main processing

#### init release from parameter when action is 05, or from current_release.txt
if [ "$ArgAction" == "05 init release" ]; then
  CheckAndSetReleaseName
else
  ReadReleaseFromFile
fi
SetCleanReleaseFolderName
LogLineDEBUG2 "TheReleaseFolder  = '${TheReleaseFolder}'"

#### Check for 05 action first; to make sure folders exist when checking for them below
if [ "$ArgAction" == "05 init release" ]; then
  CreateReleaseFolder
  WriteReleaseFile
fi

#### Test if the Release specific folder exists

if [ -d "${BulkActionsRootFolder}/${ArgEnv}/${TheReleaseFolder}" ]; then
  ReleaseBaseFolder="${BulkActionsRootFolder}/${ArgEnv}/${TheReleaseFolder}"
  cd "$ReleaseBaseFolder"
else
  deploy_error $DPLERR_BulkActionReleaseFolderMissing $ArgEnv "$TheReleaseFolder"
fi
printf -v TmpFld "%q" "${ReleaseBaseFolder}/tmp"
mkdir "$TmpFld"

GetEnvData
SSHTargetUser=$UnixUserOnApplSrv

if [ "$ArgAction" == "10 validatie tickets" ]; then
  ProcessAllBlokFiles
  TicketAction="Validate"
  ProcessTicketArray
  WriteStartStopDeck
  WriteValidatie
fi

if [ "$ArgAction" == "20 stage download" ]; then
  ProcessAllBlokFiles
  TicketAction="Download"
  ProcessTicketArray
fi

if [ "$ArgAction" == "30 stop" ]; then
  ExecuteStopDeck
fi

if [ "$ArgAction" == "31 stop one ADC" ]; then
  ExecuteOneStop
fi

if [ "$ArgAction" == "40 deploy blok" ]; then
  ExecuteDeployBlok
fi

if [ "$ArgAction" == "50 validatie blok" ]; then
  ValidateDeployBlok
fi

if [ "$ArgAction" == "60 start" ]; then
  ExecuteStartDeck
fi

if [ "$ArgAction" == "61 start one ADC" ]; then
  ExecuteOneStart
fi

if [ "$ArgAction" == "70 confirm" ]; then
  ProcessAllBlokFiles
  TicketAction="Confirm"
  ProcessTicketArray
fi
if [ "$ArgAction" == "80 clean" ]; then
  CleanupFiles
fi

exit 0
