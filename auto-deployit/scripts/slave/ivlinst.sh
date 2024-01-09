#!/bin/bash

#### ivlinst.sh script
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
# dexa  # Dec/2019      # 1.0.0   # initial version
# dexa  # Aug/2020      # 1.0.1   # remove source ivl_functions
# dexa  # Oct/2020      # 1.1.0   # TraceIT status upd for all environments
# dexa  # Dec/2020      # 1.1.1   # TraceIT UITGEVOERD in commentaar gezet
# dexa  # Dec/2020      # 1.1.2   # TraceIT IN_UITVOERING gebruiken
#############################################################################
#

ScriptName="ivlinst.sh"
ScriptVersion="1.1.2"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"
source "${ScriptPath}/deploy_slverrorwarns.sh"

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

ActionType="ivl-inst"
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

## Get info on ivl-server
GetIvlInfo
## output:
##     $OdiTgtServer           : the server to connect to
##     $OdiTgtLoggingFolder    : the logging folder on the target machine

LogLineDEBUG "OdiTgtServer=$OdiTgtServer"
LogLineDEBUG "OdiTgtLoggingFolder=$OdiTgtLoggingFolder"

## Doe een PING naar de ODI server
ping -c 2 "${OdiTgtServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  echo "Server ping failed for server ${OdiTgtServer}"
  exit 16
fi

LogLineDEBUG "Het TraceIT ticket wordt IN UITVOERING gezet ..."
ArgStatus="${ArgEnv}_IN_UITVOERING"
ArgErrMsg="${ArgEnv}_In_Uitvoering NIET gelukt!"
TraceIT_UpdStatus

TargetFolder="/data/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}"

# execute the installIvl.sh script

$SshCommand $OdiTgtServer "/bin/bash --login ${TargetFolder}/installIvl.sh"
RC=$?
if [ $RC -ne 0 ]; then
  ## Before we raise the errror to the user, we must set TraceIT if needed

  LogLineDEBUG "Het TraceIT ticket wordt UITGEVOERD MET FOUTEN gezet ..."
  ArgStatus="${ArgEnv}_UITGEVOERD_MET_FOUTEN"
  ArgErrMsg="${ArgEnv}_Uitgevoerd_met_fouten NIET gelukt!"
  TraceIT_UpdStatus

  ## Call the related error function for Slave problems
  ## The below call does NOT come back here!
  DPLERR_BASE=$DPLERRSLV_IVL_Base
  deploy_slvRC $RC
fi

## UITGEVOERD zetten wordt uitgesteld tot de postdeploy stap
#LogLineDEBUG "Het TraceIT ticket wordt UITGEVOERD gezet ..."
#ArgStatus="${ArgEnv}_UITGEVOERD"
#ArgErrMsg="${ArgEnv}_Uitgevoerd NIET gelukt!"
#TraceIT_UpdStatus

$SshCommand $OdiTgtServer "/bin/bash ${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/cleanTemp.sh" $OdiTgtServer $RC
fi

echo "All scripts have been executed to all target machines"

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

LogLineINFO "Script" ${ScriptName}  "ended."
