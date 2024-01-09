#!/bin/bash

#### ivlpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# It will prepare the provided binaries from the oplevering-folder
#
# It will create scripts which are sent to the odi-server..
# 1. prepareTarget Folder: prepares the target folder on the odi-server.
# 2. odireminst.sh       : a static script that does the install
# 3. installodi.sh       : loads and calls the odireminst.sh code
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
# dexa  # Dec/2019    # 1.0.0 # initial version
# dexa  # Maa/2020    # 1.1.0 # added Jenkins Build nr en URL
# dexa  # Aug/2020    # 1.1.1 # remove source ivl_functions
# lekri # 12/11/2021  # 1.1.2 # ondersteuning ACC & SIM TraceIT/4me
#       #             #       #
#       #             #       #
#################################################################
ScriptName="ivlpredeploy.sh"
ScriptVersion="1.1.2"
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

ActionType="ivl-predeploy"
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

GetEnvData

## Get info on ivl-server
GetIvlInfo
## output:
##     $OdiTgtServer           : the server to connect to
##     $OdiTgtLoggingFolder    : the logging folder on the target machine

LogLineDEBUG "OdiTgtServer=$OdiTgtServer"
LogLineDEBUG "OdiTgtLoggingFolder=$OdiTgtLoggingFolder"

## Determine value of DoTestSql
## DoTestSql is used to perform a trial SQL DDL update on a test database before
## the real database DDL execution is done. This trial is done to validate the
## SQL DDL code.
DoTestSql=0 ## default is OFF
if [ "$ArgEnv" = "ACC" ]; then
  DoTestSql=1
  LogLineDEBUG "The flag DoTestSql is activated."
fi

## Doe een PING naar de ODI server
ping -c 2 "${OdiTgtServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  echo "Server ping failed for server ${OdiTgtServer}"
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

ToInstallSubfolder="${TmpTicketFolder}/${firstpart}/${secondpart}"
TargetFolder="/data/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}"
TgtLogFile="${OdiTgtLoggingFolder}/TI${ArgTicketNr}-${BUILD_NUMBER}.log"

# Use Replace tool to parse credentials files before sending them over
cd $TmpTicketFolder
mkdir "psw"
mkdir "psw/in"
mkdir "psw/out"
cp "$ScriptPath/ivlremcfgoracle.sh" "psw/in/"
if [ ${DoTestSql} -eq 1 ]; then
  ## We must perform a test SQL on this environment. Copy the related script.
  cp "$ScriptPath/ivlremtestsql.sh" "psw/in/"
fi
cp "$ScriptPath/ivlremcfgodi.sh" "psw/in/"
cp "$ScriptPath/ivlremgroovy-ivl-generic.conf" "psw/in/"
Ivl_replace "${TmpTicketFolder}/psw/in" "${TmpTicketFolder}/psw/out"
LogLineINFO "Credentials files were processed."

LogLineDEBUG2 "Start aanmaak preptargetfolder.sh"

TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm -f $TmpCmdFile
cat > ${TmpCmdFile} << EOL
#!/bin/bash
TmpTargetFolder=${TargetFolder}
TheEnv=${TheEnv}
TheFld=${TheFld}
TheADC=${TheADC}
TicketNr=${ArgTicketNr}
LoggingFolder=${OdiTgtLoggingFolder}
LogFile=${TgtLogFile}
mkdir -p \${TmpTargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific Target-folder."
  exit 16
fi
## If the Target folder already existed, it might be that it is
## not empty. Therefore, we will clean it (no error checking).
rm -rf \${TmpTargetFolder}/*

## Create a subfolder psw, to store confidential cfg files.
mkdir \${TmpTargetFolder}/psw

if [ ! -d \${LoggingFolder} ]; then
  echo "The logging folder \${LoggingFolder} (derived from"
  echo " DEPLOYIT_IVL_LOGGING_FOLDER in ConfigIT) does not exist!"
  exit 16
fi
## create the log file
echo "DeployIT log file started for IVL deploy" > \${LogFile}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific log file (\${LogFile})."
  exit 16
fi
## add some info to the log file. As the previous command worked,
## we don't need to test each command here.
echo "Deploy started on " \$(date) >> \${LogFile}
echo "Deploy for ticket \${TicketNr} for ADC \${TheADC}" >> \${LogFile}
echo "Work files and scripts are located in \${TmpTargetFolder}" >> \${LogFile}
echo "Please note that the above location will be cleaned when the deploy completes correctly." >> \${LogFile}
EOL
chmod +x ${TmpCmdFile}

LogLineDEBUG2 "Einde aanmaak preptargetfolder.sh"


LogLineDEBUG2 "Start aanmaak installIvl.sh"

TmpCmd2file="${TmpTicketFolder}/installIvl.sh"
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
LogFile="${TgtLogFile}"
ZipFolder="${TargetFolder}/${firstpart}/${secondpart}"
DoTestSql="${DoTestSql}"
JenkinsBuildNr="${BUILD_NUMBER}"
JenkinsBuildURL="${BUILD_URL}"
#Below this point, only local variables (starting with \$) may be used
echo "running installIvl.sh now." >> \$LogFile

## call the slave specific error & warning defs and functions
source \${BaseFolder}/deploy_slverrorwarns.sh

## call the ivlreminst.sh script
source \${BaseFolder}/ivlreminst.sh
DoIvlFullInstall \$TheEnv \$BaseFolder \$TheADC \$TicketNr \$DebugLevel \$LogFile \$ZipFolder \$DoTestSql \$JenkinsBuildNr \$JenkinsBuildURL
echo "Back after call from DoIvlFullInstall function" >> \$LogFile

echo "ending installIvl.sh." >> \$LogFile

EOL
chmod +x ${TmpCmd2file}

LogLineDEBUG2 "Einde  aanmaak installIvl.sh"

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

$ScpPutCommand ${OdiTgtServer} ${TmpCmdFile} "/tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $OdiTgtServer
fi

LogLineDEBUG "Uitvoeren bestand preparetargetfolder.sh"

# execute the preparetargetfolder.sh script
$SshCommand $OdiTgtServer "bash /tmp/TI${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $OdiTgtServer $RC
fi

LogLineDEBUG "Kopieren script files installIvl.sh, ivlreminst.sh"

# Send the remaining scripts to the bof.
$ScpPutCommand ${OdiTgtServer} ${TmpCmd2file} "${TargetFolder}/installIvl.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "installIvl.sh" $OdiTgtServer
fi

$ScpPutCommand ${OdiTgtServer} "${ScriptPath}/ivlreminst.sh" "${TargetFolder}/ivlreminst.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "ivlreminst.sh" $OdiTgtServer
fi

$ScpPutCommand ${OdiTgtServer} "${ScriptPath}/deploy_slverrorwarns.sh" "${TargetFolder}/deploy_slverrorwarns.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "deploy_slverrorwarns.sh" $OdiTgtServer
fi

$ScpPutCommand ${OdiTgtServer} "${ScriptPath}/ivl_groovy" "${TargetFolder}/groovy"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "ivl_groovy" $OdiTgtServer
fi

$ScpPutCommand ${OdiTgtServer} "${TmpTicketFolder}/psw/out/ivlremcfgoracle.sh" "${TargetFolder}/psw/ivlremcfgoracle.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "ivlremcfgoracle.sh" $OdiTgtServer
fi

if [ ${DoTestSql} -eq 1 ]; then
  ## We must perform a test SQL on this environment. Therefore, the related script must be copied.
  $ScpPutCommand ${OdiTgtServer} "${TmpTicketFolder}/psw/out/ivlremtestsql.sh" "${TargetFolder}/psw/ivlremtestsql.sh"
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_ScpPutFailed "ivlremtestsql.sh" $OdiTgtServer
  fi
fi
$ScpPutCommand ${OdiTgtServer} "${TmpTicketFolder}/psw/out/ivlremcfgodi.sh" "${TargetFolder}/psw/ivlremcfgodi.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "ivlremcfgodi.sh" $OdiTgtServer
fi

$ScpPutCommand ${OdiTgtServer} "${TmpTicketFolder}/psw/out/ivlremgroovy-ivl-generic.conf" "${TargetFolder}/groovy-ivl-generic.conf"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "ivlremgroovy-ivl-generic.conf" $OdiTgtServer
fi

LogLineDEBUG "Kopieren bestand cleanTemp.sh"

$ScpPutCommand ${OdiTgtServer} ${TmpCmd3File} "${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "cleanTemp.sh" $OdiTgtServer
fi

## Send additional files to odi.
### downloadedlist

LogLineDEBUG "Kopieren bestand deletedlist"

$ScpPutCommand ${OdiTgtServer} "${HandoverDeletedList}" "${TargetFolder}/TI${ArgTicketNr}-deleted.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDeletedList}" $OdiTgtServer
fi
### deletedlist
LogLineDEBUG "Kopieren bestand downloadedlist"

$ScpPutCommand ${OdiTgtServer} "${HandoverDownloadedList}" "${TargetFolder}/TI${ArgTicketNr}-downloaded.txt"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${HandoverDownloadedList}" $OdiTgtServer
fi


## Send all files towards the target odi-server.
LogLineDEBUG "Start sending all the required directories to the ${OdiTgtServer} for ticket ${ArgTicketNr}."

for folder  in $(find ${TmpTicketFolder}/*/ -maxdepth 0 -type d |grep -v "^.$"); do
  foldername=$(echo ${folder/$TmpTicketFolder/""})
  foldernameSingle=$(basename "$foldername" | cut -d. -f1)

  folderDest=$(echo ${foldername/$foldernameSingle/""})
  LogLineDEBUG "copying '${folder}' to '${TargetFolder}${folderDest}'"

  $ScpPutCommand ${OdiTgtServer} "${folder}" "${TargetFolder}${folderDest}"
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_ScpPutFailed "$folder" $OdiTgtServer
  fi
done
LogLineDEBUG "Finished creating all the required directory on ${OdiTgtServer} for ticket ${ArgTicketNr}."

LogLineDEBUG "Finished sending all the required files on ${OdiTgtServer} for ticket ${ArgTicketNr}."

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
LogLineINFO "Script" ${ScriptName}  "ended."
exit

