#!/bin/bash

#### jbosspasswordpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the preparation activities to allow
# a jboss password type ticket deployment.
# It pushes the required files to the deployIT mount point,
# then contacts all target servers to download those files
# into the container but without activation.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# dexa # dec/2015    # initial POC versie
# dexa # apr/2016    # move naar deploy-it ACC omgeving
#      #             # centraliseer functies in externe file
# dexa # jun/2016    # added DeployITSpecificSettings call
# dexa # jul/2016    # gebruik DeployIT_Can_Update_Tickets en
#      #             # DeployIT_Can_Ssh_To_Appl_Servers
# dexa # 07/10/2016  # call MaakTmpTicketFolder en CleanTmpFolder
# dexa # 24/01/2017  # insert call naar GetDynOplOmg
# dexa # 29/05/2017  # upload deployit-scripts voor delete
#      #             #   ONDERSTEUN-1302
# lekri # 12/11/2021 # ondersteuning ACC & SIM TraceIT/4me
#      #             #
#      #             #
#################################################################
#

ScriptName="jbosspasswordpredeploy.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

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

ActionType="psw-predeploy"
MaakTmpTicketFolder
cd ${TmpTicketFolder}

TmpFld=$TmpTicketFolder
TheEnv=$ArgEnv
TheADC=$ArgAppl

## Get default settings based on the ENV and ADC
GetDeployITSettings

## ExtraOpts is hier nodig, omdat GetDynOplOmg via TraceIT gebeurt
Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

## GetDynOplOmg:
## In: ArgTicketNr, TmpFld    Out: TheOpl
GetDynOplOmg

DebugLevel=$DeployIT_Debug_Level
Replace_Tool_Defaults
EchoDeployITSettings
LoggingBaseFolder="${ConfigNfsFolderRepllogOnServer}/target_${ArgEnv}/"
mkdir -p $LoggingBaseFolder

StapDoelBepalen $ArgDoel

## Opnieuw ExtraOpts parsen, want die kunnen StapDoel wijzigen!
Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_PREDEPLOY ]; then
  echo "WARN: Predeploy fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

if [ ${DeployIT_Can_Ssh_To_Appl_Servers} -ne 1 ]; then
  echo "WARN: Deploy to target servers is skipped due to Deploy-IT settings"
  exit 0
fi

## Get info on container
GetCntInfo
## Output: $TheCnt, $TheUsr, $TheFld

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

cd ${TmpTicketFolder}

## Call Handover tool to download ticket material
Handover_Download_Local

# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

OnlyDeletes=0 ## Default value

# Check the contents of the deleted and downloaded files
# Test 1: ensure deleted.txt AND downloaded.txt are NOT BOTH empty
if [ ! -s ${HandoverDownloadedList} ]; then
  if [ ! -s ${HandoverDeletedList} ]; then
    echo "ERROR: Ticket bevat geen data files (geen nieuwe, gewijzigde of verwijderde files). DeployIT kan dus niets doen."
  fi
  ## Als we dit punt bereiken, dan is er GEEN downloaded file maar wel deleted files.
  ## Dus heeft het geen zin om de downloaded file te parsen.
  OnlyDeletes=1
fi

# Test 3: ensure downloaded.txt only contains lines with "password"
if [ $(grep -v password ${HandoverDownloadedList} | wc -l) -ne 0 ];
then
  echo "ERROR: Ticket contains download files outside the password folder. This is not supported here."
  exit 16
fi

## Extract the *secondpart* variable from the first line of the downloaded file
# Under password there should be only 1 subfolder, which is typical for this ADC. Extract it.
line1=$(cat ${HandoverDownloadedList} ${HandoverDeletedList} | head -n 1)
echo "line1 = " ${line1}
## expected format: OK      password/<adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
# echo "line1 (stripped) = " ${line1}
firstpart=${line1%%"/"*}
restpart=${line1:${#firstpart}+1}
secondpart=${restpart%%"/"*}
# echo "first folder part is:" ${firstpart}
# echo "second folder part is:" ${secondpart}
if [[ ${firstpart} -eq "password" ]] && [[ ${secondpart} -eq ${ArgAppl,,} ]]; then
  echo "Line 1 is in the expected format!"
else
  echo "ERROR: downloaded.txt has a first line that is outside the expected location!"
  echo ">>${firstpart}<< should be >>password<<"
  echo ">>${secondpart}<< should be >>${ArgAppl,,}<<"
  exit 16
fi

## Currently, we only support to deploy the password files that were generated by our own tools
ToInstallSubfolder="${TmpTicketFolder}/password/${secondpart}/generated/${ArgEnv}"

## Copieer de bestanden die moeten geinstalleerd worden naar de NFS mount.
NfsFolder="${ConfigNfsFolderOnServer}/T${ArgTicketNr}"
rm -rf $NfsFolder
if [ -d ${NfsFolder} ]; then
  echo "ERROR: Could not remove old contents in ${NfsFolder}."
  exit 16
fi
mkdir $NfsFolder
if [ ! -d ${NfsFolder} ]; then
  echo "ERROR: Could not create directory ${NfsFolder}."
  exit 16
fi
if [ $OnlyDeletes -eq 0 ]; then
  echo "Copying files and folders from ${ToInstallSubfolder} to ${NfsFolder}."
  cp -a ${ToInstallSubfolder}/* ${NfsFolder}
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "Could not copy material to the NFS share. Please check the mounts on this server."
    exit 16
  fi
fi
if [ -s ${HandoverDeletedList} ];
then
  ## Er zijn delete requests die we moeten afhandelen op de target servers.
  cd ${TmpTicketFolder}
  Handover_MakeDeleteBashScript
  mkdir -p "${NfsFolder}/deployIT-scripts"
  cp "TI${ArgTicketNr}-dodelete.sh" "${NfsFolder}/deployIT-scripts/dodelete.sh"
fi

chown -R ${UnixUserSlave}:${UnixGroupPckSlv} ${NfsFolder}/*

TargetFolder="${TheFld}/deploy_material/password"
# prepare script to send to target server(s)
TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm $TmpCmdFile
cat >${TmpCmdFile} << EOL
#!/bin/bash
mkdir -p ${TargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific folder."
  exit 16
fi
cd ${TargetFolder}
rm -rf from_nfs
mkdir from_nfs
cp -a ${ConfigNfsFolderOnClient}/T${ArgTicketNr}/* from_nfs
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not copy the ticket specific files into a temporary deploy folder."
  exit 16
fi
EOL
chmod +x ${TmpCmdFile}


echo "Starting communication with target servers ..."

for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    TargetServer="${SrvList[$i]}${DnsSuffix}"
    echo "Starting preparation work on server ${TargetServer}"

    $ScpPutCommand $TargetServer $TmpCmdFile "/tmp/T${ArgTicketNr}_preparetargetfolder.sh"
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $TargetServer
    fi

    # execute the preparetargetfolder.sh script
    $SshCommand $TargetServer "source /tmp/T${ArgTicketNr}_preparetargetfolder.sh"
    RC=$?
    if [ $RC -ne 0 ]; then
      deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $TargetServer $RC
    fi
  done
# All listed target servers have now been provisioned with the svn material.

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
