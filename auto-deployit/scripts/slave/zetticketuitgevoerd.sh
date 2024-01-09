#!/bin/bash

#### zetticketuitgevoerd.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The environment the normal deploy goes to
#     DOEL		: The level of deploy. If not Install or higher,
#                         all processing will be skipped
#
#################################################################
# Change history
#################################################################
# dexa  # Jan/2021    # 1.0.0 # initial version
#       #             #       #
#################################################################
ScriptName="zetticketuitgevoerd.sh"
ScriptVersion="1.0.0"
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
LogLineINFO "  TARGETSRV = '${ArgTargetSrv}'"
LogLineINFO "  DOEL = '${ArgDoel}'"
LogLineINFO "  EXTRA OPTIONS = '${ArgExtraOpts}'"

ActionType="zet-ticket-uitgevoerd"
MaakTmpTicketFolder
cd ${TmpTicketFolder}

TmpFld=$TmpTicketFolder
TheEnv=$ArgEnv
TheADC=$ArgAppl
## Get default settings based on the ENV and ADC
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level
EchoDeployITSettings

Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

StapDoelBepalen $ArgDoel

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_ACTIVATE ]; then
  echo "WARN: Ticket in uitgevoerd zetten wordt niet gedaan wegens huidig doel"
  exit 0
fi

LogLineDEBUG "Het TraceIT ticket wordt UITGEVOERD gezet ..."
ArgStatus="${ArgEnv}_UITGEVOERD"
ArgErrMsg="${ArgEnv}_Uitgevoerd NIET gelukt!"
TraceIT_UpdStatus

