#!/bin/bash

#### javabatchconfigpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the preparation activities to allow
# a javabatch config type ticket deployment.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     DOEL		: The StapDoel that determines up to
#                            what point the deploy process
#                            should go
#
#################################################################
# Change history
#################################################################
# jaden # Mar/2018    # 1.0.0 # initial POC versie
# jaden # Jun/2018    # 1.0.1 # Fixed several bugs
# dexa  # feb/2019    # 1.1.0 # Added better logging
# dexa  # feb/2019    # 1.1.0 # remove "cims" hard-coding
# dexa  # apr/2019    # 1.2.0 # move processing to bofreminst script
# lekri # 12/11/2021  # 1.2.1 # ondersteuning ACC & SIM TraceIT/4me
#################################################################
#
ScriptName="javabatchconfigpredeploy.sh"
ScriptVersion="1.2.1"
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

SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="javabatch-config-predeploy"
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
GetBofInfo
## Output:, $TheUsr, $TheFld

## Determine the target elements for this predeploy:
## - the BOF server: $TheBOFServer
## - the root path where to deploy: $TheBOFTargetPath
TheBOFServer="bof_${TheBof}.argenta.be"
TheBOFTargetPath="/${ArgEnv}/${TheFld}"

LogLineDEBUG "TheBOFServer=$TheBOFServer"
LogLineDEBUG "BofDeployFolder=$BofDeployFolder"
LogLineDEBUG "TheFld=$TheFld"
LogLineDEBUG "TheBOFTargetPath=$TheBOFTargetPath"

## Doe een PING naar de BOF server
ping -c 2 "${TheBOFServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  LogLineERROR "Server ping failed for server ${TheBOFServer}"
  exit 16
fi

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

# Test 3: ensure downloaded.txt only contains lines with "config"
if [ $(grep -v config ${HandoverDownloadedList} | wc -l) -ne 0 ];
then
  echo "ERROR: Ticket contains download files outside the config folder. This is not supported here."
  exit 16
fi

