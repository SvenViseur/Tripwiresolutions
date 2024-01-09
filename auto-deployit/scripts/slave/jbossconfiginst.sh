#!/bin/bash

#### jbossconfiginst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the real installation of
# a jboss config type ticket deployment.
# Given that the predeploy script has pushed the ticket material
# to all target servers, they are simply contacted to take
# these steps:
#   stop the container
#   replace the files with the ticket related ones
#   start the container
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
# dexa # sept/2016   # ArgDoel en bijbehorende processing
# dexa # 07/10/2016  # call MaakTmpTicketFolder en CleanTmpFolder
# dexa # 09/12/2016  # ONDERSTEUN-1024 - set chmod on files
# dexa # 29/05/2017  # ONDERSTEUN-1302 - deployIT-scripts apart
#      #             #     en dodelete.sh uitvoeren
# lekri # 12/11/2021 # ondersteuning ACC & SIM TraceIT/4me
#      #             #
#################################################################
#

ScriptName="jbossconfiginst.sh"
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

ActionType="config-inst"
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

## Get info on container
GetCntInfo
## Output: $TheCnt, $TheUsr, $TheFld

TargetFolder="${TheFld}/deploy_material/config"

## GetSrvList:
##     input variables  : $ArgAppl, $ArgEnv
##     input files      : ADCENV2SRV.csv
GetSrvList
##     output variables : $SrvCount, $SrvList[1..$SrvCount]

if [ "$SrvCount" = "0" ]; then
  deploy_error $DPLERR_ServerCount0
fi

## Toon de lijst van servers in SrvList[]
EchoSrvList

## Doe een PING naar alle servers in SrvList[]
PingSrvList

# Three scripts are prepared for execution on each target server:
# Script 1 will issue stop commands
# Script 2 will move current binaries to a backup folder and install the new binaries
# Script 3 will issue start commands
TmpCmd1File="${TmpTicketFolder}/ShutdownContainer.sh"
rm -f $TmpCmd1File
cat >${TmpCmd1File} << EOL
#!/bin/bash
if [ -s "/etc/rc.d/init.d/jboss-${TheUsr}.sh" ]; then
  sudo /etc/rc.d/init.d/jboss-${TheUsr}.sh stop
  RC=\$?
  if [ \$RC -ne 0 ]; then
    echo "Could not stop the target container ${TheCnt} using the jboss-${TheUsr}.sh stop command."
    exit 16
  fi
else
  if [ -s "/usr/local/scripts/restart_container.sh" ]; then
    sudo  /usr/local/scripts/restart_container.sh -c ${TheUsr} -S
    RC=\$?
    if [ \$RC -ne 0 ]; then
      echo "Could not stop the target container ${TheCnt} using the restart_container.sh -c ${TheUsr}.sh -S command."
      exit 16
    fi
  else
    echo "No supported start/stop script found."
    exit 16
  fi
fi
EOL
chmod +x ${TmpCmd1File}

TmpCmd2File="${TmpTicketFolder}/MoveBinaries.sh"
rm -f $TmpCmd2File
## the cp command is executed by the functional account to ensure the right access rights
cat >${TmpCmd2File} << EOL
#!/bin/bash
## set all file permissions to 0640
cd "${TargetFolder}/from_nfs"
find . -type f -exec chmod 640 {} +
## with container user, copy all files with preserve mode
## sudo /bin/su - ${TheUsr} -c "cp --preserve=mode -r ${TargetFolder}/from_nfs/* ${TargetFolder}/.."
sudo /bin/su - ${TheUsr} -c "rsync -av --exclude deployIT-scripts ${TargetFolder}/from_nfs/* ${TargetFolder}/../.."
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not copy the config files for container ${TheCnt}."
  exit 16
fi
cd "${TargetFolder}/from_nfs"
if [ -e "deployIT-scripts/dodelete.sh" ]; then
  chown -R :jboss "${TargetFolder}/from_nfs/deployIT-scripts"
  echo "Executing delete command set..."
  sudo /bin/su - ${TheUsr} -c "source ${TargetFolder}/from_nfs/deployIT-scripts/dodelete.sh"
fi
EOL
chmod +x ${TmpCmd2File}

TmpCmd3File="${TmpTicketFolder}/StartContainer.sh"
rm -f $TmpCmd3File
cat >${TmpCmd3File} << EOL
#!/bin/bash
if [ -s "/etc/rc.d/init.d/jboss-${TheUsr}.sh" ]; then
  sudo /etc/rc.d/init.d/jboss-${TheUsr}.sh manualstart
  RC=\$?
  if [ \$RC -ne 0 ]; then
    echo "Could not start the target container ${TheCnt} using the jboss-${TheUsr}.sh manualstart command."
    exit 16
  fi
  sudo /etc/rc.d/init.d/jboss-${TheUsr}.sh status
else
  if [ -s "/usr/local/scripts/restart_container.sh" ]; then
    sudo  /usr/local/scripts/restart_container.sh -c ${TheUsr} -B
    RC=\$?
    if [ \$RC -ne 0 ]; then
      echo "Could not start the target container ${TheCnt} using the restart_container.sh -c ${TheUsr}.sh -B command."
      exit 16
    fi
  else
    echo "No supported start/stop script found."
    exit 16
  fi
fi
EOL
chmod +x ${TmpCmd3File}

echo "Starting communication with target servers ..."

for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    echo "Starting preparation work on server ${TargetServer}"

    # put the command files on the target
    $ScpPutCommand $TargetServer ${TmpCmd1File} ${TargetFolder}/StopContainer.sh
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_ScpPutFailed "StopContainer.sh" $TargetServer
    fi
    $ScpPutCommand $TargetServer ${TmpCmd2File} ${TargetFolder}/MoveBinaries.sh
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_ScpPutFailed "MoveBinaries.sh" $TargetServer
    fi
    $ScpPutCommand $TargetServer ${TmpCmd3File} ${TargetFolder}/StartContainer.sh
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_ScpPutFailed "StartContainer.sh" $TargetServer
    fi
  done
echo "All scripts have been uploaded to all target machines"

for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    echo "Starting activation work on server ${TargetServer}"

    # execute the StopContainer.sh script
    $SshCommand $TargetServer "source ${TargetFolder}/StopContainer.sh"
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_StopContainerFailed $TargetServer $TheUsr $RC
    fi

    # execute the MoveBinaries.sh script
    $SshCommand $TargetServer "source ${TargetFolder}/MoveBinaries.sh"
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_SshExecFailed "MoveBinaries.sh" $TargetServer $RC
    fi

    if [ $DeployIT_Stap_Doel -ge $DEPLOYIT_STAP_RESTART ]; then
      # execute the StartContainer.sh script
      $SshCommand $TargetServer "source ${TargetFolder}/StartContainer.sh"
      RC=$?
      if [ $RC -ne 0 ]; then
        deploy_error $DPLERR_StartContainerFailed $TargetServer $TheUsr $RC
      fi
    fi

  done
# All listed target servers have now stopped their containers and replaced their binaries.
echo "All scripts have been executed to all target machines"

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
