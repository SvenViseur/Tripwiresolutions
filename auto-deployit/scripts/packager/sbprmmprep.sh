#!/bin/bash

#### sbprmmprep.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script can only work for tickets of the ADC
# "SBP Deploy Tools". It reads the template files and generates
# the related environment specific files. It only serves to
# substitute passwords.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# dexa  # 16/06/2017  # Add option RT_HiddenFiles for ticket
#       #             #    ONDERSTEUN-1502
# dexa  # 07/07/2017  # ONDERSTEUN-1529: log van replace schrijven
# lekri # 02/06/2021  # SSGT-65: openssl key hashing -> sha256
#       #             #
#################################################################
#

ScriptName="sbprmmprep.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

DebugLevel=3
ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3

echo "Script" ${ScriptName}  "started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"

TmpTicketFolder="/data/deploy-it/tmp/sbp/T${ArgTicketNr}"

GetEnvData
##     output variables : $TheBof, $TheOpl (The BOF server and the Oplevering_XXX folder to use)
##                        $ThePswEnv (The password environment: AC5 -> ACC)


## Clean up local traces of previous runs of this same ticket
rm -rf ${TmpTicketFolder}
mkdir -p  ${TmpTicketFolder}
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

Handover_Download_Local

# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

# first filter the downloaded.txt file for these files
# deployinfo files
# info files that go with tar.gz files
# previously generated and uploaded environment specific files
FilterStrings="deployinfo
gz.info
.pdf
generated
opleverinstructies
DeploymentTools.ACC
DeploymentTools.SIM
DeploymentTools.PRD"
grep -v -F "${FilterStrings}" ${HandoverDownloadedList} > ${TmpTicketFolder}/handover-downloaded-filtered.txt

# Test 2: ensure downloaded.txt is NOT empty
if [ ! -s ${TmpTicketFolder}/handover-downloaded-filtered.txt ];
then
  echo "ERROR: Ticket contains no downloadable files, so there is nothing to deploy."
  exit 16
fi
# Test 3: ensure downloaded.txt only contains lines for config.PLACEHOLDERS
if [ $(grep -v SBPDeploymentTools.PLACEHOLDERS ${TmpTicketFolder}/handover-downloaded-filtered.txt | wc -l) -ne 0 ];
then
  echo "ERROR: Ticket contains other files than SBPDeploymentTools.PLACEHOLDERS file. This is not supported for SBP Deploy Tools type applications."
  exit 16
fi

### Vind de sbp_environment value

mkdir "${TmpTicketFolder}/TmpPlh"
cd "${TmpTicketFolder}/TmpPlh"
TmpPlhFile="${TmpTicketFolder}/TmpPlh/File.txt"
cat >${TmpPlhFile} << EOL
@@sbp_environment#@
EOL

## Prepare for a Replace_Tool call
RT_InFolder=${TmpTicketFolder}/TmpPlh
RT_ScanFilter="*"
RT_OutFolder=${TmpTicketFolder}/TmpPlhRepl
mkdir -p $RT_OutFolder
RT_OutFolderEnc=""
RT_Env=$ArgEnv
RT_ADC="SBP"
RT_Tmp=$TmpTicketFolder
RT_Dos2Unix=1

Replace_Tool

TheSbpEnv=$(cat ${TmpTicketFolder}/TmpPlhRepl/File.txt)
echo "SBP omgevingsnaam is: $TheSbpEnv"

##### SBP specific processing: untar the file #######

TmpUntar=${TmpTicketFolder}/tar

mkdir ${TmpUntar}
cd ${TmpUntar}
tar -xzf ${TmpTicketFolder}/sbp_deploy_tools/SBPDeploymentTools.PLACEHOLDERS.tar.gz
RC=$?
if [ $RC -ne 0 ]; then
  echo "tar command to extract the file SBPDeploymentTools.PLACEHOLDERS.tar.gz failed."
  exit 16
fi

