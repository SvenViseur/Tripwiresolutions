#!/bin/bash

#### ivlprep.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# It will prepare the provided binaries from the oplevering-folder
# extract the tar-file, run a replace-tool call re-tar the binaries.
# And commit it to the svn repo.
#

# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# dexa  # Feb/2019    # 1.0.0 # Initial version
# dexa  # Jan/2020    # 1.0.1 # Correctie test on 2 files
# lekri # 12/11/2021  # 1.0.2 #ondersteuning ACC & SIM TraceIT/4me
#################################################################
ScriptName="ivlprep.sh"
ScriptVersion="1.0.2"
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

SshCommand="${SshScriptsFolder}/ssh_srv_taccdeps_key.sh"
ScpPutCommand="${SshScriptsFolder}/scp_srv_taccdeps_put.sh"
ScpGetCommand="${SshScriptsFolder}/scp_srv_toptoa_get.sh"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="ivl-prep"
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

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_UPD_TICKET ]; then
  echo "WARN: Predeploy fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

## output: $TheUsr $TheFld
GetEnvData
## Determine the target elements for this prep:
GetIvlInfo

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

## We will do some sanity controls on the contents of this ticket
## Check 1: only 1 file, and it must be a zip file
linecount=$(wc -l ${HandoverDownloadedList} | awk '{ print $1 }')
echo ">>${linecount}<<"
if [ $linecount -ne 1 ]; then
  echo "ERROR: Dit ticket mag slechts 1 file bevatten: de .zip file met de SQL code"
  exit 16
fi
grep -e ".zip" ${HandoverDownloadedList}
if [ $? -ne 0 ]; then
  echo "ERROR: Dit ticket moet 1 file bevatten: de .zip file met de SQL code"
  exit 16
fi

## unzip de file
cd ${TmpTicketFolder}/${firstpart}/${secondpart}
mkdir unzipped
cd unzipped
unzip ../*.zip
if [ $? -ne 0 ]; then
  echo "ERROR: De unzip operatie verliep niet goed. Mogelijks is de zip file beschadigd."
  exit 16
fi

## Check 2: in de .zip moet steeds een parameters folder zijn
if [ ! -d "parameters" ]; then
  echo "ERROR: De zip file bevat geen folder ""parameters"". Dit kan niet behandeld worden."
  exit 16
fi
cd parameters
## Check 3: in de parameters folder moet minstens een .properties file staan
ls *.properties 1> /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: De zip file bevat geen file "".properties"" in de parameters folder. Dit kan niet behandeld worden."
  exit 16
fi
## Check 4: in de parameters folder moet minstens een DDL of ODI execution order file staan. Als beide ontbreken, kunnen we niks deployen
if [ -f "ODI_execution_order.txt" ] || [ -f "DDL_execution_order.txt" ]; then
  echo "OK, execution order files gevonden"
else
  echo "ERROR: De zip file moet minstens een ODI_execution_order.txt of een DDL_execution_order.txt bevatten in de parameters folder. Dit kan niet behandeld worden."
  exit 16
fi

cd ..

if [ -f "parameters/DDL_execution_order.txt" ]; then
  ## Parse the execution order line by line
  while read -r line; do
  mainsql="sql/${line}/${line}_main_sql.sql"
  ##check 5: main_sql.sql moet bestaan
  if [ ! -f "$mainsql" ]; then
    echo "ERROR: in de DDL_execution_order.txt staat $line maar er is geen bijbehorende folder met een passende main_sql.sql."
    exit 16
  fi
  grep -i "whenever sqlerror" $mainsql
  if [ $? -ne 0 ]; then
    echo "ERROR: in de file $mainsql ontbreekt een clausule 'whenever sqlerror'."
    exit 16
  fi
  grep -i "whenever oserror" $mainsql
  if [ $? -ne 0 ]; then
    echo "ERROR: in de file $mainsql ontbreekt een clausule 'whenever oserror'."
    exit 16
  fi
  grep -i "^exit" $mainsql
  if [ $? -ne 0 ]; then
    echo "ERROR: in de file $mainsql ontbreekt een clausule 'exit'."
    exit 16
  fi
  done < "parameters/DDL_execution_order.txt"
fi

if [ -f "parameters/ODI_execution_order.txt" ]; then
  ## Parse the execution order line by line
  while read -r line; do
  odifolder="odi/${line}"
  ##check 6: main_sql.sql moet bestaan
  if [ ! -d "$odifolder" ]; then
    echo "ERROR: in de ODI_execution_order.txt staat $line maar er is geen bijbehorende folder."
    exit 16
  fi
  ls ${odifolder}/${line}.zip ${odifolder}/EXEC_${line}.zip ${odifolder}/LP_${line}.zip
  if [ ! -e "${odifolder}/${line}.zip" ] && [ ! -e "${odifolder}/EXEC_${line}.zip" ] && [ ! -e "${odifolder}/LP_${line}.zip" ]; then
    echo "ERROR: in de folder $odifolder moet minstens 1 van deze 3 files aanwezig zijn:"
    echo "${line}.zip EXEC_${line}.zip LP_${line}.zip"
    exit 16
  fi
  done < "parameters/ODI_execution_order.txt"
fi

cd ~

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
echo "Script" ${ScriptName}  "ended."
exit
