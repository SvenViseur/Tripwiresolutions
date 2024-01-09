#!/bin/bash

#### ivlpostdeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# IMPORTANT: Where most scripts run on the slave of the target
# environment, this script may not. It depends on which DeployIT
# env is used rather than which target env. These definitions are
# located in a csv file named IVL2BATCH.csv and are used by a
# groovy script when building the IVL deploy jobs.
#
#
# It will copy material to the batch server for a async OEMM deploy
#
# It will create scripts which are sent to the batch server
# 1. prepareTarget Folder: prepares the target folder on the odi-server.
# 2. movefolder.sh       : moves the temp folder to the location where
#                          it can later be processed
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The environment the normal deploy goes to
#     DOEL		: The level of deploy. If not Install or higher,
#                         all processing will be skipped
#     TARGETSRV		: The target server where to deposit
#     TARGETFLD1	: The first target folder where to put the data
#     TARGETFLD2	: The second target folder where to put the data
#                         If the second target is not used, it should be "NVT"
#     TARGETGROUP   : The group of the target folder.
#
#################################################################
# Change history
#################################################################
# dexa  # Dec/2020    # 1.0.0 # initial version
# dexa  # Dec/2020    # 1.0.1 # corr user account to connect with
# lekri # Sept/2020   # 1.1.0 # ensure the target folder has the correct
#       #             #       # user and group assignment.
# lekri # 12/11/2021  # 1.1.1 # ondersteuning ACC & SIM TraceIT/4me
#       #             #       #
#################################################################
ScriptName="ivlpostdeploy.sh"
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
ArgTargetSrv=$5
ArgTargetFld1=$6
ArgTargetFld2=$7
ArgTargetGroup=$8
ArgExtraOpts=$9

LogLineINFO "Script" ${ScriptName}  "started."
LogLineINFO "Options are:"
LogLineINFO "  APPL = '${ArgAppl}'"
LogLineINFO "  TICKETNR = '${ArgTicketNr}'"
LogLineINFO "  TARGETSRV = '${ArgTargetSrv}'"
LogLineINFO "  DOEL = '${ArgDoel}'"
LogLineINFO "  TARGETFLD1 = '${ArgTargetFld1}'"
LogLineINFO "  TARGETFLD2 = '${ArgTargetFld2}'"
LogLineINFO "  TARGETGROUP = '${ArgTargetGroup}'"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData

SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="ivl-postdeploy"
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

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_ACTIVATE ]; then
  echo "WARN: Post Deploy fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

GetIvlInfo ## fetch mail address for alerting messages

