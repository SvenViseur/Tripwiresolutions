#!/bin/bash

#### convert_ticket_withsvnupdate.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script is largely similar to the script
# convert_ticket_dryrun.sh but on top op generating files
# for an environment, these generated files are added to
# the ticket as well.
#
# Command line options:
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
#      #             #
#      #             #
#      #             #
#################################################################
#

ScriptName="convert_ticket_withsvnupdate.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

quote='"'

DebugLevel=3
ArgTicketNr=$1
omgeving=$2
ArgEnv=$omgeving

LogLineINFO "Script" ${ScriptName}  "started."
LogLineINFO "Options are:"
LogLineINFO "  APPL = '${ArgAppl}'"
LogLineINFO "  TICKETNR = '${ArgTicketNr}'"
LogLineINFO "  ENV = '${ArgEnv}'"

GetEnvData

OutputFolder="$WORKSPACE"
cd $OutputFolder

TmpFld=$OutputFolder
TheEnv=$ArgEnv
TheADC="NO-ADC"
## Get some default settings based in the ENV
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level

Replace_Tool_Defaults

LogLineINFO "Userid    : $USER"
LogLineINFO "omgeving  : $omgeving"
LogLineINFO "Jenkins id:" $BUILD_NUMBER
LogLineINFO "Ticket nr :" $ArgTicketNr

if [ -z "$BUILD_NUMBER" ]
then
  echo "Jenkins build number ontbreekt!!"
  exit 16
fi

cd $OutputFolder
if [ -d "svn" ]; then
  rm -rf svn
fi
mkdir svn
cd svn
Handover_Download_Local
cd ..
cp svn/TI*-downloaded.txt handover-downloaded.txt

TmpTicketFolder=$OutputFolder
HandoverDownloadedList="${TmpTicketFolder}/handover-downloaded.txt"
HODL_parse

DerivedADC=${TheTicketADCfolder^^}

TheADC=$DerivedADC
## Get specific settings based on the ENV and the ADC
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level

EchoDeployITSettings

Replace_Tool_Defaults

## Prepare for a Replace_Tool call
RT_InFolder=${OutputFolder}/svn/${TheTicketType}/${TheTicketADCfolder}/template
RT_ScanFilter="*"
RT_OutFolder=${OutputFolder}/out
mkdir $RT_OutFolder
RT_OutFolderEnc=""
RT_Env=$ArgEnv
RT_ADC=$DerivedADC
RT_Tmp=$OutputFolder

Replace_Tool

## Voorbereiding Upload naar het ticket

OplFolder="${TheTicketType}/${TheTicketADCfolder}"
## Svn_co:
## Input:
## TmpTicketFolder
## TheOpl             (de Opleverings-root-folder, bekomen via GetEnvData()  )
## OplFolder          (de opleverings-subfolder, meestal config/$EnvAppl of password/$EnvAppl  )
Svn_co
## Output:
## svn folder structure under $TmpTicketFolder/svnupd

if [ ${DeployIT_Can_Update_Tickets} -eq 1 ]; then

  ## replace de gegenereerde files

  cd ${TmpTicketFolder}/svnupd/${TheTicketADCfolder}
  mkdir -p generated
  mkdir -p generated/${ArgEnv}
  cp --no-preserve=timestamps -a $RT_OutFolder/* generated/${ArgEnv}/.

  ## Call Svn_add en Svn_commit
  Svn_add

  Svn_commit

  ## call Ripple up
  Handover_RippleUp
else
  LogLineINFO "Geen SVN of ticket updates uitgevoerd wegens Deploy-IT configuratiesettings."
fi

cd ${TmpTicketFolder}
## rm -rf out
rm handover-downloaded.txt

echo "Einde van het script."

