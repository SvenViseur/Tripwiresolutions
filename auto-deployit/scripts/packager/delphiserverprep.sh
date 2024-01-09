#!/bin/bash

#### delphiserverprep.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# It will prepare the provided binaries from the oplevering-folder
# extract the tar-file, run a replace-tool call re-tar the binaries.
# And commit it to the svn repo.
#

# Command line options:
#     APPL    : The ADC name being deployed
#     TICKETNR    : The ticket number being deployed
#     ENV   : The target environment
#
#################################################################
# Change history
#################################################################
# dexa  # 17/09/2019  # 1.0.0 # Initial version
# lekri # 12/11/2021  # 1.0.1 # ondersteuning ACC & SIM TraceIT/4me
#################################################################
ScriptName="delphiserverprep.sh"
ScriptVersion="1.0.1"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3
ArgDoel=$4
ArgExtraOpts=$5

LogLineINFO "Script" ${ScriptName}  "started."
LogLineINFO "Options are:"
LogLineINFO "  APPL = '${ArgAppl}'"
LogLineINFO "  TICKETNR = '${ArgTicketNr}'"
LogLineINFO "  ENV = '${ArgEnv}'"
LogLineINFO "  DOEL = '${ArgDoel}'"
LogLineINFO "  EXTRA OPTIONS = '${ArgExtraOpts}'"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData

SshCommand="${SshScriptsFolder}/ssh_srv_taccdeps_key.sh"
ScpPutCommand="${SshScriptsFolder}/scp_srv_taccdeps_put.sh"
ScpGetCommand="${SshScriptsFolder}/scp_srv_toptoa_get.sh"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="delphiserver-prep"
MaakTmpTicketFolder
cd ${TmpTicketFolder}

TmpFld=$TmpTicketFolder
TheEnv=$ArgEnv
TheADC=$ArgAppl

## Get default settings based on the ENV and ADC
GetDeployITSettings

## ExtraOpts is hier nodig, omdat GetDynOplOmg via TraceIT gebeurt
Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

## GetDynOplOmg:
## In: ArgTicketNr, TmpFld    Out: TheOpl
GetDynOplOmg

DebugLevel=$DeployIT_Debug_Level
Replace_Tool_Defaults
EchoDeployITSettings
LoggingBaseFolder="${ConfigNfsFolderRepllogOnServer}/target_${ArgEnv}/"
mkdir -p $LoggingBaseFolder

StapDoelBepalen $ArgDoel

## Opnieuw ExtraOpts parsen, want die kunnen StapDoel wijzigen!
Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_UPD_TICKET ]; then
  echo "WARN: Deploy preparation niet uitgevoerd wegens huidig doel"
  exit 0
fi

## output: $TheUsr $TheFld
GetEnvData
## Determine the target elements for this predeploy:
## - the BOF server: $TheBOFServer
## - the root path where to deploy: $TheBOFTargetPath


## Maak locale folder klaar voor downloads
## Clean up local traces of previous runs of this same ticket
rm -rf ${TmpTicketFolder}
mkdir  ${TmpTicketFolder}
cd ${TmpTicketFolder}

## Download ticket materiaal
Handover_Download_Local
# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

line1=$(cat ${HandoverDownloadedList} ${HandoverDeletedList} | head -n 1)
echo "line1 = " ${line1}
## expected format: OK      <adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
echo "line1 (stripped) = " ${line1}
firstpart=${line1%%"/"*}

# Save the ADC with capitals.
DerivedADC=${firstpart^^}
## Compare the requested ADC with the one derived from the HODL file
if [ "$ArgAppl" = "$DerivedADC" ]; then
  LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
else
  echo "ERROR: Dit ticket bevat files die, op basis van hun locatie, niet tot deze ADC behoren. Deploy kan niet verdergaan."
  echo "Deploy voor ADC=${ArgAppl}. Files in ticket zouden zijn voor ADC=${DerivedADC}."
    exit 16
fi

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
echo "Script" ${ScriptName}  "ended."
exit
