#!/bin/bash

#### convert_ticket_dryrun.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script is the main script of the dryrun functionality
# of AutoDeploy (or DeployIT). It allows a developer or other
# interested party (OO, ICTDeploy team) to generate the resulting
# files from a ticket using the replace tool.
# This script takes only a ticket number in input and a target
# environment. It generates the according files for all files
# that are in the ticket.
# The output files are NOT sent to SVN. They are kept by this
# script in the Jenkins Workspace, to allow the Jenkins job to
# archive them as artefacts.
#
# Command line options:
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# dexa # 06/12/2016  # gebruik GetDynOplOmg
# dexa # 06/12/2016  # gebruik deploy_errorwarns.sh
# dexa # 15/12/2016  # gebruik RT_AllErrors flag
#      #             #
#      #             #
#      #             #
#################################################################
#

ScriptName="convert_ticket_dryrun.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

quote='"'

DebugLevel=3
ArgTicketNr=$1
omgeving=$2
ArgEnv=$omgeving

LogLineINFO "Script ${ScriptName} started."
LogLineINFO "Options are:"
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
  deploy_error $DPLERR_JenkinsBuildNrMissing
fi

cd $OutputFolder
TmpTicketFolder="${OutputFolder}/tmp"
mkdir $TmpTicketFolder
cd $TmpTicketFolder

## Important: this script always works with the latest and greatest placeholder file!
## check out that placeholder file from SVN
Svn_set_options
svn export ${SvnOpts} https://scm/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/trunk/jenkins/deploy-it/cmdb_publish/Placeholders_DeployIt.csv
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SvnError
fi

## GetDynOplOmg:
## In: ArgTicketNr, TmpFld    Out: TheOpl
GetDynOplOmg

## download the ticket material via the handover tool
if [ -d "svn" ]; then
  rm -rf svn
fi
mkdir svn
cd svn
Handover_Download_Local
cd ..
cp svn/TI*-downloaded.txt handover-downloaded.txt

## Parse the downloaded.txt file to determine the ADC for which we are working
HandoverDownloadedList="${TmpTicketFolder}/handover-downloaded.txt"
HODL_parse
## ADC names in the placeholder file are allways uppercase
DerivedADC=${TheTicketADCfolder^^}

## Load specific DeployIT settings that may be specific to this ADC
TmpFld=$TmpTicketFolder
TheADC=$DerivedADC
# Get specific settings based on the ENV and the ADC
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level

EchoDeployITSettings



## Prepare for a Replace_Tool call
Replace_Tool_Defaults
RT_InFolder=${TmpTicketFolder}/svn/${TheTicketType}/${TheTicketADCfolder}/template
RT_ScanFilter="*"
RT_OutFolder=${TmpTicketFolder}/out
mkdir $RT_OutFolder
RT_OutFolderEnc=""
RT_Env=$ArgEnv
RT_ADC=$DerivedADC
RT_Tmp=$OutputFolder
RT_Cmdb_csv=${TmpTicketFolder}/Placeholders_DeployIt.csv
RT_LogUsage=${RT_OutFolder}/replace_logging.txt
RT_TicketNr=$ArgTicketNr
RT_AllErrors=1
RT_EchoFileNames=1

Replace_Tool

LogLineINFO "copieren van output files naar workspace."

cd $WORKSPACE
cp -a $RT_OutFolder/* $WORKSPACE/

if [ $RT_ReturnCode -ne 0 ]; then
  echo "Er werden problemen gevonden tijdens de replace fase (Return code = ${RT_ReturnCode}). Zie hoger voor meer details."
  exit 16
fi

echo "Einde van het script."
