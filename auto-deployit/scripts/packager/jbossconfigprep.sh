#!/bin/bash

#### jbossconfigprep.sh script
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
#     DOEL		: Tot welk punt moet de deploy gebeuren
#     EXTRAOPTS		: Andere specifieke opties
#
#################################################################
# Change history
#################################################################
# dexa # dec/2015    # initial POC versie
# dexa # apr/2016    # move naar deploy-it ACC omgeving
#      #             # centraliseer functies in externe file
# dexa # jun/2016    # gebruik centrale Replace_Tool functie
#      #             #   en deployIT_Settings
# dexa # jul/2016    # gebruik DeployIT_Can_Update_Tickets en
#      #             # DeployIT_Can_Ssh_To_Appl_Servers
# dexa # sept/2016   # ArgDoel en bijbehorende processing
# dexa # sept/2016   # Toev check ArgAppl vs DerivedADC
# dexa # 07/10/2016  # call MaakTmpTicketFolder en CleanTmpFolder
# dexa # 07/10/2016  # verwijdering diffs (ONDERSTEUN-977)
# dexa # 22/12/2016  # ONDERSTEUN-1068: propset
# dexa # 06/01/2017  # ONDERSTEUN-1070: delete
# dexa # 30/05/2017  # ONDERSTEUN-1302: delete only mogelijk
# dexa # 07/07/2017  # ONDERSTEUN-1529: log van replace schrijven
# dexa # 09/08/2018  # call Parse_ExtraOptsSvnTraceIT
# lekri # 12/11/2021 # ondersteuning ACC & SIM TraceIT/4me
#      #             #
#      #             #
#################################################################
#

ScriptName="jbossconfigprep.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3
ArgDoel=$4
ArgExtraOpts=$5

LogLineINFO "Script ${ScriptName} started."
LogLineINFO "Options are:"
LogLineINFO "  APPL = '${ArgAppl}'"
LogLineINFO "  TICKETNR = '${ArgTicketNr}'"
LogLineINFO "  ENV = '${ArgEnv}'"
LogLineINFO "  DOEL = '${ArgDoel}'"

SshCommand="/data/deploy-it/scripts/ssh/ssh_srv_toptoa.sh"
ScpPutCommand="/data/deploy-it/scripts/ssh/scp_srv_toptoa_put.sh"
ScpGetCommand="/data/deploy-it/scripts/ssh/scp_srv_toptoa_get.sh"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData
ActionType="config-prep"
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

## Download ticket materiaal
Handover_Download_Local

# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

# Check the contents of the deleted and downloaded files
# Test 1: ensure deleted.txt AND downloaded.txt are NOT BOTH empty
if [ ! -s ${HandoverDownloadedList} ]; then
  if [ ! -s ${HandoverDeletedList} ]; then
    echo "ERROR: Ticket bevat geen data files (geen nieuwe, gewijzigde of verwijderde files). DeployIT kan dus niets doen."
    exit 16
  fi
  ## Als we dit punt bereiken, dan is er GEEN downloaded file maar wel deleted files.
  ## Dus heeft het geen zin om een replace tool op te starten.
  echo "Script" ${ScriptName}  "ended (no downloadable files to process here)."
  exit 0
fi

HODL_parse

if [ "$TheTicketType" != "config" ]; then
  echo "ERROR: This ticket is not a JBoss type config ticket. The files attached to the ticket do not match the expected "
  echo "folder location. Deployment will stop here."
  exit 16
fi

DerivedADC=${TheTicketADCfolder^^}
## Compare the requested ADC with the one derived from the HODL file
if [ "$ArgAppl" = "$DerivedADC" ]; then
  LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
else
  echo "ERROR: Dit ticket bevat files die, op basis van hun locatie, niet tot deze ADC behoren. Deploy kan niet verdergaan."
  echo "Deploy voor ADC=${ArgAppl}. Files in ticket zouden zijn voor ADC=${DerivedADC}."
  exit 16
fi

## Now test ALL records of downloaded.txt to match against this:
## OK<tab>config/<adc-folder>/template/...
## OK<tab>config/<adc-folder>/generated/...
if [ $(grep -v -E "config/${TheTicketADCfolder}/(template|generated)" ${HandoverDownloadedList} | wc -l) -ne 0 ];
then
  LogLineWARN "Ticket contains download files outside the expected folder which is: config/${TheTicketADCfolder}/template or"
  LogLineWARN "   config/${TheTicketADCfolder}/generated"
  LogLineWARN "Only the files in the template path will be processed. Other files can serve as comparison."
fi

## Prepare for a Replace_Tool call
RT_InFolder=${TmpTicketFolder}/config/${TheTicketADCfolder}/template
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

OplFolder="config/${TheTicketADCfolder}"
CurTS=$(date -Iseconds)
SvnPropValue="""TI=$ArgTicketNr;Host=$HOSTNAME;JenkinsID=$BUILD_NUMBER;TS=$CurTS"""

if [ $DeployIT_Stap_Doel -ge $DEPLOYIT_STAP_UPD_TICKET ]; then

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


    ## Call Svn_add en Svn_commit
    Svn_add

    Svn_commit

    ## call Ripple up
    Handover_RippleUp
  else
    LogLineINFO "Geen SVN of ticket updates uitgevoerd wegens Deploy-IT configuratiesettings."
  fi
else
  LogLineINFO "Geen SVN of ticket updates uitgevoerd wegens huidig deploy doel."
fi

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
