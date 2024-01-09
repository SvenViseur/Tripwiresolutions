#!/bin/bash

#### bofpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# It will prepare the provided binaries from the oplevering-folder
# extract the tar-file, run a replace-tool call re-tar the binaries.
# And commit it to the svn repo.
#
# It will also create scripts which are sent to the bof-server..
# 1. prepareTarget Folder: prepares the target folder on the bof-server.
# 2. bofreminst.sh       : a static script that does the install
# 3. installbinaries.sh  : loads and calls the bofreminst.sh code
# 4. Clean temp          : Removes the previously created tempfolder.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# jaden # 13/08/2018  # 1.0-0 # initial POC versie
# vevi  # Oct/2018    # 1.1-0 # Updated PoC
# dexa  # Feb/2019    # 1.2.0 # logging, DeployIT_Stap_Doel
#       #             #       # move code to bofreminst.sh
#################################################################
ScriptName="bofpredeploy.sh"
ScriptVersion="1.2.0"
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
LogLineINFO "  EXTRA OPTIONS = '${ArgExtraOpts}'"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData

SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="bof-predeploy"
MaakTmpTicketFolder
cd ${TmpTicketFolder}

TmpFld=$TmpTicketFolder
TheEnv=$ArgEnv
TheADC=$ArgAppl

## GetDynOplOmg:
## In: ArgTicketNr, TmpFld    Out: TheOpl
GetDynOplOmg

## Get default settings based on the ENV and ADC
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level
Replace_Tool_Defaults
EchoDeployITSettings
LoggingBaseFolder="${ConfigNfsFolderRepllogOnServer}/target_${ArgEnv}/"
mkdir -p $LoggingBaseFolder

StapDoelBepalen $ArgDoel

Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"
  
if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_PREDEPLOY ]; then
  echo "WARN: Predeploy fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

GetEnvData

## Get info on bof-server
GetBofInfo
## output: $BofDeployFolder, can be specified in ConfigIT or calculated from standard rule
## output: $BofGroupPrefix5: de eerste 5 letters van de group die toegepast moet worden.

## Determine the target elements for this predeploy:
## - the BOF server: $TheBOFServer
## - the root path where to deploy: $TheBOFTargetPath
TheBOFServer="bof_${TheBof}.argenta.be"

LogLineDEBUG "TheBOFServer=$TheBOFServer"
LogLineDEBUG "BofDeployFolder=$BofDeployFolder"
LogLineDEBUG "TheFld=$TheFld"
LogLineDEBUG "BofGroupPrefix5=$BofGroupPrefix5"

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

LogLineDEBUG2 "Start aanmaak preptargetfolder.sh"


TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm -f $TmpCmdFile
cat > ${TmpCmdFile} << EOL
#!/bin/ksh
TmpTargetFolder=${TargetFolder}
mkdir -p \${TmpTargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific Target-folder."
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

LogLineDEBUG2 "Einde aanmaak preptargetfolder.sh"


LogLineDEBUG2 "Start aanmaak installBinaries.sh"

TmpCmd2file="${TmpTicketFolder}/installBinaries.sh"
rm -f ${TmpCmd2file}
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
ToInstallFld="\${TheADC}"
ACLFolder="\${ToInstallSubfolder}/ACL"
DestFolder="\${TheEnv}"
FormattedADC="\${TheADC,,}"
DestFolderFinal=/\${DestFolder^^}/\${BofDeployFolder}
AclFile="\${ToInstallSubfolder}/acl.txt"

## call the bofreminst.sh script
source \$ToInstallSubfolder/bofreminst.sh
DoInstallViaToptoa \$TheEnv \$TheFld \$TheADC \$TicketNr \$ToInstallSubfolder \$BofDeployFolder \$BofGroupPrefix5 \$DebugLevel "BOFDEPLOY"

EOL
chmod +x ${TmpCmd2file}

LogLineDEBUG2 "Einde  aanmaak installBinaries.sh"

LogLineDEBUG2 "Start aanmaak cleanTemp.sh"

TmpCmd3File="${TmpTicketFolder}/cleanTemp.sh"
rm -f ${TmpCmd3File}
cat > ${TmpCmd3File} <<EOL
#!/usr/local/bin/bash
#
# This script will cleanup the tmp ticket folder on 
# the BOF server
TmpDeployFolder="${TargetFolder}"
if [[ -e \${TmpDeployFolder} ]]; then
  rm -rf \${TmpDeployFolder}
  if [ \$? -eq 0 ]; then
    echo "Succesfuly removed tmpdir \"\${TmpDeployFolder}\"."
  else
    echo "Failed removing tmpdir \"\${TmpDeployFolder}\"."
  fi
fi
EOL
chmod +x ${TmpCmd3File}

LogLineDEBUG "Einde aanmaak cleanTemp.sh"

## Send the newly created scripts to the TmpTargetFolder
## But first create the target folders.
LogLineDEBUG "Kopieren bestand preparetargetfolder.sh"

$ScpPutCommand ${TheBOFServer} ${TmpCmdFile} "/tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $TheBOFServer
fi

LogLineDEBUG "Uitvoeren bestand preparetargetfolder.sh"

# execute the preparetargetfolder.sh script
$SshCommand $TheBOFServer "ksh /tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $TheBOFServer $RC
fi

LogLineDEBUG "Kopieren script files installBinaries.sh, bofreminst.sh, bofremtoptoainst.sh"

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

LogLineDEBUG "Kopieren bestand cleanTemp.sh"

$ScpPutCommand ${TheBOFServer} ${TmpCmd3File} "${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "cleanTemp.sh" $TheBOFServer
fi

## Send additional files to bof.
### downloadedlist

LogLineDEBUG "Kopieren bestand deletedlist"

$ScpPutCommand ${TheBOFServer} "${HandoverDeletedList}" "${TargetFolder}/TI${ArgTicketNr}-deleted.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDeletedList}" $TheBOFServer
fi
### deletedlist
LogLineDEBUG "Kopieren bestand downloadedlist"

$ScpPutCommand ${TheBOFServer} "${HandoverDownloadedList}" "${TargetFolder}/TI${ArgTicketNr}-downloaded.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDownloadedList}" $TheBOFServer
fi


## Send all files towards the target bof-server.
LogLineDEBUG "Start sending all the required directories to the ${TheBOFServer} for ticket ${ArgTicketNr}."

for folder  in $(find ${TmpTicketFolder}/*/ -maxdepth 0 -type d |grep -v "^.$"); do
  foldername=$(echo ${folder/$TmpTicketFolder/""})
  foldernameSingle=$(basename "$foldername" | cut -d. -f1)

  folderDest=$(echo ${foldername/$foldernameSingle/""})
  LogLineDEBUG "copying '${folder}' to '${TargetFolder}${folderDest}'"

  $ScpPutCommand ${TheBOFServer} "${folder}" "${TargetFolder}${folderDest}"
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_ScpPutFailed "$folder" $TheBOFServer
  fi
done
LogLineDEBUG "Finished creating all the required directory on ${TheBOFServer} for ticket ${ArgTicketNr}."

LogLineDEBUG "Start sending all the required files to the ${TheBOFServer} for ticket ${ArgTicketNr}."
for file in $(find ${TmpTicketFolder} -type f ); do
  filename=$(echo ${file/$TmpTicketFolder/""})
##  $ScpPutCommand ${TheBOFServer} "${file}" "${TargetFolder}${filename}"
  ##RC=$?
  ##if [ $RC -ne 0 ]; then
    ##deploy_error $DPLERR_ScpPutFailed "$file" $TheBOFServer
  ##fi
done
LogLineDEBUG "Finished sending all the required files on ${TheBOFServer} for ticket ${ArgTicketNr}."

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
LogLineINFO "Script" ${ScriptName}  "ended."
exit

