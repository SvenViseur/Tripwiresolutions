#!/bin/bash

ScriptName="svn_dl_plhdata.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"

Svn_set_options

mkdir -p /data/deploy-it/svn_configdata
cd /data/deploy-it/svn_configdata

svn info ${SvnOpts} https://scm/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/trunk/jenkins/deploy-it/cmdb_publish/Placeholders_DeployIt.csv
svn export --force ${SvnOpts} https://scm/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/trunk/jenkins/deploy-it/cmdb_publish/Placeholders_DeployIt.csv

