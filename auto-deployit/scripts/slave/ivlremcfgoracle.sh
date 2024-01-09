#### ivlremcfgoracle.sh script
# This script is to be source'd from a Jenkins AutoDeploy job.
#
# IMPORTANT! The code in this script will only run on TARGET IVL servers,
# not on DeployIT servers (depm/depp/deps).
#
# This script contains placeholders, and thus must pass the replace tool
# before being sent to the target machine.

echo "uitvoering gevraagd van ivlremcfgoracle.sh."

local OraUser="@@DEPLOYIT_IVL_ORACLE_USER#@"

local OraPsw="@@DEPLOYIT_IVL_ORACLE_PSW#@"

local OraSrv="@@DEPLOYIT_IVL_ORACLE_SERVER#@"

local SqlActive="@@DEPLOYIT_IVL_SQL_ACTIVE#@"
