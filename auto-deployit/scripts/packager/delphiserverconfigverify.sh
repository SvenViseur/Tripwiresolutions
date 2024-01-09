#!/bin/bash

#### delphiserverconfigverify.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the verify process of an ADC for an
# environment: the latest source files are generated to
# environment specific versions (for the chosen environment)
# and any errors or issues (e.g. missing placeholder values)
# are reported.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# dexa     # Sept/2019    # initial version
#################################################################
#

ScriptName="delphiserverconfigverify.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

DebugLevel=3
ArgAppl=$1
ArgEnv=$2

LogLineINFO "Script" ${ScriptName}  "started."
LogLineINFO "Options are:"
LogLineINFO "  APPL = '${ArgAppl}'"
LogLineINFO "  ENV = '${ArgEnv}'"

## GetEnvData:
##     input variables  : $ArgEnv
##     input files      : ENV2BOFOPL.csv
GetEnvData
##     output variables : $TheBof, $TheOpl (The BOF server and the Oplevering_XXX folder to use)
##                        $ThePswEnv (The password environment: AC5 -> ACC)

TmpFld="${WORKSPACE}/tmp"
TheEnv=$ArgEnv
TheADC=$ArgAppl
## Get default settings based on the ENV and ADC
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level
Replace_Tool_Defaults
EchoDeployITSettings


## Prepare for a Replace_Tool call for config files
RT_InFolder="${WORKSPACE}/config-template"
RT_ScanFilter="*"
RT_OutFolder="${WORKSPACE}/config-replaced"
mkdir -p $RT_OutFolder
RT_OutFolderEnc=""
RT_Env=$ArgEnv
RT_ADC=$ArgAppl
RT_Tmp="${WORKSPACE}/tmp"
mkdir -p $RT_Tmp
RT_Dos2Unix=1

Replace_Tool

ActionType="config-verify"
MaakTmpApplEnvFolder
cd ${TmpApplEnvFolder}


## Prepare for a Replace_Tool call for password files
RT_InFolder="${WORKSPACE}/password-template"
RT_ScanFilter="*"
RT_OutFolder=${TmpApplEnvFolder}/ReplacedPub
mkdir -p $RT_OutFolder
RT_OutFolderEnc=${TmpApplEnvFolder}/ReplacedSecret
mkdir -p $RT_OutFolderEnc
RT_Env=$ArgEnv
RT_ADC=$ArgAppl
RT_Tmp="${WORKSPACE}/tmp"
## password vault file gebruikt lowercase env, dus acc of sim of prd
RT_Vault=${SvnConfigDataFolder}/delphiserver_${ThePswEnv,,}.psafe3
RT_VaultPSW=${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw
RT_Enc_SKIP=1
RT_EncPSW="Not_used"

Replace_Tool

#delete password files, mogen niet bewaard worden voor verify
rm -rf $RT_OutFolder
rm -rf $RT_OutFolderEnc
TmpFolder=${TmpApplEnvFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