## Doe een PING naar de ODI server
ping -c 2 "${ArgTargetSrv}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  echo "Server ping failed for server ${ArgTargetSrv}"
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
## Future improvement: the below code should be migrated to the
## HODL_parse function in the common function library. That deals
## already with the config and password first level folders.
firstpart=${line1%%"/"*}
restpart=${line1:${#firstpart}+1}
secondpart=${restpart%%"/"*}
LogLineDEBUG "first folder part is: ${firstpart}"
LogLineDEBUG "second folder part is: ${secondpart}"
if [[ ${firstpart} -eq "ivl" ]]; then
  LogLineINFO "Line 1 is in the expected format for an ivl ticket!"
else
  if [[ ${firstpart} -eq "civl" ]]; then
    LogLineINFO "Line 1 is in the expected format for a civl ticket!"
  else
    echo "Line 1 is niet in het verwachte formaat. De eerste folder level zou"
    echo "ofwel 'ivl' ofwel 'civl' moeten zijn."
    echo "De eerste folder level is echter: >>${firstpart}<<"
    exit 16
  fi
fi

# Save the ADC with capitals.
DerivedADC=${secondpart^^}
## Compare the requested ADC with the one derived from the HODL file
if [ "$ArgAppl" = "$DerivedADC" ]; then
  LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
else
  echo "ERROR: Dit ticket bevat files die, op basis van hun locatie, niet tot deze ADC behoren. Deploy kan niet verdergaan."
  echo "Deploy voor ADC=${ArgAppl}. Files in ticket zouden zijn voor ADC=${DerivedADC}."
  exit 16
fi

TargetFolder="/HTD/autodeploy/tmp/TI${ArgTicketNr}"
TargetBase1="/HTD/autodeploy"
TargetBase2="/HTD/autodeploy/tmp"
TargetFinalFld1="$ArgTargetFld1"
TargetFinalFld2="$ArgTargetFld2"
TargetGroup="$ArgTargetGroup"
TimestampFolder="DT$(date ""+%Y-%m-%d_%H-%M-%S"")_TI${ArgTicketNr}"
## TargetFolder is de folder die aangemaakt wordt om de data voor dit ticket in te steken
## TargetBase1/2 zijn de onderliggende folders vanaf waar de chgrp moet gebeuren
## Dat is nodig zodat de deploy user de TargetFolder kan vinden.
## De TmpTargetFolder zelf moet group writable zijn
LogLineDEBUG2 "Timestamp folder name: $TimestampFolder"

LogLineDEBUG2 "Start aanmaak batchpreptargetfolder.sh"

TmpCmdFile="${TmpTicketFolder}/batchpreptargetfolder.sh"
rm -f $TmpCmdFile
cat > ${TmpCmdFile} << EOL
#!/bin/bash
TmpTargetFolder=${TargetFolder}
TmpTargetBase1=${TargetBase1}
TmpTargetBase2=${TargetBase2}
TmpTargetFinalFld1=${TargetFinalFld1}
TmpTargetFinalFld2=${TargetFinalFld2}
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
## check existence of Final folder 1
if [ ! -d "\$TmpTargetFinalFld1" ]; then
  sudo /bin/su - toptoa -c "mkdir -p -m 770 \${TmpTargetFinalFld1}"
  ## it is assumed the above folder is located under the correct application folder
  ## such that the appropriate ownership group will allow later to remove the files
  ## by the IWS batch process that uses the files. The ownership of this directory
  ## will be set explicitly later on in any case.
fi
if [ ! "\TmpTargetFinalFld2" = "NVT" ]; then
  if [ ! -d "\$TmpTargetFinalFld2" ]; then
    sudo /bin/su - toptoa -c "mkdir -p -m 770 \${TmpTargetFinalFld2}"
    ## it is assumed the above folder is located under the correct application folder
    ## such that the appropriate ownership group will allow later to remove the files
    ## by the IWS batch process that uses the files. The ownership of this directory
    ## will be set explicitly later on in any case.
  fi
fi
EOL
chmod +x ${TmpCmdFile}

LogLineDEBUG2 "Einde aanmaak batchpreptargetfolder.sh"

LogLineDEBUG2 "Start aanmaak batchmovedatafolder.sh"

TmpCmd2file="${TmpTicketFolder}/batchmovedatafolder.sh"
rm -f ${TmpCmd2file}
cat > ${TmpCmd2file} <<EOL
#!/bin/bash
#

# Variables which are taken from the parent-scripts.
TheEnv="${TheEnv}"
BaseFolder="${TargetFolder}"
TheADC="${TheADC}"
TicketNr="${ArgTicketNr}"
DebugLevel="${DebugLevel}"
TargetFinalFld1="${TargetFinalFld1}"
TargetFinalFld2="${TargetFinalFld2}"
TargetGroup="${TargetGroup}"
TimestampFolder="${TimestampFolder}"
ZipFolder="${TargetFolder}/${firstpart}/${secondpart}"
JenkinsBuildNr="${BUILD_NUMBER}"
JenkinsBuildURL="${BUILD_URL}"
#Below this point, only local variables (starting with \$) may be used
echo "running batchmovedatafolder.sh now."

## first set group to 'users' to ensure toptoa can read it
chgrp -R users "\${BaseFolder}/"*
if [ ! "\$TargetFinalFld2" = "NVT" ]; then
  sudo /bin/su - toptoa -c "cp -r ""\$ZipFolder"" ""\${TargetFinalFld2}/\${TimestampFolder}"" "
  RC=\$?
  if [ \$RC -ne 0 ]; then
    echo "Copy of \$ZipFolder to \${TargetFinalFld2}/\${TimestampFolder} failed."
    exit 16
  fi
  sudo /bin/su - toptoa -c "chmod -R g+w ""\${TargetFinalFld2}/\${TimestampFolder}"" "
  RC=\$?
  if [ \$RC -ne 0 ]; then
    echo "Chmod of \$ZipFolder to \${TargetFinalFld2}/\${TimestampFolder} failed."
    exit 16
  fi
  sudo /bin/su - toptoa -c "sudo chgrp -R \${TargetGroup} ""\${TargetFinalFld2}/\${TimestampFolder}"" "
  RC=\$?
  if [ \$RC -ne 0 ]; then
    echo "Chgrp of \${TargetFinalFld2}/\${TimestampFolder} to \${TargetGroup} failed."
    exit 16
  fi
fi
sudo /bin/su - toptoa -c "cp -r ""\$ZipFolder"" ""\${TargetFinalFld1}/\${TimestampFolder}"" "
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Copy of \$ZipFolder to \${TargetFinalFld1}/\${TimestampFolder} failed."
  exit 16
fi
sudo /bin/su - toptoa -c "chmod -R g+w ""\${TargetFinalFld1}/\${TimestampFolder}"" "
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Chmod of \$ZipFolder to \${TargetFinalFld1}/\${TimestampFolder} failed."
  exit 16
fi
sudo /bin/su - toptoa -c "sudo chgrp -R \${TargetGroup} ""\${TargetFinalFld1}/\${TimestampFolder}"" "
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Chgrp of \${TargetFinalFld1}/\${TimestampFolder} to \${TargetGroup} failed."
  exit 16
fi

echo "ending batchmovedatafolder.sh."

EOL
chmod +x ${TmpCmd2file}

LogLineDEBUG2 "Einde  aanmaak batchmovedatafolder.sh"

LogLineDEBUG2 "Start aanmaak cleanTemp.sh"

TmpCmd3File="${TmpTicketFolder}/cleanTemp.sh"
rm -f ${TmpCmd3File}
cat > ${TmpCmd3File} <<EOL
#!/bin/bash
#
# This script will cleanup the tmp ticket folder on
# the ODI server
TmpDeployFolder="${TargetFolder}"
if [[ -e \${TmpDeployFolder} ]]; then
  ## first clean the contents of the TmpDeployFolder using the normal user
  ## then, use toptoa to remove the folder itself which should then be empty
  ## If that last rmdir command worked, we are sure all is cleaned.
  rm -rf \${TmpDeployFolder}/*
  sudo /bin/su - toptoa -c "rmdir \${TmpDeployFolder}"
  if [ \$? -eq 0 ]; then
    echo "Succesfuly removed tmpdir \"\${TmpDeployFolder}\"."
  else
    echo "Failed removing tmpdir \"\${TmpDeployFolder}\"."
  fi
fi
EOL
chmod +x ${TmpCmd3File}

LogLineDEBUG "Einde aanmaak cleanTemp.sh"

## Here start the SSH connections. They occur to the ArgTargetSrv.
## We must therefore set the connection user accordingly.
SSHTargetUser="Unknown"
if [ "${ArgTargetSrv}" = "sv-arg-batch-a1" ]; then
  SSHTargetUser="taccdeps"
fi
if [ "${ArgTargetSrv}" = "sv-arg-batch-p1" ]; then
  SSHTargetUser="tprddeps"
fi
if [ "${ArgTargetSrv}" = "sv-arg-batch-s1" ]; then
  SSHTargetUser="tsimdeps"
fi
if [ "${SSHTargetUser}" = "Unknown" ]; then
  echo "The target server ${ArgTargetSrv} has no known user account to use for an SSH connection. Cannot continue."
fi

## Send the newly created scripts to the TmpTargetFolder
## But first create the target folders.
LogLineDEBUG "Kopieren bestand preparetargetfolder.sh"

$ScpPutCommand ${ArgTargetSrv} ${TmpCmdFile} "/tmp/TI${ArgTicketNr}_batchpreparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "batchpreparetargetfolder.sh" $ArgTargetSrv
fi

LogLineDEBUG "Uitvoeren bestand batchpreparetargetfolder.sh"

# execute the preparetargetfolder.sh script
$SshCommand ${ArgTargetSrv} "bash /tmp/TI${ArgTicketNr}_batchpreparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $ArgTargetSrv $RC
fi

LogLineDEBUG "Kopieren script file batchmovedatafolder.sh"

# Send the remaining scripts to the bof.
$ScpPutCommand ${ArgTargetSrv} ${TmpCmd2file} "${TargetFolder}/batchmovedatafolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "batchmovedatafolder.sh" $ArgTargetSrv
fi

## Send all files towards the target odi-server.
LogLineDEBUG "Start sending all the required directories to the ${ArgTargetSrv} for ticket ${ArgTicketNr}."

for folder  in $(find ${TmpTicketFolder}/*/ -maxdepth 0 -type d |grep -v "^.$"); do
  foldername=$(echo ${folder/$TmpTicketFolder/""})
  foldernameSingle=$(basename "$foldername" | cut -d. -f1)

  folderDest=$(echo ${foldername/$foldernameSingle/""})
  LogLineDEBUG "copying '${folder}' to '${TargetFolder}${folderDest}'"

  $ScpPutCommand ${ArgTargetSrv} "${folder}" "${TargetFolder}${folderDest}"
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_ScpPutFailed "$folder" $ArgTargetSrv
  fi
done
LogLineDEBUG "Finished creating all the required directory on ${ArgTargetSrv} for ticket ${ArgTicketNr}."

LogLineDEBUG "Finished sending all the required files on ${ArgTargetSrv} for ticket ${ArgTicketNr}."

LogLineDEBUG "Kopieren bestand cleanTemp.sh"

$ScpPutCommand ${ArgTargetSrv} ${TmpCmd3File} "${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "cleanTemp.sh" $ArgTargetSrv
fi

$SshCommand $ArgTargetSrv "/bin/bash ${TargetFolder}/batchmovedatafolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/batchmovedatafolder.sh" $ArgTargetSrv $RC
fi

$SshCommand $ArgTargetSrv "/bin/bash ${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "${TargetFolder}/cleanTemp.sh" $ArgTargetSrv $RC
fi

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
LogLineINFO "Script" ${ScriptName}  "ended."
exit

