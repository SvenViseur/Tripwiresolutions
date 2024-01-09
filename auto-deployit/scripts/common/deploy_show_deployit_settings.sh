#!/bin/bash


# Command line options:
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

ScriptName="deploy_show_deployit_settings.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

TmpFld="/tmp/deploy-it/show_deployit_settings"
TheEnv=$1
TheADC="\"***\""

GetDeployITSettings

EchoDeployITSettings

ArgEnv=$1
GetEnvData

EchoEnvData

exit 0

