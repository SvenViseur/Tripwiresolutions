#!/bin/bash

#### iwspackageinst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     DOEL		: To which point the deploy shoud go
#
#################################################################
# Change history
#################################################################
# dexa # jul/2018    # allow multiple package files to be
#      #             # processed sequentially (alphabetical seq)
# dexa # mar/2019    #   1.1.0 # increase retry count to 20 x
#      #             #         # 15 sec as IWS wakes up every
#      #             #         # 2 minutes only.
#      #             #         # Add scriptVersion info
# lekri # 12/11/2021 # 1.1.1   # ondersteuning ACC & SIM TraceIT/4me
#      #             #         #
#################################################################
#

ScriptName="iwspackageinst.sh"
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

echo "Script" ${ScriptName}  "started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"
echo "  DOEL = '${ArgDoel}'"

## GetEnvData:
##     input variables  : $ArgEnv
GetEnvData

ActionType="iwspackage-inst"
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

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_ACTIVATE ]; then
  echo "WARN: Activatie fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

## Compare the requested ADC with the one derived from the HODL file
if [ "$ArgAppl" = "IWS_job_scheduler_packages" ]; then
  LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
else
  echo "ERROR: Dit script werd opgeroepen voor een ADC type dat niet past bij dit script."
  echo "Deploy voor ADC=${ArgAppl}. Script is enkel voorzien voor ADC=\"IWS_job_scheduler_packages\"."
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
# Test 1: ensure deleted.txt is empty
if [ -s ${HandoverDeletedList} ]; then
  echo "ERROR: Ticket contains file deletions. This is currently NOT supported."
  exit 16
fi
# Test 2: ensure downloaded.txt is NOT empty
if [ ! -s ${HandoverDownloadedList} ]; then
  echo "ERROR: Ticket contains no downloadable files, so there is nothing to deploy."
  exit 16
fi
# Test 3: ensure downloaded.txt only contains lines with "iws_job_scheduler_packages/"
if [ $(grep -v "iws_job_scheduler_packages/" ${HandoverDownloadedList} | wc -l) -ne 0 ]; then
  echo "ERROR: Ticket contains download files outside the 'iws_job_scheduler_packages/' folder. This is not supported for this type of applications."
  exit 16
fi

echo "*** $DEPLOYIT_IWS_MOUNT_POINT ***"

ToInstallSubfolder="${TmpTicketFolder}/iws_job_scheduler_packages/*"
TargetFolderBase=${DEPLOYIT_IWS_MOUNT_POINT}

echo "listing tar.gz files in the install set"
ls -l ${ToInstallSubfolder}.tar.gz
echo "end of ls"

echo "dump tar.gz contents list:"
for f in $ToInstallSubfolder
do
  echo "contents of package file $f ..."
  tar -tvzf $f
done
echo "end of tar.gz index dump"

echo "Attempting to copy files to ${TargetFolderBase}/packages"
echo "List of files that will be copied:"
ls -lR $ToInstallSubfolder
echo "End of list of files that will be copied."

## Prepare to deposit files
TargetFolder="${TargetFolderBase}/packages/"
LogFolder="${TargetFolderBase}/logging/"

for f in $ToInstallSubfolder
do
  echo "installing package $f ..."
  cd $LogFolder
  ls -1X > ${TmpTicketFolder}/ls_initial.txt

  ## reset the timer
  SECONDS=0

  ## copy the tar.gz files from $ToInstallSubfolder to the TargetFolder
  cp -r $f ${TargetFolder}
  RC=$?
  if [ $RC -ne 0 ]; then
    deploy_error $DPLERR_IWSCopyFailed $f $TargetFolder
  fi

  ## list the logging folder
  cd $LogFolder
  LoopEnded=0
  LoopCounter=0
  OutputFile=""
  while [ $LoopEnded -eq 0 ]; do
    ## allow the IWS system to process the file
    sleep 15

    ls -1X > ${TmpTicketFolder}/ls_after.txt
    diff ${TmpTicketFolder}/ls_initial.txt ${TmpTicketFolder}/ls_after.txt > ${TmpTicketFolder}/ls_diff.txt
    RC=$?
    if [ $RC -ne 0 ]; then
      ## We have a difference
      OutputFile=$(grep ">" ${TmpTicketFolder}/ls_diff.txt | awk '{printf("%s", $2)}')
      echo $OutputFile
      extension="${OutputFile##*.}"
      if [ "$extension" = "TMP" ]; then
        ## We have a TMP file, not finished yet
        echo "IWS upload processing is still active, for $SECONDS seconds now."
      fi
      if [ "$extension" = "OK" ]; then
        ## We have an OK result
        IWSResult="OK"
        LoopEnded=1
      fi
      if [ "$extension" = "NOK" ]; then
        ## We have a failure result
        IWSResult="NOK"
        LoopEnded=1
      fi
    else
      echo "IWS upload waiting for an output file, for $SECONDS seconds now."
    fi
    let LoopCounter=LoopCounter+1
    if [ $LoopCounter -gt 20 ]; then
      ## We have a time-out result
      IWSResult="TO"
      LoopEnded=1
    fi
  done

  if [ "$IWSResult" = "OK" ]; then
    echo "The IWS changes were processed successfully. The output is listed below."
    cat $OutputFile
  fi

  if [ "$IWSResult" = "NOK" ]; then
    echo "The IWS changes have failed. The output is listed below."
    cat $OutputFile
    deploy_error $DPLERR_IWSApplyFailed
  fi

  if [ "$IWSResult" = "TO" ]; then
    echo "The IWS changes have taken too long to process. If possible, a partial output is listed below."
    cat $OutputFile
    echo "Please contact the IWS expert team or raise a ticket with Cegeka for analysis."
    deploy_error $DPLERR_IWSApplyTimeout
  fi

  echo "end of installation for package $f"
done ## end of processing for this file, now treat the next one


## find . -mmin -5 -type f -name "CHG_*.tar.gz_${ArgEnv}_*" -print
## find . -mmin -5 -type f -name "CHG_*.tar.gz_${ArgEnv}_*" -exec cat {}


cd ${TmpTicketFolder}
cd ..

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi

echo "Script" ${ScriptName}  "ended."
