#!/bin/bash

#### jbosspasswordinst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the real installation of
# a jboss password type ticket deployment.
# Given that the predeploy script has pushed the ticket material
# to all target servers, they are simply contacted to take
# these steps:
#   stop the container
#   replace the files with the ticket related ones
#   perform the required decryption of password files
#   set security of the password files
#   start the container
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     DOEL		: The StapDoel that determines up to
#                            what point the deploy process
#                            should go
#################################################################
# Change history
#################################################################
# dexa  # sept/2016   # ArgDoel en bijbehorende processing
# dexa  # 07/10/2016  # call MaakTmpTicketFolder en CleanTmpFolder
# dexa  # 10/06/2017  # Uitvoeren van het dodelete.sh script
# lekri # 02/06/2021  # expliciet openssl hashing algoritme specifieren
# lekri # 12/11/2021  # ondersteuning ACC & SIM TraceIT/4me
#       #             #
#################################################################
#

ScriptName="jbosspasswordinst.sh"
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

ActionType="psw-inst"
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

TargetFolder="${TheFld}/deploy_material/password"

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

# Two scripts are prepared for execution on each target server:
# Script 1 will issue stop commands
# Script 2 will move current binaries to a backup folder and install the new binaries
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
cp ${ScriptPath}"/deploy_slave_target_functions.sh" $TmpCmd2File
cat >>${TmpCmd2File} << EOL
#!/bin/bash

echo "Script MoveBinaries.sh started ..."
cd ${TargetFolder}

for filename in \$(find ${TargetFolder}/from_nfs -name '*.enc') ; do
  strpfn=\${filename#"$TargetFolder/from_nfs/"}
  echo "Processing \${strpfn}"
  if [ -d $TargetFolder/from_nfs/\$strpfn ]; then
    if [ ! -e $TargetFolder/../../\$strpfn ]; then
      mkdir $TargetFolder/../../\$strpfn
    fi
  else
    fl=\$( expr  \${#strpfn} - 4 )
    echo "\${strpfn:\$fl:4}"
    if [ "\${strpfn:\$fl:4}" = ".enc" ]; then
      echo "Decrypting file \$strpfn ..."
      openssl enc -d -in $TargetFolder/from_nfs/\${strpfn} -out $TargetFolder/tempfile -aes256 -md sha256 -pass file:MasterPSW_openssl
      RC=\$?
      if [ \$RC -ne 0 ]; then
        echo "Could not decrypt the password file \${strpfn}."
        exit 16
      fi
      chown :jboss ${TargetFolder}/tempfile
      basefld=\$(dirname $TargetFolder/../../\${strpfn:0:\$fl})
      sudo /bin/su - ${TheUsr} -c "mkdir -p \$basefld"
      ## Keep historical vesions of password files
      keepfname="${TargetFolder}/../../\${strpfn:0:\$fl}"
      sudouser=${TheUsr}
      keep_historical_versions
      ## Put the new version in place
      sudo /bin/su - ${TheUsr} -c "cp ${TargetFolder}/tempfile ${TargetFolder}/../../\${strpfn:0:\$fl}"
      RC=\$?
      if [ \$RC -ne 0 ]; then
        echo "Could not copy the decrypted password file \${strpfn} to its final location."
        exit 16
      fi
      ## Reduce security settings to owner only
      sudo /bin/su - ${TheUsr} -c "chmod 600 ${TargetFolder}/../../\${strpfn:0:\$fl}"
      ## remove the temp file
      rm ${TargetFolder}/tempfile
    fi
  fi
done
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
    $ScpPutCommand $TargetServer ${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw ${TargetFolder}/MasterPSW_openssl
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_ScpPutFailed "MasterPSW_openssl" $TargetServer
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
      echo "SSH call to run StopContainer.sh on target server ${TargetServer} failed (RC=$RC)."
      exit 16
    fi

    # execute the MoveBinaries.sh script
    $SshCommand $TargetServer "source ${TargetFolder}/MoveBinaries.sh"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "SSH call to run MoveBinaries.sh on target server ${TargetServer} failed (RC=$RC)."
      exit 16
    fi

    if [ $DeployIT_Stap_Doel -ge $DEPLOYIT_STAP_RESTART ]; then
      # execute the StartContainer.sh script
      $SshCommand $TargetServer "source ${TargetFolder}/StartContainer.sh"
      RC=$?
      if [ $RC -ne 0 ]; then
        echo "SSH call to run StartContainer.sh on target server ${TargetServer} failed (RC=$RC)."
        exit 16
      fi
    fi
  done
# All listed target servers have now stopped their containers and replaced their binaries.
echo "All scripts have been executed to all target machines"

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
