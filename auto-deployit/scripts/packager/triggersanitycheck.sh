#!/bin/bash

#### trigger the sanity check process on the Jenkins of the Testing team
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     ENV               : The target environment
#     URL               : The URL that should be called
#
#################################################################
# Change history
#################################################################
# dexa # apr/2017    # initial version
#      #             #
#################################################################

ScriptName="triggersanitycheck.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"

ArgEnv=$1
ArgURL=$2

echo "Sanity check request voor omgeving $ArgEnv"

## Inlezen van Svn credentials
source ${ConfigDataFolder}/credentials/svn.password.properties
## Samenstellen van alle Svn opties
URLCredentials=" -u ${SvnUsername}:${SvnPassword} "

curl -X POST $URLCredentials ${ArgURL}/build?delay=0sec

echo "De job output kan bekeken worden via deze URL: ${ArgURL}"

