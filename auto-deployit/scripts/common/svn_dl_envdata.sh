#!/bin/bash

ScriptName="svn_dl_envdata.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"

ArgEnv=${1:-"PRD"}

LogLineINFO "Script" ${ScriptName}  "started."
LogLineINFO "Options are:"
LogLineINFO "  ENV = '${ArgEnv}'"

Svn_set_options

mkdir -p /data/deploy-it/svn_configdata
cd /data/deploy-it/svn_configdata

SvnBasePathCSV="https://scm/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/trunk/jenkins/deploy-it/cmdb_publish"
if [[ "${ArgEnv}" == "ACC" ]]; then
  SvnBasePathCSV="https://scm/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/branches/acc/jenkins/deploy-it/cmdb_publish"
fi

LogLineINFO "Refreshing environment data from ${SvnBasePathCSV}"

svn info ${SvnOpts} ${SvnBasePathCsv}

svn export --force ${SvnOpts} "${SvnBasePathCSV}/ADC2CNTUSRDIR.csv"
svn export --force ${SvnOpts} "${SvnBasePathCSV}/ADC2CNTUSRDIR_MAN.csv"
svn export --force ${SvnOpts} "${SvnBasePathCSV}/ADCENV2SRV.csv"
svn export --force ${SvnOpts} "${SvnBasePathCSV}/ADCENV2SRV_MAN.csv"
svn export --force ${SvnOpts} "${SvnBasePathCSV}/ENV2DEPLSETTINGS.csv"
svn export --force ${SvnOpts} "${SvnBasePathCSV}/SANITYCHECKS.csv"
svn export --force ${SvnOpts} "${SvnBasePathCSV}/OPERBEHEERACTIES_STATIC.csv"
svn export --force ${SvnOpts} "${SvnBasePathCSV}/IVL2BATCH.csv"
svn export --force ${SvnOpts} https://scm/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/trunk/jenkins/deploy-it/releases.csv
svn export --force ${SvnOpts} https://scm/argenta/projecten/ontwikkelstraat.tools/be.argenta.srvinstall/trunk/jenkins/deploy-it/ADC2BOFUSRDIR.csv
