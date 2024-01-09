#!/bin/bash

export RP_ACTION=""

while [ $# -ne 0 ]
do
case "$1" in
  "--action")
    shift
    export RP_ACTION=$1
    ;;
esac
shift
done

if [ "$RP_ACTION" == "" ]
then
    echo "parameters incorrect."
    echo "usage: --action <CREATE|RESTORE|DROP>"
    exit 1
fi

. ../cfg/CIVL_omgeving.cfg

. ./civl_orasecurity.sh --set DDL

echo "pwd/usr=$DDL_DB_PSW -- $DDL_DB_USER" 
echo "orasrv =$ora_srv"

if [ "$RP_ACTION" == "CREATE" ]
then
#   sqlplus C##IVL_ADMIN/ora4ivl_ORA4IVL@ARGEXA02-SCAN-ACC:1521/CIVLACC1_srv @../sql/PDDL_create_restore_point.sql
    sqlplus "$DDL_DB_USER/$DDL_DB_PSW@$ora_srv" @../sql/PDDL_create_restore_point.sql
fi


if [ "$RP_ACTION" == "RESTORE" ]
then
#   sqlplus C##IVL_ADMIN/ora4ivl_ORA4IVL@ARGEXA02-SCAN-ACC:1521/CIVLACC1_srv @../sql/PDDL_flashback_to_restore_point.sql
    sqlplus "$DDL_DB_USER/$DDL_DB_PSW@$ora_srv" @../sql/PDDL_flashback_to_restore_point.sql
fi


if [ "$RP_ACTION" == "DROP" ]
then
#   sqlplus C##IVL_ADMIN/ora4ivl_ORA4IVL@ARGEXA02-SCAN-ACC:1521/CIVLACC1_srv @../sql/PDDL_drop_restore_point.sql
    sqlplus "$DDL_DB_USER/$DDL_DB_PSW@$ora_srv" @../sql/PDDL_drop_restore_point.sql
fi

script_err=$?

if [ $script_err -gt 0 ]
then
        exit $script_err
fi

