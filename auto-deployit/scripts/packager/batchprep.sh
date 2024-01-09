#!/bin/bash

#### batchprep.sh script
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
# dexa  # May/2020    # 1.0.0   # Clone from bofprep
# dexa  # May/2020    # 1.1.0   # Use replace on ini folder
# lekri # 12/11/2021  # 1.1.1   # ondersteuning ACC & SIM TraceIT/4me
#       #    /2020    #  . .    #
#################################################################

ScriptName="batchprep.sh"
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

############# Belangrijke opmerking
## In feb 2019 is het onduidelijk wat de zin is van deze
## code: enkel de /ini/template folder wordt omgezet (Replace)
## Maar in Oplevering/DVL/ hebben de ADCs nog geen
## ini/template folder. Er wordt dus niks geconverteerd.
## Het is dus maar de vraag of deze code werkt ...

## In mei 2020 werd de code van de bof, met bovenstaande
## opmerking die nog steeds geldig is, overgezet naar
## de code voor de batch server

## In Oktober 2020 is deze code uitgebreid om specifiek voor
## de ini/template folder een replace call te doen.
## Zie version change voor 1.1.0
## Dit is ook de eerste die de replace tool gebruikt in combi mode
## Eerste ADC die dit gebruikt is TAREDI_BATCH

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData

ActionType="batch-prep"
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


## Prepare for a Replace_Tool call in ini folder
RT_InFolder=${TmpTicketFolder}/${TheADC,,}/ini/template
RT_ScanFilter="*"
RT_OutFolder="${TmpTicketFolder}/ReplacedCombi"
mkdir -p $RT_OutFolder
RT_EncCombiMode=1
RT_Vault=${SvnConfigDataFolder}/jboss_${ThePswEnv,,}.psafe3
RT_VaultPSW=${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw
RT_EncPSW=${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw
RT_Env=$ArgEnv
RT_ADC=$ArgAppl
RT_Tmp=$TmpTicketFolder
RT_Dos2Unix=1
RT_TicketNr=${ArgTicketNr}
RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

Replace_Tool

OplFolder="${TheADC,,}/ini"
CurTS=$(date -Iseconds)
SvnPropValue="""TI=$ArgTicketNr;Host=$HOSTNAME;JenkinsID=$BUILD_NUMBER;TS=$CurTS"""

if [ $DeployIT_Stap_Doel -ge $DEPLOYIT_STAP_UPD_TICKET ]; then
  if [ ${DeployIT_Can_Update_Tickets} -eq 1 ]; then
    Svn_co

    # Move to the generated directory.
    cd "${TmpTicketFolder}/svnupd/ini"
    mkdir -p generated/${ArgEnv}
    cp --no-preserve=timestamps -a ${RT_OutFolder}/* generated/${ArgEnv}
    cd ${RT_OutFolder}
    find . -type f -exec svn propset "AutoDeploy" ${SvnPropValue} ${TmpTicketFolder}/svnupd/ini/generated/$ArgEnv/{} \;
    ## go back to the root of the svn checkout
    cd ${TmpTicketFolder}/svnupd/ini
    ## delete generated files for which the template file was deleted.
    grep "/template/" $HandoverDeletedList | cut -f2- > ${TmpTicketFolder}/deleted_templates.txt
    if [ -s ${HandoverDownloadedList} ];
      then
        OplFolderEsc=${OplFolder//\//\\\/}
        echo "OplFolder= $OplFolder"
        echo "OplFolderEsc= $OplFolderEsc"
        echo sed -i -- "s/${OplFolderEsc}\/template\//generated\/${ArgEnv}\//g" ${TmpTicketFolder}/deleted_templates.txt
        sed -i -- "s/${OplFolderEsc}\/template\//generated\/${ArgEnv}\//g" ${TmpTicketFolder}/deleted_templates.txt
        dos2unix ${TmpTicketFolder}/deleted_templates.txt
        while read fnameToDelete; do
          if [ -e "$fnameToDelete" ];
            then
              LogLineDEBUG "Delete requested for existing file $fnameToDelete"
              svn delete $fnameToDelete
              RC=$?
              if [ $RC -ne 0 ]; then
                echo "svn call with function delete failed. RC=$RC."
                exit 16
              fi
            else
              LogLineWARN "Delete requested for non-existing file $fnameToDelete"
            fi
        done < "${TmpTicketFolder}/deleted_templates.txt"
        ## restore previous IFS value
        # IFS=$oIFS
      fi
    cd "${TmpTicketFolder}/svnupd/ini"

    ## Call Svn_add en Svn_commit
    Svn_add
    Svn_commit
    Handover_RippleUp
  else
    LogLineINFO "Geen SVN of ticket updates uitgevoerd wegens Deploy-IT configuratiesettings."
  fi
else
  LogLineINFO "Geen SVN of ticket updates uitgevoerd wegens huidig deploy doel."
fi

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi
echo "Script" ${ScriptName}  "ended."
exit
