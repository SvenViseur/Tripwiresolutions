#!/bin/bash

####### jbosspasswordverify.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script is currently not used: the jbossconfigverify.sh
# script also does the verify for the passwords.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
#      #             #
#      #             #
#      #             #
#################################################################
#

ScriptName="jbosspasswordverify.sh"
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

## Prepare for a Replace_Tool call
RT_InFolder="${WORKSPACE}/template"
RT_ScanFilter="*"
RT_OutFolder="${WORKSPACE}/ReplacedPub"
mkdir -p $RT_OutFolder
RT_OutFolderEnc="${WORKSPACE}/ReplacedEnc"
mkdir -p $RT_OutFolderEnc
RT_Env=$ArgEnv
RT_ADC=$ArgAppl
RT_Tmp="${WORKSPACE}/tmp"
mkdir -p $RT_Tmp
RT_Dos2Unix=1
## password vault file gebruikt lowercase env, dus acc of sim of prd
RT_Vault=${SvnConfigDataFolder}/jboss_${ThePswEnv,,}.psafe3
RT_VaultPSW=${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw
RT_EncPSW=${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw

Replace_Tool

## Vernietigen temp files
rm -rf $RT_Tmp

## De verify heeft niet tot doel om de paswoorden te gebruiken.
## Dus kunnen we die files beter weggooien.
rm -rf $RT_OutFolderEnc

echo "Script" ${ScriptName}  "ended."
