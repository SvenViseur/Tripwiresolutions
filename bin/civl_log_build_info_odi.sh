#!/bin/bash

export input_properties=""
export input_header=""
export input_detail=""


while [ $# -ne 0 ]
do
case "$1" in
  "--properties")
    shift
    export input_properties=$1
    ;;
  "--header")
    shift
    export input_header=$1
    ;;
  "--detail")
    shift
    export input_detail=$1
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

### HEADER

oIFS=$IFS
IFS="|"
while read pTicket pOdiType pOdiName pLastUser pGlobalID pLastUpdateDate pBuildID
# example : EST-2139|loadplan|CIVL_LP_TEST_CASE_JENKINS2_LOADPLAN_DO_NOT_EXECUTE|visv|6015fa48-ee1f-4504-886e-e70be45e67f4|2020-02-07 8:48:00|103
do

  export pTraceTicket='0'
  export pJenkinsType='B'

  export sql_parameters=""
  export sql_parameters=${sql_parameters}'p_build_id => '\'${pBuildID}\',
  export sql_parameters=${sql_parameters}'p_jira_ticket => '\'${pTicket}\',
  export sql_parameters=${sql_parameters}'p_traceit_ticket_id => '\'${pTraceTicket}\',
  export sql_parameters=${sql_parameters}'p_type => '\'${pOdiType}\',
  export sql_parameters=${sql_parameters}'p_name => '\'${pOdiName}\',
  export sql_parameters=${sql_parameters}'p_update_by => '\'${pLastUser}\',
  export sql_parameters=${sql_parameters}'p_global_id => '\'${pGlobalID}\',
  export sql_parameters=${sql_parameters}'p_last_update => '\'${pLastUpdateDate}\',
  export sql_parameters=${sql_parameters}'p_jenkins_type => '\'${pJenkinsType}\'

  sqlplus -s "$RMC_DB_USR/$RMC_DB_PSW@$ora_srv" 1>/dev/null 2>&1<<EOF
SET PAGESIZE 0;
SET SERVEROUTPUT ON;
SET FEEDBACK ON;
set trimspool on;
set linesize 300;
set echo on;
set verify off;
BEGIN
   civl_rmc.rmc_log_installation.p_log_build_odi_header($sql_parameters);
END;
/
EOF

done < "${input_header}"
IFS=$oIFS

### DETAIL

oIFS=$IFS
IFS="|"
while read pTicket pOdiType pOdiName pSourceOdiType pSourceOdiName pSourceLastUser pSourceGlobalID pSourceLastUpdateDate pBuildID 

# example : EST-2139|scenario|CIVL_S_TEST_CASE_JENKINS2_CIVL_M_9001_GG_HEART_BEAT|mapping|TEST_CASE_JENKINS2_CIVL_M_9001_GG_HEART_BEAT|visv|e1d1c2d6-0980-46c4-b72f-c03c2fd676ee|2020-02-07 8:39:00|102
do
  export pTraceTicket='0'
  export pJenkinsType='B'
  export sql_parameters=""
  export sql_parameters=${sql_parameters}'p_build_id => '\'${pBuildID}\',
  export sql_parameters=${sql_parameters}'p_jira_ticket => '\'${pTicket}\',
  export sql_parameters=${sql_parameters}'p_traceit_ticket_id => '\'${pTraceTicket}\',
  export sql_parameters=${sql_parameters}'p_type => '\'${pOdiType}\',
  export sql_parameters=${sql_parameters}'p_name => '\'${pOdiName}\',
  export sql_parameters=${sql_parameters}'p_source_type => '\'${pSourceOdiType}\',
  export sql_parameters=${sql_parameters}'p_source_name => '\'${pSourceOdiName}\',
  export sql_parameters=${sql_parameters}'p_source_update_by => '\'${pSourceLastUser}\',
  export sql_parameters=${sql_parameters}'p_source_global_id => '\'${pSourceGlobalID}\',
  export sql_parameters=${sql_parameters}'p_source_last_update => '\'${pSourceLastUpdateDate}\',
  export sql_parameters=${sql_parameters}'p_jenkins_type => '\'${pJenkinsType}\'

  sqlplus -s "$RMC_DB_USR/$RMC_DB_PSW@$ora_srv" 1>/dev/null 2>&1<<EOF
SET PAGESIZE 0;
SET SERVEROUTPUT ON;
SET FEEDBACK ON;
set trimspool on;
set linesize 300;
set echo on;
set verify off;
BEGIN
   civl_rmc.rmc_log_installation.p_log_build_odi_detail($sql_parameters);
END;
/
EOF

done < "${input_detail}"

IFS=$oIFS