### process the "project" folder: only keep the subfolder that matches $TheSbpEnv
cd ${TmpUntar}


mv "project/${TheSbpEnv}" "project_to_keep"
RC=$?
if [ $RC -ne 0 ]; then
  echo "mv command to select one project folder has failed. Probably the tar.gz file does not have the right structure."
  exit 16
fi
rm -rf project/*
### Now run a replace run on that resulting folder
## Prepare for a Replace_Tool call
RT_InFolder="${TmpUntar}/project_to_keep"
RT_ScanFilter="*"
RT_OutFolder="${TmpUntar}/project_to_keep_pub"
mkdir -p $RT_OutFolder
RT_OutFolderEnc="${TmpUntar}/project_to_keep_repl"
mkdir ${RT_OutFolderEnc}
RT_Env=$ArgEnv
RT_ADC="SBP"
RT_Tmp=$TmpTicketFolder
RT_Dos2Unix=1
RT_Vault="${SvnConfigDataFolder}/sbp_${ThePswEnv,,}.psafe3"
RT_VaultPSW="${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw"
RT_EncPSW="NOT_USED"
RT_Enc_SKIP=1
RT_KeepCHMOD=1
RT_HiddenFiles=1
RT_TicketNr=${ArgTicketNr}
RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

Replace_Tool
### remove the project_to_keep and project_to_keep_pub folder
rm -rf "${TmpUntar}/project_to_keep"
rm -rf "${TmpUntar}/project_to_keep_pub"
### put the output folder back in the correct location
mv "project_to_keep_repl" "project/${TheSbpEnv}"

### process the "scmflattening/project" folder: only keep the subfolder that matches $TheSbpEnv
cd ${TmpUntar}
mv "scmflattening/project/${TheSbpEnv}" "project_to_keep"
rm -rf scmflattening/project/*
### Now run a replace run on that resulting folder
RT_InFolder="${TmpUntar}/project_to_keep"
RT_ScanFilter="*"
RT_OutFolder="${TmpUntar}/project_to_keep_pub"
mkdir -p $RT_OutFolder
RT_OutFolderEnc="${TmpUntar}/project_to_keep_repl"
mkdir ${RT_OutFolderEnc}
RT_Env=$ArgEnv
RT_ADC="SBP"
RT_Tmp=$TmpTicketFolder
RT_Dos2Unix=1
RT_Vault="${SvnConfigDataFolder}/sbp_${ThePswEnv,,}.psafe3"
RT_VaultPSW="${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw"
RT_EncPSW="NOT_USED"
RT_Enc_SKIP=1
RT_KeepCHMOD=1
RT_HiddenFiles=1
RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

Replace_Tool
### remove the project_to_keep and project_to_keep_pub folder
rm -rf "${TmpUntar}/project_to_keep"
rm -rf "${TmpUntar}/project_to_keep_pub"
### put the output folder back in the correct location
mv "project_to_keep_repl" "scmflattening/project/${TheSbpEnv}"

### both project folders have been processed.

### make the output tar.gz file

  cd ${TmpTicketFolder}
  cd tar
  tar -czf ../SBPDeploymentTools.${ArgEnv}.Secret.tar.gz *
  cd ..
  openssl enc -in SBPDeploymentTools.${ArgEnv}.Secret.tar.gz -out SBPDeploymentTools.${ArgEnv}.Secret.tar.gz.enc -aes256 -md sha256 -pass file:${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw
  echo "Geheime versie van output tar.gz file gemaakt."

### uploaden naar SVN

Svn_set_options
OplFolder="sbp_deploy_tools"
Svn_co

cd sbp_deploy_tools
mkdir -p generated
cd generated

# Replace the Public and Private files

cp ../../../SBPDeploymentTools.${ArgEnv}.Secret.tar.gz.enc .
cd ..

Svn_add

svn status

# Commit de wijzigingen

Svn_commit

# Handover tool oproepen voor Ripple up

Handover_RippleUp

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi

echo "Script" ${ScriptName}  "ended."
