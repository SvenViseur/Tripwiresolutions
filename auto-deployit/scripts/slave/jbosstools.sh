#!/bin/bash

#### jbosstools.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     ENV		: The target environment
#     COMMAND           : The command to perform against the containers
#
# Valid COMMAND values can be found in the deploy_global_remote_commands.sh script
#                 An empty command lists the container status (started or stopped)

ScriptName="jbosstools.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_global_remote_commands.sh"

DebugLevel=3
ArgAppl=$1
ArgEnv=$2
ArgAction=$3

echo "Script ${ScriptName} started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  ENV = '${ArgEnv}'"
echo "  ACTION = '${ArgAction}'"

## Call GetEnvData
GetEnvData

SshCommand="${SshScriptsFolder}/ssh_srv_taccdeps_key.sh"
ScpPutCommand="${SshScriptsFolder}/scp_srv_taccdeps_put.sh"
if [ "${ArgEnv}" = "SIM" ]; then    ## cat console.log
  SshCommand="${SshScriptsFolder}/ssh_srv_toptoa.sh"
  ScpPutCommand="${SshScriptsFolder}/scp_srv_toptoa_put.sh"
fi

## Get info on container
GetCntInfo
## Output: $TheCnt, $TheUsr, $TheFld

BuildJBossActionLine

## GetSrvList:
##     input variables  : $ArgAppl, $ArgEnv
##     input files      : ADCENV2SRV.csv
GetSrvList
##     output variables : $SrvCount, $SrvList[1..$SrvCount]

if [ "$SrvCount" = "0" ]; then
  echo "ERROR: no target servers found to deploy to. Check arguments against file $Filename"
  exit 16
fi

## Toon de lijst van servers in SrvList[]
EchoSrvList

## Doe een PING naar alle servers in SrvList[]
PingSrvList

TargetFolder="/tmp"
TargetScriptName="/tmp/jbosstools-script.sh"
TmpTicketFolder="/tmp/deploy-it/jbosstools/${ArgEnv}"
LocalScriptName="${TmpTicketFolder}/jbosstools-script.sh"
mkdir -p $TmpTicketFolder

# Two scripts are prepared for execution on each target server:
# Script 1 will issue stop commands
# Script 2 will move current binaries to a backup folder and install the new binaries
if [ -e ${LocalScriptName} ]; then
  rm $LocalScriptName
fi
cat >${LocalScriptName} << EOL
#!/bin/bash
sudo /etc/rc.d/init.d/jboss-${TheUsr}.sh status
RC=$?
$ActionLine
EOL
chmod +x ${LocalScriptName}

LogLineDEBUG "Starting communication with target servers ..."

for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    LogLineDEBUG "Starting preparation work on server ${TargetServer}"

    # put the command files on the target
    $ScpPutCommand ${TargetServer} ${LocalScriptName} ${TargetScriptName}
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "Could not put ${TargetScriptName} script on target server ${TargetServer}."
      exit 16
    fi
  done
LogLineDEBUG "All scripts have been uploaded to all target machines"
## We can now delete the local script
rm $LocalScriptName


for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    # execute the script
    $SshCommand $TargetServer "source ${TargetScriptName}"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "SSH call to run ${TargetScriptName} on target server ${TargetServer} failed (RC=$RC)."
      exit 16
    fi
  done
LogLineDEBUG "All scripts have been executed to all target machines"

for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    # remove the script
    $SshCommand $TargetServer "rm ${TargetScriptName}"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "SSH call to delete ${TargetScriptName} on target server ${TargetServer} failed (RC=$RC)."
      exit 16
    fi
  done
LogLineDEBUG "All scripts have been executed to all target machines"

LogLineINFO "Script ${ScriptName} ended."
