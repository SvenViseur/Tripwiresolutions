#!/bin/bash

#### generateReleaseCsv.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
#
#################################################################
# Change history
#################################################################
# vevi     # Sep/2018    # 1.0-0 initial POC versie
#################################################################

ScriptName="generateReleaseCsv.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"



BulkActionsRootFolder="/data/deploy-it/bulk-actions"
echo "Generating CSV from releases in TraceIT"
Svn_set_options
echo "Updating releases.csv from SVN"
cd "${BulkActionsRootFolder}"
mkdir tmp
cd tmp
## We just need one file, releases.csv so no need to download the whole deploy-it folder
svn ${SvnOpts} co https://${DeployIT_SVN_server}/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/trunk/jenkins/deploy-it  --depth files
cd deploy-it
echo "Generating new CSV"

unformatted_releases=$(java -cp /data/deploy-it/bin/handover-tool-app.jar -DHOT_ENV=prd be.argenta.handover.export.Releases -c /data/deploy-it/configdata/credentials/handover-tool_settings.conf)
echo "**UNFORMATTED**"
echo "${unformatted_releases}"
formatted_releases=$(echo $unformatted_releases | sed 's/;/|/g')
formatted_releases=$(echo $formatted_releases | sed 's/| /\n/g')

echo """

**FORMATTED**"""
echo "${formatted_releases}"

 echo "${formatted_releases}" > "${BulkActionsRootFolder}/tmp/deploy-it/releases.csv"
echo "Commiting new file to SVN"
svn ${SvnOpts} commit "${BulkActionsRootFolder}/tmp/deploy-it" -m "Auto update releases.csv"
cd "${BulkActionsRootFolder}"
rm -rf tmp

