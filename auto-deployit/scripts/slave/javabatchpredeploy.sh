#!/bin/bash

#### javabatchpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# It will prepare the provided binaries from the oplevering-folder
# extract the tar-file, run a replace-tool call re-tar the binaries.
# And commit it to the svn repo.
#
# It will also create 4 in-here script which are sent to the bof-server..
# 1. prepareTarget Folder: prepares the target folder on the bof-server.
# 2. untar:					Untars the binaries to a temp-folder
# 3. Install binaries:		saves the current permissions, clear lib-folder
#                           set the saved permissions to the extract-folder.
#                           then installs the binaries to the dest-folder.
# 4. Clean temp:			Removes the previously created tempfolder.
#                           If you got here, it means the deploy went ok.
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# jaden # Mar/2018    # 1.0.0 # initial POC versie
# jaden # Jun/2018    # 1.0.1 # Fixed several bugs
# dexa  # feb/2019    # 1.1.0 # Added better logging
# dexa  # feb/2019    # 1.1.0 # remove "cims" hard-coding
# dexa  # apr/2019    # 1.2.0 # transfer processing naar bofreminst
# lekri # 12/11/2021  # 1.2.1 # ondersteuning ACC & SIM TraceIT/4me
#################################################################
ScriptName="javabatchpredeploy.sh"
ScriptVersion="1.2.1"
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
LogLineINFO "  ENV = '${ArgEnv}'"
LogLineINFO "  DOEL = '${ArgDoel}'"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData

SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="javabatch-predeploy"
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

## Get info on bof-server
GetBofInfo
## output: ${BofDeployFolder}, ${TheFld}

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

## Maak locale folder klaar voor downloads
## Clean up local traces of previous runs of this same ticket
rm -rf ${TmpTicketFolder}
mkdir  ${TmpTicketFolder}
cd ${TmpTicketFolder}

## Download ticket materiaal
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
	exit 16
  fi
  ## Als we dit punt bereiken, dan is er GEEN downloaded file maar wel deleted files.
  ## Dus heeft het geen zin om de downloaded file te parsen.
  OnlyDeletes=1
fi

line1=$(cat ${HandoverDownloadedList} ${HandoverDeletedList} | head -n 1)
echo "line1 = " ${line1}
## expected format: OK      <adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
echo "line1 (stripped) = " ${line1}
firstpart=${line1%%"/"*}

# Save the ADC with capitals.
DerivedADC=${firstpart^^}
## Compare the requested ADC with the one derived from the HODL file
if [ "$ArgAppl" = "$DerivedADC" ]; then
  LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
else
  echo "ERROR: Dit ticket bevat files die, op basis van hun locatie, niet tot deze ADC behoren. Deploy kan niet verdergaan."
  echo "Deploy voor ADC=${ArgAppl}. Files in ticket zouden zijn voor ADC=${DerivedADC}."
  exit 16
fi

ToInstallSubfolder="${TmpTicketFolder}/${firstpart}"
TargetFolder="/home/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}"
ApplFolder="${TheEnv}/${TheFld}/"

# Prepare delete script if necesary.
if [ -s ${HandoverDeletedList} ]; then
  ## Er zijn delete requests die we moeten afhandelen op de target servers.
  cd ${TmpTicketFolder}
  Handover_MakeDeleteBashScript
  mkdir -p "${TmpTicketFolder}/deployIT-scripts"
  # grant execute and write permissions 
  chmod u+rwx ${TmpTicketFolder}/TI${ArgTicketNr}-dodelete.sh
  chown ${UnixUserOnApplSrv} ${TmpTicketFolder}/TI${ArgTicketNr}-dodelete.sh
fi

TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm -rf $TmpCmdFile
cat >${TmpCmdFile} << EOL
#!/bin/ksh
TmpTargetFolder="${TargetFolder}"
mkdir -p \${TmpTargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific tempTarget-folder."
  exit 16
fi
chmod -R g+rx \${TmpTargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not chmod the ticket specific folder (for toptoa)."
  exit 16
fi
EOL
chmod +x ${TmpCmdFile}

TmpCmd2file="${TmpTicketFolder}/installBinaries.sh"
rm -rf ${TmpCmd2file}
cat > ${TmpCmd2file} <<EOL
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
DoInstallViaToptoa \$TheEnv \$TheFld \$TheADC \$TicketNr \$ToInstallSubfolder \$BofDeployFolder \$BofGroupPrefix5 \$DebugLevel JAVABATCHDEPLOY

exit
EOL
chmod +x ${TmpCmd2file}

TmpCmd3File="${TmpTicketFolder}/cleanTemp.sh"
rm -rf ${TmpCmd3File}
cat > ${TmpCmd3File} <<EOL
#!/usr/local/bin/bash
cd
TmpDeployFolder="${TargetFolder}"
if [[ -e \${TmpDeployFolder} ]]; then
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

## Send the newly created scripts to the TmpTargetFolder
## But first create the target folders.
LogLineINFO "Copying scripts to destination server."

$ScpPutCommand ${TheBOFServer} ${TmpCmdFile} "/tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $TheBOFServer
fi
# execute the preparetargetfolder.sh script
$SshCommand $TheBOFServer "/tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $TheBOFServer $RC
fi

# Send the remaining scripts to the bof.
$ScpPutCommand ${TheBOFServer} ${TmpCmd2file} "${TargetFolder}/installBinaries.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "installBinaries.sh" $TheBOFServer
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

$ScpPutCommand ${TheBOFServer} ${TmpCmd3File} "${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "cleanTemp.sh" $TheBOFServer
fi
LogLineDEBUG "All scripts are copied to destination server."



## Send additional files to bof.
### dodelete.sh
if [[ -e ${TmpTicketFolder}/TI${ArgTicketNr}-dodelete.sh ]]; then
  $ScpPutCommand ${TheBOFServer} "${TmpTicketFolder}/TI${ArgTicketNr}-dodelete.sh" "${TargetFolder}/TI${ArgTicketNr}-dodelete.sh"
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_ScpPutFailed "${TmpTicketFolder}/TI${ArgTicketNr}-dodelete.sh" $TheBOFServer
  fi
fi
### downloadedlist
$ScpPutCommand ${TheBOFServer} "${HandoverDeletedList}" "${TargetFolder}/TI${ArgTicketNr}-deleted.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDeletedList}" $TheBOFServer
fi
### deletedlist
$ScpPutCommand ${TheBOFServer} "${HandoverDownloadedList}" "${TargetFolder}/TI${ArgTicketNr}-downloaded.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDownloadedList}" $TheBOFServer
fi


## Send the ticket files to the targetFolder on the bof-server
cd ${TmpTicketFolder}

LogLineDEBUG "Will copy ticket files to destination server."
$ScpPutCommand ${TheBOFServer} "${TheADC,,}" "${TargetFolder}/${TheADC,,}"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${tarFile}" $TheBOFServer
fi
LogLineDEBUG "copy of ticket files to destination server done."

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
echo "Script" ${ScriptName}  "ended."
exit
