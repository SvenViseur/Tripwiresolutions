#!/bin/bash

#### autactprep.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the generation of environment specific
# files for any jboss config type ticket.
# It generates one file for each template file in the ticket.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     EXTRAOPTS		: Andere specifieke opties
#
#################################################################
# Change history
#################################################################
# dexa # jul/2020    # initiele versie
#      #             #
#      #             #
#################################################################
#

ScriptName="autactprep.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3
ArgExtraOpts=$4

LogLineINFO "Script ${ScriptName} started."
LogLineINFO "Options are:"
LogLineINFO "  APPL = '${ArgAppl}'"
LogLineINFO "  TICKETNR = '${ArgTicketNr}'"
LogLineINFO "  ENV = '${ArgEnv}'"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData
ActionType="autact-prep"
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

## Download ticket materiaal
Handover_Download_Local

# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

# Check the contents of the deleted and downloaded files
# Test 1: ensure deleted.txt is empty
if [ -s ${HandoverDeletedList} ]; then
  echo "ERROR: Ticket bevat deleted files. Dat is niet toegelaten voor deze ADC. DeployIT kan dus niets doen."
  exit 16
fi

# Test 2: ensure downloaded.txt in NOT empty
if [ ! -s ${HandoverDownloadedList} ]; then
  echo "ERROR: Ticket bevat geen files. DeployIT kan dus niets doen."
  exit 16
fi

# Check folder location vs. the ADC
line1=$(head -n 1 ${HandoverDownloadedList})
RC=$?
if [ $RC -ne 0 ]; then
  echo "call to head command failed. RC=$RC."
  exit 16
fi
if [ "${line1}" = "" ]; then
  echo "HODL_parse error: file is leeg. Oorzaak is waarschijnlijk dat er geen files aan"
  echo "ticket hangen."
  exit 16
fi
LogLineDEBUG "line1 = ${line1}"
## expected format: OK      config/<adc-folder>/...
##             of : OK      password/<adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
LogLineDEBUG "line1 (stripped) = ${line1}"
firstpart=${line1%%"/"*}
restpart=${line1:${#firstpart}+1}
TheTicketADCfolder=$firstpart

DerivedADC=${firstpart^^}
## Compare the requested ADC with the one derived from the HODL file
if [ "$ArgAppl" = "$DerivedADC" ]; then
  LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
else
  echo "ERROR: Dit ticket bevat files die, op basis van hun locatie, niet tot deze ADC behoren. Deploy kan niet verdergaan."
  echo "Deploy voor ADC=${ArgAppl}. Files in ticket zouden zijn voor ADC=${DerivedADC}."
  exit 16
fi

## Now test ALL records of downloaded.txt to match against this:
## OK<tab><adc-folder>/template/...
## OK<tab><adc-folder>/generated/...
if [ $(grep -v -E "${TheTicketADCfolder}/(template|generated)" ${HandoverDownloadedList} | wc -l) -ne 0 ];
then
  LogLineWARN "Ticket contains download files outside the expected folder which is: ${TheTicketADCfolder}/template or"
  LogLineWARN "   ${TheTicketADCfolder}/generated"
  LogLineWARN "Only the files in the template path will be processed. Other files can be used without processing from the replace tool."
fi

## Prepare for a Replace_Tool call
RT_InFolder=${TmpTicketFolder}/${TheTicketADCfolder}/template
RT_ScanFilter="*"
RT_OutFolder=${TmpTicketFolder}/ReplacedPub
mkdir -p $RT_OutFolder
RT_OutFolderEnc=""
RT_Env=$ArgEnv
RT_ADC=$ArgAppl
RT_Tmp=$TmpTicketFolder
RT_Dos2Unix=1
RT_TicketNr=${ArgTicketNr}
RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

Replace_Tool

## Voorbereiding Upload naar het ticket

OplFolder="${TheTicketADCfolder}"
CurTS=$(date -Iseconds)
SvnPropValue="""TI=$ArgTicketNr;Host=$HOSTNAME;JenkinsID=$BUILD_NUMBER;TS=$CurTS"""

if [ ${DeployIT_Can_Update_Tickets} -eq 1 ]; then

    ## Svn_co:
    ## Input:
    ## TmpTicketFolder
    ## TheOpl             (de Opleverings-root-folder, bekomen via GetEnvData()  )
    ## OplFolder          (de opleverings-subfolder, meestal config/$EnvAppl of password/$EnvAppl  )
    Svn_co
    ## Output:
    ## svn folder structure under $TmpTicketFolder/svnupd

    ## replace de gegenereerde files

    cd ${TmpTicketFolder}/svnupd/${TheTicketADCfolder}
    mkdir -p generated/${ArgEnv}
    cp --no-preserve=timestamps -a $RT_OutFolder/* generated/${ArgEnv}/.
    ## iterate over all generated files, and do a propset for the copied files
    cd $RT_OutFolder
    find . -type f -exec svn propset "AutoDeploy" ${SvnPropValue} ${TmpTicketFolder}/svnupd/${TheTicketADCfolder}/generated/$ArgEnv/{} \;
    ## go back to the root of the svn checkout
    cd ${TmpTicketFolder}/svnupd/${TheTicketADCfolder}
    pwd

    ## Call Svn_add en Svn_commit
    Svn_add

    Svn_commit

    ## call Ripple up
    Handover_RippleUp
  else
    LogLineINFO "Geen SVN of ticket updates uitgevoerd wegens Deploy-IT configuratiesettings."
fi

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
