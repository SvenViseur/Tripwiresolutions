#### ivlremcfgodi.sh script
# This script is to be source'd from a Jenkins AutoDeploy job.
#
# IMPORTANT! The code in this script will only run on TARGET IVL servers,
# not on DeployIT servers (depm/depp/deps).
#
# This script contains placeholders, and thus must pass the replace tool
# before being sent to the target machine.

echo "uitvoering gevraagd van ivlremcfgodi.sh."

OdiProject="@@DEPLOYIT_IVL_ODI_PROJECT#@"
CheckEnvDown="@@DEPLOYIT_IVL_CHECK_ENV_DOWN#@"

## Logging database
OdiLogDbUrl="@@DEPLOYIT_IVL_RMC_DB_URL#@"
OdiLogDbUser="@@DEPLOYIT_IVL_RMC_DB_USER#@"
OdiLogDbPsw="@@DEPLOYIT_IVL_RMC_DB_PSW#@"


## Gedeelte RT
OdiRTActive="@@DEPLOYIT_IVL_ODI_RT_ACTIVE#@"
OdiRTDeployUser="@@DEPLOYIT_IVL_ODI_RT_DEPLOY_USER#@"
OdiRTDeployPsw="@@DEPLOYIT_IVL_ODI_RT_DEPLOY_PSW#@"
OdiRTMasterUser="@@DEPLOYIT_IVL_ODI_RT_MASTER_USER#@"
OdiRTMasterPsw="@@DEPLOYIT_IVL_ODI_RT_MASTER_PSW#@"
OdiRTUrl="@@DEPLOYIT_IVL_ODI_RT_URL#@"

## Gedeelte OEMM
OdiOEMMActive="@@DEPLOYIT_IVL_ODI_OEMM_ACTIVE#@"
OdiOEMMDeployUser="@@DEPLOYIT_IVL_ODI_OEMM_DEPLOY_USER#@"
OdiOEMMDeployPsw="@@DEPLOYIT_IVL_ODI_OEMM_DEPLOY_PSW#@"
OdiOEMMMasterUser="@@DEPLOYIT_IVL_ODI_OEMM_MASTER_USER#@"
OdiOEMMMasterPsw="@@DEPLOYIT_IVL_ODI_OEMM_MASTER_PSW#@"
OdiOEMMUrl="@@DEPLOYIT_IVL_ODI_OEMM_URL#@"

