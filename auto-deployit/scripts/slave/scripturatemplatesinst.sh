#!/bin/bash

#### scripturatemplatesinst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     DOEL		: To which point the deploy shoud go
#
#################################################################
# Change history
#################################################################
# lekri # 12/11/2021 # ondersteuning ACC & SIM TraceIT/4me
#      #             #
#      #             #
#      #             #
#################################################################
#

ScriptName="scripturatemplatesinst.sh"
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

echo "Script" ${ScriptName}  "started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"
echo "  DOEL = '${ArgDoel}'"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData

ActionType="scripturatemplates-inst"
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

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_ACTIVATE ]; then
  echo "WARN: Activatie fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

## Compare the requested ADC with the one derived from the HODL file
if [ "$ArgAppl" = "Scriptura_templates" ]; then
  LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
else
  echo "ERROR: Dit script werd opgeroepen voor een ADC type dat niet past bij dit script."
  echo "Deploy voor ADC=${ArgAppl}. Script is enkel voorzien voor ADC=\"Scriptura_templates\"."
  exit 16
fi

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
# Test 1: ensure deleted.txt is empty
if [ -s ${HandoverDeletedList} ]; then
  echo "ERROR: Ticket contains file deletions. This is currently NOT supported."
  exit 16
fi
# Test 2: ensure downloaded.txt is NOT empty
if [ ! -s ${HandoverDownloadedList} ]; then
  echo "ERROR: Ticket contains no downloadable files, so there is nothing to deploy."
  exit 16
fi
# Test 3: ensure downloaded.txt only contains lines with "scriptura_templates/scripturaproject/"
if [ $(grep -v "scriptura_templates/scripturaproject/" ${HandoverDownloadedList} | wc -l) -ne 0 ]; then
  echo "ERROR: Ticket contains download files outside the 'scriptura_templates/scripturaproject/' folder. This is not supported for this type of applications."
  exit 16
fi

ToInstallSubfolder="${TmpTicketFolder}/scriptura_templates/scripturaproject/*"
TargetFolderBase=${DEPLOYIT_SCRIPTURA_TARGET_BASE}
TargetFolderNodes=${DEPLOYIT_SCRIPTURA_TARGET_NODES}

echo "Deploying to base $TargetFolderBase"
echo "         and nodes $TargetFolderNodes"
echo "List of files that will be copied:"
ls -lR $ToInstallSubfolder
echo "End of list of files that will be copied."


oIFS=$IFS
IFS=","
read -r -a nodelist <<< "$TargetFolderNodes"
echo "Size of nodelist: ${#nodelist[@]}"
for node in "${nodelist[@]}"
do
  ## copy the complete $ToInstallSubfolder to the TargetFolder
  TargetFolder="${TargetFolderBase}${node}/"
  echo "copying to ${TargetFolder}"
  cp -r ${ToInstallSubfolder} ${TargetFolder}
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_ScripturaCopyFailed $ToInstallSubfolder $TargetFolder
  fi
done

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi

echo "Script" ${ScriptName}  "ended."
