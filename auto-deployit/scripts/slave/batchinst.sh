#!/bin/bash

#### batchinst.sh script
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
# dexa  # May/2020      # 1.0.0   # clone van bofinst.sh
#############################################################################
#

ScriptName="batchinst.sh"
ScriptVersion="1.0.0"
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

SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="batch-inst"
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
  echo "WARN: Activatiefase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

if [ ${DeployIT_Can_Ssh_To_Appl_Servers} -ne 1 ]; then
  echo "WARN: Deploy to target servers is skipped due to Deploy-IT settings"
  exit 0
fi
GetEnvData

GetBatchInfo

## Get info on target server
## GetCntInfo
## Output: $TheCnt, $TheUsr, $TheFld

## GetSrvList:
##     input variables  : $ArgAppl, $ArgEnv
##     input files      : ADCENV2SRV.csv
GetSrvList
##     output variables : $SrvCount, $SrvList[1..$SrvCount]

if [ "$SrvCount" = "0" ]; then
  deploy_error $DPLERR_ServerCount0
fi

## For this type of ADC, we currently only support 1 target server per ADC
if [ "$SrvCount" -gt 1 ]; then
  deploy_error $DPLERR_ServerCountGt1
fi


## Determine the target elements for this predeploy:
TheBatchServer="${SrvList[1]}"

TargetFolder="/HTD/autodeploy/tmp/TI${ArgTicketNr}"

## Doe een PING naar de BOF server
ping -c 2 "${TheBatchServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  LogLineERROR "Server ping failed for server ${TheBatchServer}"
  exit 16
fi

# execute the preptargetfolder.sh script

$SshCommand $TheBatchServer "/bin/bash ${TargetFolder}/installBinaries.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/installBinaries.sh" $TheBatchServer $RC
fi

$SshCommand $TheBatchServer "/bin/bash ${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/cleanTemp.sh" $TheBatchServer $RC
fi


echo "All scripts have been executed to all target machines"

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

LogLineINFO "Script" ${ScriptName}  "ended."
