#!/bin/bash

#### batchpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# It will prepare the provided binaries from the oplevering-folder
# extract the tar-file, run a replace-tool call re-tar the binaries.
# And commit it to the svn repo.
#
# It will also create scripts which are sent to the batch-server..
# 1. prepareTarget Folder    : prepares the target folder on the batch-server.
# 2. batchreminst.sh         : a static script that does part of the install
# 2b. batchremtoptoainst.sh  : a static script that does part of the install
# 3. installbinaries.sh      : loads and calls the batchreminst.sh code
# 4. Clean temp              : Removes the previously created tempfolder.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# dexa  # May/2020    # 1.0.0   # clone of bofpredeploy
# dexa  # May/2020    # 1.0.1   # remove use of TheFld
# dexa  # May/2020    # 1.0.2   # fine tune tmp location on batch
# dexa  # Mar/2021    # 1.1.0   # remove 2de call GetEnvData (causes bad TheOpl if DATA PATCH ticket)
# dexa  # Mar/2021    # 1.1.0   # added dos2unix on downloaded/deleted.txt
# lekri # 12/11/2021  # 1.1.1   # ondersteuning ACC & SIM TraceIT/4me
#       #             #         #
#################################################################

ScriptName="batchpredeploy.sh"
ScriptVersion="1.1.1"
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

ActionType="batch-predeploy"
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

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_PREDEPLOY ]; then
  echo "WARN: Predeploy fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

## Get info on batch-server
GetBatchInfo
## output: $BatchDeployFolder, can be specified in ConfigIT or calculated from standard rule
## output: $AclGroupPrefix5: de eerste 5 letters van de group die toegepast moet worden.

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

LogLineDEBUG "TheBatchServer=$TheBatchServer"
LogLineDEBUG "BatchDeployFolder=$BatchDeployFolder"
LogLineDEBUG "AclGroupPrefix5=$AclGroupPrefix5"

## Doe een PING naar de Batch server
ping -c 2 "${TheBatchServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  LogLineERROR "Server ping failed for server ${TheBatchServer}"
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
## convert both to unix style files
dos2unix $HandoverDeletedList $HandoverDownloadedList

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
## TargetFolder="/export/home/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}"
TargetFolder="/HTD/autodeploy/tmp/TI${ArgTicketNr}"
TargetBase1="/HTD/autodeploy"
TargetBase2="/HTD/autodeploy/tmp"
## TargetFolder is de folder die aangemaakt wordt om de data voor dit ticket in te steken
## TargetBase1/2 zijn de onderliggende folders vanaf waar de chgrp moet gebeuren
## Dat is nodig zodat de deploy user de TargetFolder kan vinden.
## De TmpTargetFolder zelf moet group writable zijn

LogLineDEBUG2 "Start aanmaak preptargetfolder.sh"


TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm -f $TmpCmdFile
cat > ${TmpCmdFile} << EOL
#!/bin/ksh
TmpTargetFolder=${TargetFolder}
TmpTargetBase1=${TargetBase1}
TmpTargetBase2=${TargetBase2}
sudo /bin/su - toptoa -c "mkdir -p -m 770 \${TmpTargetFolder}"
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific Target-folder."
  exit 16
fi
sudo /bin/su - toptoa -c "chgrp users \${TmpTargetBase1} \${TmpTargetBase2} \${TmpTargetFolder}"
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not chgrp the shared folders."
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
TheADC="${TheADC}"
TheFld="NOT_USED"
TicketNr="${ArgTicketNr}"
ToInstallSubfolder="${TargetFolder}"
BatchDeployFolder="${BatchDeployFolder}"
useronapplsrv="${UnixUserOnApplSrv}"
AclGroupPrefix5="${AclGroupPrefix5}"
DebugLevel="${DebugLevel}"

#Below this point, only local variables (starting with \$) may be used
ToInstallFld="\${TheADC}"
ACLFolder="\${ToInstallSubfolder}/ACL"
DestFolder="\${TheEnv}"
FormattedADC="\${TheADC,,}"
DestFolderFinal=/\${DestFolder^^}/\${BatchDeployFolder}
AclFile="\${ToInstallSubfolder}/acl.txt"

## call the batchreminst.sh script
source \$ToInstallSubfolder/batchreminst.sh
DoInstallViaToptoa \$TheEnv \$TheFld \$TheADC \$TicketNr \$ToInstallSubfolder \$BatchDeployFolder \$AclGroupPrefix5 \$DebugLevel "BATCHDEPLOY"

EOL
chmod +x ${TmpCmd2file}

LogLineDEBUG2 "Einde  aanmaak installBinaries.sh"

LogLineDEBUG2 "Start aanmaak cleanTemp.sh"

