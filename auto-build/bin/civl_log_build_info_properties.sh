#!/bin/bash

export input_properties=""


while [ $# -ne 0 ]
do
case "$1" in
  "--properties")
    shift
    export input_properties=$1
    ;;
esac
shift
done

. ./civl_orasecurity.sh --set LOG

### PROPERTIES

# Read the properties file and set them as environment variables
while read -r line
do
   var_name=$(echo ${line} | cut -d '=' -f 1)
   var_value=$(echo ${line} | cut -d '=' -f 2)
   exec_cmd='export '${var_name}"='"${var_value}"'"
   eval ${exec_cmd}
done < "${input_properties}"

export sql_parameters=""
export sql_parameters=${sql_parameters}'p_Omgeving => '\'${BLDR_Omgeving}\',
export sql_parameters=${sql_parameters}'p_TicketID => '\'${BLDR_TicketID}\',
export sql_parameters=${sql_parameters}'p_URL => '\'${BLDR_URL}\',
export sql_parameters=${sql_parameters}'p_Team => '\'${BLDR_Team}\',
export sql_parameters=${sql_parameters}'p_Summary => '\'${BLDR_Summary}\',
export sql_parameters=${sql_parameters}'p_Assignee => '\'${BLDR_Assignee}\',
export sql_parameters=${sql_parameters}'p_Project => '\'${BLDR_Project}\',
export sql_parameters=${sql_parameters}'p_Source => '\'${BLDR_Source}\',
export sql_parameters=${sql_parameters}'p_DDL_List => '\'${BLDR_DDL_List}\',
export sql_parameters=${sql_parameters}'p_ODI_List => '\'${BLDR_ODI_List}\',
export sql_parameters=${sql_parameters}'p_Stop_Env => '\'${BLDR_Stop_Env}\',
export sql_parameters=${sql_parameters}'p_Epic => '\'${BLDR_Epic}\',
export sql_parameters=${sql_parameters}'p_TIProject => '\'${BLDR_TIProject}\',
export sql_parameters=${sql_parameters}'p_TIRelease => '\'${BLDR_TIRelease}\',
export sql_parameters=${sql_parameters}'p_TIProjectID => '\'${BLDR_TIProjectID}\',
export sql_parameters=${sql_parameters}'p_ReleaseType => '\'${BLDR_ReleaseType}\',
export sql_parameters=${sql_parameters}'p_TIADC => '\'${BLDR_TIADC}\',
export sql_parameters=${sql_parameters}'p_AutoBuild => '\'${BLDR_AutoBuild}\',
export sql_parameters=${sql_parameters}'p_AutoDeployACC => '\'${BLDR_AutoDeployACC}\',
export sql_parameters=${sql_parameters}'p_TIOmschrijving => '\'${BLDR_TIOmschrijving}\',
export sql_parameters=${sql_parameters}'p_TITeam => '\'${BLDR_TITeam}\',
export sql_parameters=${sql_parameters}'p_BuildRequest => '\'${BLDR_BuildRequest}\',
export sql_parameters=${sql_parameters}'p_BUILD_ID => '\'${BLDR_BUILD_ID}\',
export sql_parameters=${sql_parameters}'p_ISSUETYPE => '\'${BLDR_TypeStory}\',
export sql_parameters=${sql_parameters}'p_COMPONENT => '\'${BLDR_Component}\'


sqlplus -s "$RMC_DB_USR/$RMC_DB_PSW@$ora_srv" 1>/dev/null 2>&1 <<EOF 
SET PAGESIZE 0;
SET SERVEROUTPUT ON;
SET FEEDBACK ON;
set trimspool on;
set linesize 300;
set echo on;
set verify off;
BEGIN
   civl_rmc.rmc_log_installation.p_log_build_header($sql_parameters);
END;
/
EOF