## Extract the *secondpart* variable from the first line of the downloaded or deleted file
# Under config there should be only 1 subfolder, which is typical for this ADC. Extract it.
line1=$(cat ${HandoverDownloadedList} ${HandoverDeletedList} | head -n 1)
echo "line1 = " ${line1}
## expected format: OK      config/<adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
## echo "line1 (stripped) = " ${line1}
firstpart=${line1%%"/"*}
restpart=${line1:${#firstpart}+1}
secondpart=${restpart%%"/"*}
## echo "first folder part is:" ${firstpart}
## echo "second folder part is:" ${secondpart}
if [[ ${firstpart} -eq "config" ]] && [[ ${secondpart} -eq ${ArgAppl,,} ]]; then
  echo "Line 1 is in the expected format!"
else
  echo "ERROR: downloaded.txt or deleted.txt has a first line that is outside the expected location!"
  echo ">>${firstpart}<< should be >>config<<"
  echo ">>${secondpart}<< should be >>${ArgAppl,,}<<"
  exit 16
fi

ToInstallSubfolder="${TmpTicketFolder}/config/${secondpart}/generated/${ArgEnv}"
# Tar the config files.
TmpSrcFld="${TmpTicketFolder}/ReplacedPub"
TmpRetarFld=${TmpTicketFolder}/retar
mkdir -p ${TmpRetarFld}
# TarFile <SrcDir> <DstDir> <DstFile>
Tarfilename="TI${ArgTicketNr}-${TheADC}-config.tar"
cd ${ToInstallSubfolder}
TarFile ./ ${TmpRetarFld} ${Tarfilename}

TargetFolder="/home/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}/"

# prepare script to send to target server(s)
TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm -f $TmpCmdFile
cat > ${TmpCmdFile} << EOL
#!/bin/ksh
mkdir -p ${TargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific folder."
  echo "Attempted folder name is: >>>${TargetFolder}<<<"
  exit 16
fi
EOL
chmod +x ${TmpCmdFile}

TmpCmd2File="${TmpTicketFolder}/InstallConfig.sh"
rm -rf ${TmpCmd2File}
cat > ${TmpCmd2File} <<EOL
#!/usr/local/bin/bash
#

# Variables which are taken from the parent-scripts.
TheEnv="${TheEnv}"
TheFld="${TheFld}"
TheADC="${TheADC}"
TicketNr="${ArgTicketNr}"
ToInstallSubfolder="${TargetFolder}"
BofDeployFolder="${BofDeployFolder}"
useronapplsrv="${UnixUserOnApplSrv}"
BofGroupPrefix5="${BofGroupPrefix5}"
DebugLevel="${DebugLevel}"

#Below this point, only local variables (starting with \$) may be used
DestFolder="\${TheEnv}"
FormattedADC="\${TheADC,,}"
DestFolderFinal=/\${DestFolder^^}/\${BofDeployFolder}

source \$ToInstallSubfolder/bofreminst.sh
DoInstallViaToptoa \$TheEnv \$TheFld \$TheADC \$TicketNr \$ToInstallSubfolder \$BofDeployFolder \$BofGroupPrefix5 \$DebugLevel JAVABATCHCONFIGDEPLOY

exit
EOL
chmod +x ${TmpCmd2File}

TmpCmd3File="${TmpTicketFolder}/cleanTemp.sh"
rm -f ${TmpCmd3File}
cat > ${TmpCmd3File} << EOL
#!/usr/local/bin/bash
cd 
TmpFolder="/tmp/TI${ArgTicketNr}"
TmpDeployFolder="${TargetFolder}"
if [[ -d \${TmpFolder} ]]; then
  rm -rf \${TmpFolder}
  if [[ \$? -eq 0 ]]; then
    echo "Succesfuly removed tmpdir \"\${TmpFolder}\"."
  else
    echo "Failed removing tmpdir \"\${TmpFolder}\"."
  fi
fi
if [[ -d \${TmpDeployFolder} ]]; then
  rm -rf \${TmpDeployFolder}
  if [[ \$? -eq 0 ]]; then
    echo "Succesfuly removed tmpdir \"\${TmpDeployFolder}\"."
  else
    echo "Failed removing tmpdir \"\${TmpDeployFolder}\"."
  fi
fi
# Remove the remaining files (like prepareTargetFolder)
rm -rf /tmp/TI${ArgTicketNr}*
if [[ \$? -eq 0 ]]; then
  echo "Succesfuly removed the remaining files for TI${ArgTicketNr}."
else
   echo "Failed removing the remaining files under /tmp for TI${ArgTicketNr}."
fi
EOL
chmod +x ${TmpCmd3File}

# Send defined scripts.
$ScpPutCommand $TheBOFServer $TmpCmdFile "/tmp/T${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $TheBOFServer
fi
# execute the preparetargetfolder.sh script
$SshCommand $TheBOFServer "ksh /tmp/T${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $TheBOFServer $RC
fi

$ScpPutCommand $TheBOFServer $TmpCmd2File "${TargetFolder}/InstallConfig.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "InstallConfig.sh" $TheBOFServer
fi
$ScpPutCommand ${TheBOFServer} "${ScriptPath}/bofreminst.sh" "${TargetFolder}/bofreminst.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "bofreminst.sh" $TheBOFServer
fi

$ScpPutCommand ${TheBOFServer} "${ScriptPath}/bofremtoptoainst.sh" "${TargetFolder}/bofremtoptoainst.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "bofremtoptoainst.sh" $TheBOFServer
fi


$ScpPutCommand $TheBOFServer $TmpCmd3File "${TargetFolder}/CleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "CleanTemp.sh" $TheBOFServer
fi

## send tarred config to bof
$ScpPutCommand $TheBOFServer "${TmpRetarFld}/${Tarfilename}" "${TargetFolder}/${Tarfilename}"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${Tarfilename}" $TheBOFServer
fi

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
echo "Script" ${ScriptName}  "ended."