TmpCmd3File="${TmpTicketFolder}/cleanTemp.sh"
rm -f ${TmpCmd3File}
cat > ${TmpCmd3File} <<EOL
#!/usr/local/bin/bash
#
# This script will cleanup the tmp ticket folder on the Batch server
# The data files in the TargetFolder must be cleaned with the normal
# user. The folder itself however can only be cleaned by toptoa.
TmpDeployFolder="${TargetFolder}"
if [[ -e \${TmpDeployFolder} ]]; then
  rm -rf \${TmpDeployFolder}/*
  if [ \$? -ne 0 ]; then
    echo "Failed removing data files from \"\${TmpDeployFolder}\"."
  else
    sudo /bin/su - toptoa -c "rmdir \${TmpDeployFolder}"
    if [ \$? -ne 0 ]; then
      echo "Failed removing folder \"\${TmpDeployFolder}\" using toptoa."
    else
      echo "Succesfuly removed tmpdir \"\${TmpDeployFolder}\"."
    fi
  fi
fi
EOL
chmod +x ${TmpCmd3File}

LogLineDEBUG "Einde aanmaak cleanTemp.sh"

## Send the newly created scripts to the TmpTargetFolder
## But first create the target folders.
LogLineDEBUG "Kopieren bestand preparetargetfolder.sh"

$ScpPutCommand ${TheBatchServer} ${TmpCmdFile} "/tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $TheBatchServer
fi

LogLineDEBUG "Uitvoeren bestand preparetargetfolder.sh"

# execute the preparetargetfolder.sh script
$SshCommand $TheBatchServer "ksh /tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $TheBatchServer $RC
fi

# remove the preparetargetfolder.sh script
$SshCommand $TheBatchServer "rm -f /tmp/TI${ArgTicketNr}_preparetargetfolder.sh"

LogLineDEBUG "Kopieren script files installBinaries.sh, batchreminst.sh, batchremtoptoainst.sh"

# Send the remaining scripts to the batch server.
$ScpPutCommand ${TheBatchServer} ${TmpCmd2file} "${TargetFolder}/installBinaries.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "installBinaries.sh" $TheBatchServer
fi

$ScpPutCommand ${TheBatchServer} "${ScriptPath}/batchreminst.sh" "${TargetFolder}/batchreminst.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "batchreminst.sh" $TheBatchServer
fi

$ScpPutCommand ${TheBatchServer} "${ScriptPath}/batchremtoptoainst.sh" "${TargetFolder}/batchremtoptoainst.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "batchremtoptoainst.sh" $TheBatchServer
fi

LogLineDEBUG "Kopieren bestand cleanTemp.sh"

$ScpPutCommand ${TheBatchServer} ${TmpCmd3File} "${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "cleanTemp.sh" $TheBatchServer
fi

## Send additional files to batch server.
## Send remaining scripts to targetfolder.
$ScpPutCommand ${TheBatchServer} ${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw "${TargetFolder}/MasterPSW_openssl"
RC=$?
if [ $RC -ne 0 ]; then
   deploy_error $DPLERR_ScpPutFailed "MasterPSW_openssl" $TheBOFServer
fi
### downloadedlist

LogLineDEBUG "Kopieren bestand deletedlist"

$ScpPutCommand ${TheBatchServer} "${HandoverDeletedList}" "${TargetFolder}/TI${ArgTicketNr}-deleted.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDeletedList}" $TheBatchServer
fi
### deletedlist
LogLineDEBUG "Kopieren bestand downloadedlist"

$ScpPutCommand ${TheBatchServer} "${HandoverDownloadedList}" "${TargetFolder}/TI${ArgTicketNr}-downloaded.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDownloadedList}" $TheBatchServer
fi


## Send all files towards the target batch-server.
LogLineDEBUG "Start sending all the required directories to ${TheBatchServer} for ticket ${ArgTicketNr}."

for folder  in $(find ${TmpTicketFolder}/*/ -maxdepth 0 -type d |grep -v "^.$"); do
  foldername=$(echo ${folder/$TmpTicketFolder/""})
  foldernameSingle=$(basename "$foldername" | cut -d. -f1)

  folderDest=$(echo ${foldername/$foldernameSingle/""})
  LogLineDEBUG "copying '${folder}' to '${TargetFolder}${folderDest}'"

  $ScpPutCommand ${TheBatchServer} "${folder}" "${TargetFolder}${folderDest}"
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_ScpPutFailed "$folder" $TheBatchServer
  fi
done
LogLineDEBUG "Finished creating all the required directories on ${TheBatchServer} for ticket ${ArgTicketNr}."

## LogLineDEBUG "Start sending all the required files to ${TheBatchServer} for ticket ${ArgTicketNr}."
## for file in $(find ${TmpTicketFolder} -type f ); do
##  filename=$(echo ${file/$TmpTicketFolder/""})
##  $ScpPutCommand ${TheBOFServer} "${file}" "${TargetFolder}${filename}"
  ##RC=$?
  ##if [ $RC -ne 0 ]; then
    ##deploy_error $DPLERR_ScpPutFailed "$file" $TheBOFServer
  ##fi
## done
## LogLineDEBUG "Finished sending all the required files on ${TheBOFServer} for ticket ${ArgTicketNr}."

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
LogLineINFO "Script" ${ScriptName}  "ended."
exit

