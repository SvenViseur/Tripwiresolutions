#!/bin/bash

#check_recursive_file.sh --file pls/IVL_FL/pa_fl_utilities.sql --sourcedir --targetdir""

export CIVL_FILE=""
export CIVL_SOURCE_DIR=""
export CIVL_TARGET_DIR=""

. ../cfg/CIVL_omgeving.cfg

while [ $# -ne 0 ]
do
case "$1" in
  "--file")
    shift
    export CIVL_FILE=$1
    ;;
  "--sourcedir")
    shift
    export CIVL_SOURCE_DIR=$1
    ;;
  "--targetdir")
    shift
    export CIVL_TARGET_DIR=$1
    ;;
esac
shift
done

if [ "$CIVL_FILE" = "" ] 
then
    echo "parameters incorrect."
        echo "usage: --file <source_file> "
        exit 1
fi

export CIVL_SUB_DIR=$(dirname $CIVL_FILE)

if [ "$CIVL_SUB_DIR" = "." ]
then
  export CIVL_SRCWORK_DIR=$CIVL_SOURCE_DIR
  export CIVL_TGTWORK_DIR=$CIVL_TARGET_DIR
else
  export CIVL_SRCWORK_DIR=$CIVL_SOURCE_DIR/$CIVL_SUB_DIR
  export CIVL_TGTWORK_DIR=$CIVL_TARGET_DIR/$CIVL_SUB_DIR
fi

if [ ! -d "$CIVL_TGTWORK_DIR" ]
then
  mkdir -p $CIVL_TGTWORK_DIR
fi

echo "INFO: check : ["$CIVL_FILE"] in directory ["$CIVL_SOURCE_DIR"]"

export CHECK_FILE=$(basename $CIVL_FILE)
# Find the file but case-insensitive
export COPYFILE=$(find ${CIVL_SRCWORK_DIR} -iname ${CHECK_FILE})

export CIVL_ERRORS=$?

   if [ "$COPYFILE" == "" ]
   then
     echo "ERROR: File not found: $CHECK_FILE in directory $CIVL_SRCWORK_DIR" 
     exit 1
   fi

   if [ $CIVL_ERRORS -ne 0 ]
   then
     echo "ERROR: The script failed" 
     exit 1
   fi

export IVL_FILE_ENCODING=$(file -b --mime-encoding $COPYFILE| tr '[:lower:]' '[:upper:]')

  if [ "$IVL_FILE_ENCODING" != "UTF-8" ]
   then
     echo "WARNING: Your file [$COPYFILE] is not in UTF-8 encoding this may cause issues during the deployment"
   fi

#echo "Copyfile: "$COPYFILE
export CHECK_FILE=$(basename $COPYFILE)

# Add additional checks before we copy

content_check=( "^exit" "dev_ana_tst_role" "run_team_role" "devops_role" "system_team_role" "ivl_cmp_role_ret" "ivl_cmp_role_upd" "ivl_cmp_role_exe" "civl_cmp_role_ret" "civl_cmp_role_upd" "civl_cmp_role_exe" "metadata_role" "session_crealt" "ddl_crealt_role")

echo "Check content"

for checkcontent in "${content_check[@]}"
do
   check_occurrence=$(cat $COPYFILE | grep -i "$checkcontent" | wc -l)
   if [ "$check_occurrence" -ne "0" ]; then
       echo "ERROR: sql file "$CHECK_FILE" contains technical role: "$checkcontent" <-- !!!"
       exit 1
   fi
done

echo "Check spool"

content_check=( "^spool " )
for checkcontent in "${content_check[@]}"
do
   check_occurrence=$(cat $COPYFILE | grep -i "$checkcontent" | wc -l)
   if [ "$check_occurrence" -ne "0" ]; then
       echo "ERROR: sql file "$CHECK_FILE" contains spool file: "$checkcontent" <-- !!!"
       exit 1
   fi
done

# Add additional checks if personal users are in the scripts

. ./civl_orasecurity.sh --set ACC

# Temporary de-activated part due to ACC-refresh failed on 17/06

# Get the list of users also

array_check=($( sqlplus -s "$ACC_DB_USR/$ACC_DB_PSW@$ora_srv" << EOF
SET PAGESIZE 0;
SET SERVEROUTPUT ON;
SET FEEDBACK OFF;
set trimspool on;
set linesize 300;
set echo off;
set verify off;
select distinct replace(replace(lower(username),chr(13),''),chr(10),'')
  from dba_users
 where profile in ('C##END_USER_PROFILE','C##PRIV_USER_PROFILE')
 order by 1;
EOF
))

echo "Check grants"

for checkcontent in "${array_check[@]}"
do
   echo "Check grants for user: "${checkcontent} 2 > /dev/null
   # Before checking to grant: remove all crlf, replace then all the ; to ;+crlf, remove the leading spacec and you have all sql statements on 1 line per statement
   check_occurrence=$(cat $COPYFILE  | tr  '\n' ' ' | sed "s/;/;\n/g" | sed -e 's/^[ \t]*//' | grep -iw "^grant" |  grep -iw "${checkcontent}" | wc -l)

   if [ "$check_occurrence" -ne "0" ]; then
       echo "ERROR: sql file "$CHECK_FILE" contains grant local user: "${checkcontent}" <-- !!!"
       exit 1
   fi
done

# If all is fine: copy the file

echo "Copy File"

cp -f $CIVL_SRCWORK_DIR/$CHECK_FILE $CIVL_TGTWORK_DIR/$CHECK_FILE

export CIVL_ERRORS=$?

if [ $CIVL_ERRORS -ne 0 ]
then
   echo "ERROR: The copy for the sql script failed ["$CIVL_SRCWORK_DIR/$CHECK_FILE"] to ["$CIVL_TGTWORK_DIR/$CHECK_FILE"]" 
#>&2
   exit 1
fi

for OUTPUT in $(cat $CIVL_SRCWORK_DIR/$CHECK_FILE | grep "^@@" )
do
#   echo $OUTPUT
echo "INFO: processing .. "$OUTPUT

   OUTPUT=$(echo $OUTPUT | sed "s/@@//g")
   EXT=${OUTPUT##*.}
   if [ "$EXT" = "$OUTPUT" ] 
   then
      OUTPUT=$OUTPUT.sql
   fi
   ./civl_check_recursive_file.sh --file $CIVL_SUB_DIR/$OUTPUT --sourcedir $CIVL_SOURCE_DIR --targetdir $CIVL_TARGET_DIR
done

