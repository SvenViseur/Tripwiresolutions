#/bin/bash
####
####
# Create date : 01 Apr 2019
# Create User : Sven Viseur
####
#
####
# Usage example: 
# civl_ddl_check_sql.sh --env IVL_TST|IVL_ACC --sql <sqlpath + sqlname>
####

. ../cfg/CIVL_omgeving.cfg

export CIVL_SQLLOG=""
export CIVL_SQLENV=""
export CIVL_SQLSQL=""

while [ $# -ne 0 ]
do
case "$1" in
  "--env")
    shift
    export CIVL_SQLENV=$1
    shift
    ;;
  "--sql")
    shift
    export CIVL_SQLSQL=$1
    shift
    ;;
esac
done

if [ "$CIVL_SQLENV" = "" ] | [ "$CIVL_SQLSQL" = "" ]
then
    echo "ERROR: parameters incorrect."
        echo "ERROR: usage: --env <environment [DDL]> --sql <sql-file>"
        exit 1
fi

export CIVL_SQLLOG=$(dirname $CIVL_SQLSQL)"/"$(basename $CIVL_SQLSQL .sql)".log"
export CIVL_SQLLOG=$(echo $CIVL_SQLLOG | sed "s+/sql/+/log/+g")
export CIVL_FOLDER=$(dirname $CIVL_SQLSQL)"/"

echo $(date "+%m/%d/%y %H:%M:%S") " : Start executing ... " 

##############################################################################
# Read the config file to load proper credentials

. ./civl_orasecurity.sh --set $CIVL_SQLENV

oraExecDir=$( dirname $CIVL_SQLSQL )
oraLogDir=$( dirname $(dirname $CIVL_SQLSQL) | sed "s|/sql|/log|g")

oraSQLPATH=$( dirname $CIVL_SQLSQL)

export SQLPATH=$oraSQLPATH

cd $oraLogDir

echo "SQLPATH=> "$SQLPATH

#set NLS_LANG

NLS_LANG='AMERICAN_AMERICA.AL32UTF8'; export NLS_LANG

sqlplus -s "$DDL_DB_USR/$DDL_DB_PSW@$ora_srv" @$CIVL_SQLSQL

export ora_err=$?

echo "----- end sql -----"

exit $ora_err

