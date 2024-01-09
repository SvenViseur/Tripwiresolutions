#!/bin/bash
#### bofconfigprep.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     DOEL		: The StapDoel that determines up to
#			     what point the deploy process
#			     should go
#
#################################################################
# Change history
#################################################################
# jaden     # 18/08/2018    # 1.0-0 initial POC versie
# lekri     # 12/11/2021    # ondersteuning ACC & SIM TraceIT/4me
#################################################################
ScriptName="bofconfigprep.sh"
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
LogLineINFO "  EXTRA OPTIES = '${ArgExtraOpts}'"


## Call GetEnvData
GetEnvData

SshCommand="${SshScriptsFolder}/ssh_srv_taccdeps_key.sh"
ScpPutCommand="${SshScriptsFolder}/scp_srv_taccdeps_put.sh"
ScpGetCommand="${SshScriptsFolder}/scp_srv_toptoa_get.sh"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="bof-config-prep"
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

if [[ ${TheTicketType} != "config" ]]; then
  echo "Error: This ticket is not a bof-config-type. The files attached to the ticket do not match the expected "
  echo "folder location. Deployment will stop here."
  exit 16  
fi

# Save the ADC with capitals.
DerivedADC=${firstpart^^}
## Compare the requested ADC with the one derived from the HODL file
if [[ "$ArgAppl" = "$DerivedADC" ]]; then
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

#Prepare for replace tool call
RT_InFolder=${TmpTicketFolder}/config/${TheTicketADCfolder}/template
mkdir -p ${RT_InFolder}
RT_ScanFilter="*"
RT_OutFolder=${TmpTicketFolder}/ReplacedPub
mkdir -p $RT_OutFolder
RT_OutFolderEnc=""
RT_Env=$ArgEnv
RT_ADC=$TheADC
RT_Tmp=$TmpTicketFolder
RT_Enc_SKIP=1
RT_Dos2Unix=1
RT_TicketNr=${ArgTicketNr}
RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

Replace_Tool

## Voorbereiding upload naar svn.
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
