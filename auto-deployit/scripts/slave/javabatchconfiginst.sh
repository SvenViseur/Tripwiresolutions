#!/bin/bash

#### javbatchconfiginst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
#
# Depending on the DOEL parameter, some or all of the above
# steps may be skipped.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     DOEL		: The StapDoel that determines up to
#                            what point the deploy process
#                            should go
#
#
#################################################################
# Change history
#################################################################
# jaden # Mar/2018    # initial POC versie
# dexa  # feb/2019    # 1.1.0 # Added better logging
# dexa  # apr/2019    # 1.2.0 # Remove steps as reminst does it all
#################################################################
#

ScriptName="javbatchconfiginst.sh"
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

echo "Script" ${ScriptName}  "started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"
echo "  DOEL = '${ArgDoel}'"

## Call GetEnvData
GetEnvData

#SshCommand="${SshScriptsFolder}/ssh_srv_taccdeps_key.sh"
#ScpPutCommand="${SshScriptsFolder}/scp_srv_taccdeps_put.sh"
#ScpGetCommand="${SshScriptsFolder}/scp_srv_toptoa_get.sh"
SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv


ActionType="javabatch-config-inst"
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

if [ ${DeployIT_Can_Ssh_To_Appl_Servers} -ne 1 ]; then
  echo "WARN: Deploy to target servers is skipped due to Deploy-IT settings"
  exit 0
fi

## get info on bof
GetBofInfo
## output: ${TheUsr}, ${TheFld}

## Determine the target elements for this predeploy:
## - the BOF server: $TheBOFServer
## - the root path where to deploy: $TheBOFTargetPath
TheBOFServer="bof_${TheBof}.argenta.be"
TheBOFTargetPath="/${ArgEnv}"
TargetFolder="/home/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}"

LogLineDEBUG "TheBOFServer=$TheBOFServer"
LogLineDEBUG "BofDeployFolder=$BofDeployFolder"
LogLineDEBUG "TheFld=$TheFld"
LogLineDEBUG "TheBOFTargetPath=$TheBOFTargetPath"
LogLineDEBUG "TargetFolder=$TargetFolder"

## Doe een PING naar de BOF server
ping -c 2 "${TheBOFServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  LogLineERROR "Server ping failed for server ${TheBOFServer}"
  exit 16
fi

$SshCommand $TheBOFServer "${TargetFolder}/InstallConfig.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/InstallConfig.sh" $TheBOFServer $RC
fi
$SshCommand $TheBOFServer "${TargetFolder}/CleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/CleanTemp.sh" $TheBOFServer $RC
fi

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
