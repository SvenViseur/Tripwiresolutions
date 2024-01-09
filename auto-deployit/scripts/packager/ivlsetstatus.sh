#!/bin/bash

#### ivlsetstatus.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# It will try to move the status from ACC_GOEDGEKEURD over
# ACC_IN_UITVOERING to ACC_UITGEVOERD_MET_FOUTEN.
#
# It is only to be used on Jenkins ACC by selected users
#
# Command line options:
#     TICKETNR		: The ticket number being deployed
#
#################################################################
# Change history
#################################################################
# dexa  # Jan/2020    # 1.0.0 # First version
#################################################################
ScriptName="ivlstatus.sh"
ScriptVersion="1.0.0"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

ArgTicketNr=$1

LogLineINFO "Script" ${ScriptName}  "started."
LogLineINFO "Options are:"
LogLineINFO "  TICKETNR = '${ArgTicketNr}'"

ArgStatus="ACC_IN_UITVOERING"
ArgErrMsg="ACC_In_Uitvoering NIET gelukt!"
TraceIT_UpdStatus

ArgStatus="ACC_UITGEVOERD_MET_FOUTEN"
ArgErrMsg="ACC_Uitgevoerd_Met_Fouten NIET gelukt!"
TraceIT_UpdStatus

LogLineINFO "Script" ${ScriptName}  "ended."
