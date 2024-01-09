#!/bin/bash

ScriptName="svn_dl_vaultdata.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"

Svn_set_options

mkdir -p /data/deploy-it/svn_configdata
cd /data/deploy-it/svn_configdata

svn info ${SvnOpts} https://scm/deploymentAutomation/vaults/jboss_acc.psafe3

svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/jboss_acc.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/jboss_sim.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/jboss_val.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/jboss_sic.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/jboss_prd.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/sbp_acc.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/sbp_sim.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/sbp_val.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/sbp_sic.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/sbp_prd.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/ivl_acc.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/ivl_sim.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/ivl_val.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/ivl_sic.psafe3
svn export --force ${SvnOpts} https://scm/deploymentAutomation/vaults/ivl_prd.psafe3
