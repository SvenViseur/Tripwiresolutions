#!/bin/bash

#### javabatchinst.sh script
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
# jaden # Mar/2018    # 1.0-0 # initial POC versie
# jaden # Jun/2018    # 1.0-1 # Fixed several bugs
# dexa  # feb/2019    # 1.1.0 # Added better logging
#############################################################################
#

ScriptName="javabatchinst.sh"
ScriptVersion="1.1.0"
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
#ScpPutCommand="${SshScriptsFolder}/scp_srv_taccdeps_put.sh"
#ScpGetCommand="${SshScriptsFolder}/scp_srv_toptoa_get.sh"
SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="javabatch-inst"
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

## get info on bof
GetBofInfo
## output: ${BofDeployFolder}, ${TheFld}


## Determine the target elements for this predeploy:
## - the BOF server: $TheBOFServer
## - the root path where to deploy: $TheBOFTargetPath
TheBOFServer="bof_${TheBof}.argenta.be"
TheBOFTargetPath="/${ArgEnv}/${TheFld}"
TargetFolder="/home/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}"

## Doe een PING naar de BOF server
ping -c 2 "${TheBOFServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  LogLineERROR "Server ping failed for server ${TheBOFServer}"
  exit 16
fi

$SshCommand $TheBOFServer "${TargetFolder}/installBinaries.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/installBinaries.sh" $TheBOFServer $RC
fi

$SshCommand $TheBOFServer "${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/cleanTemp.sh" $TheBOFServer $RC
fi


echo "All scripts have been executed to all target machines"

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
