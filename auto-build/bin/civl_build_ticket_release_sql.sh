#!/bin/bash

#. ../cfg/CIVL_omgeving.cfg

export CIVL_TICKET=""
export CIVL_ERROR=0
export CIVL_BRANCH=""
export CIVL_PROJECT=IVL

while [ $# -ne 0 ]
do
case "$1" in
  "--ticket")
    shift
    export CIVL_TICKET=$1
    ;;
  "--sqllist")
    shift
    export CIVL_SOURCE=$1
    ;;
  "--main")
    shift
    export CIVL_MAIN=$1
    ;;
   "--branch")
    shift
    export CIVL_BRANCH=$1
    ;;
   "--project")
    shift
    export CIVL_PROJECT=$1
    ;;
esac
shift
done

if [ "$CIVL_TICKET" = "" ] | [ "$CIVL_SOURCE" = "" ]
then
    echo "ERROR: parameters incorrect."
    echo "ERROR: usage: --ticket <jira_ticket> --sqllist <SQL LIST.dit file> [--project IVL|CIVL --main <main-ticket (specific for patch releases)> --branch <branch directory (if the code-base is not the source of global scripts>)]"
    exit 1
fi

export CIVL_CFG_FILE=$CIVL_PROJECT"_omgeving.cfg"

# Dynamische config file op basis van het project (meegegeven als parameter)
# Bepaalt dan ook de juiste repository die moet benadert worden

#. $CIVL_HOME_CFG/$CIVL_CFG_FILE
. ../cfg/$CIVL_CFG_FILE

export CIVL_TARGET_SQL_DIR=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/sql/$CIVL_TICKET
export CIVL_TMP_DIR=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/wrk_tmp
export CIVL_PARAMETER_DIR=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/parameters

#Add comment release build

#  printf -v data  '{"body": "Release DDL sql build started for ticket %s"}' "$CIVL_TICKET"
#  curl -s -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X POST --data "$data" "https://digiwave.atlassian.net/rest/api/2/issue/$CIVL_TICKET/comment"

dos2unix $CIVL_SOURCE 2> /dev/null

export OUTPUT_TMP=$CIVL_TMP_DIR/$CIVL_TICKET
export OUTPUT_LIST=$OUTPUT_TMP".lst"
export OUTPUT_LIST_WRK=$OUTPUT_TMP".wrk"

export CIVL_IS_EMPTY=$(cat $CIVL_SOURCE | sed 's/ //g' | sed '/^$/d' | awk '{print $1}' | wc -l)

# If zero lines, file is empty
if [ "$CIVL_IS_EMPTY" == "0" ]; then
  exit 0
fi

# copy the complete file as is
cat $CIVL_SOURCE | sed '/^$/d' | awk '{print $1}' > $OUTPUT_LIST

if [ "$CIVL_MAIN" == "" ]; then
   export MAIN_SQL_TICKET=$CIVL_TARGET_SQL_DIR/$CIVL_TICKET"_main_sql.sql"
else
   export MAIN_SQL_TICKET=$CIVL_TARGET_SQL_DIR/$CIVL_MAIN"_main_sql.sql"
fi

cat $CIVL_HOME_CFG/CIVL_sql.header | sed "s/JIRA_TICKET/$CIVL_TICKET/g" > $MAIN_SQL_TICKET

# change CRLF to LF : tr -d '\r' < test_windows.sql > output_unix.sql
while IFS= read -r element
do
  echo "INFO: Add to main ticket =>" $element
  execute_sql="$CIVL_TARGET_SQL_DIR/$element"
  cat $CIVL_HOME_CFG/CIVL_sql.middle | sed "s+IVL_SQLFILE+$element+g" | sed "s+IVL_SQLPATHFILE+$execute_sql+g" >> $MAIN_SQL_TICKET
done < $OUTPUT_LIST

cat $CIVL_HOME_CFG/CIVL_sql.footer | sed "s+JIRA_TICKET+$CIVL_TICKET+g"  >> $MAIN_SQL_TICKET

# Copy now the existing SQL files from the subversion place (to_release) to the appropriate place and perform also a search and replace

cat $MAIN_SQL_TICKET | grep "@@" | grep "/" | sed "s/@@//g" | sed "s/;//g" > "$OUTPUT_LIST_WRK"

while IFS= read -r element
do
   echo "INFO: Checking script + subscripts: "$element
   if [ "$CIVL_BRANCH" = "" ]; then
      #cp -r $CIVL_GLOBAL_SCRIPTS_DIR/$element "$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/sql/."
      ./civl_check_recursive_file.sh --file $element --sourcedir $CIVL_GLOBAL_SCRIPTS_DIR --targetdir $CIVL_TARGET_SQL_DIR
   else
      #cp -r $CIVL_GLOBAL_SCRIPTS_BRANCHES/$CIVL_BRANCH/$element "$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/sql/."
      ./civl_check_recursive_file.sh --file $element --sourcedir $CIVL_GLOBAL_SCRIPTS_BRANCHES/$CIVL_BRANCH --targetdir $CIVL_TARGET_SQL_DIR
   fi

   if [ $? -ne 0 ]
   then
     echo "ERROR: Checking of content failed " >&2
     exit 1
   fi

   find $CIVL_TARGET_SQL_DIR -name ".*" -exec rm -rf {} \;
done < "$OUTPUT_LIST_WRK"

#remove work file
rm -f "$OUTPUT_LIST_WRK"

cat $OUTPUT_LIST | grep -v "/" > "$OUTPUT_LIST_WRK"

while IFS= read -r element
do
   echo "INFO: Copy from To_release folder=>" $CIVL_SOURCE_DIR_MAIN/$element
   if [ "$CIVL_BRANCH" = "" ]; then
     execute_sql="$CIVL_TARGET_SQL_DIR/$element"
     source_sql="$CIVL_SOURCE_DIR_MAIN/$element"
     ./civl_check_recursive_file.sh --file $element --sourcedir $CIVL_SOURCE_DIR_MAIN --targetdir $CIVL_TARGET_SQL_DIR
     
   else
     execute_sql="$CIVL_TARGET_SQL_DIR/$element"
     source_sql="$CIVL_GLOBAL_SCRIPTS_BRANCHES/$CIVL_BRANCH/$CIVL_SOURCE_DIR_BRANCH/$element" 
     ./civl_check_recursive_file.sh --file $element --sourcedir $CIVL_GLOBAL_SCRIPTS_BRANCHES/$CIVL_BRANCH/$CIVL_SOURCE_DIR_BRANCH --targetdir $CIVL_TARGET_SQL_DIR

   fi
 
   if [ $? -ne 0 ]
   then
     echo "ERROR: Copy of Release folder failed" >&2
     exit 1
   fi

done < "$OUTPUT_LIST_WRK"

# Check of alle sql files er zijn die aangeroepen worden in het script
while IFS= read -r element
do
  echo "INFO: Check if main file is copied and known =>" $element
  zoek_file="$CIVL_TARGET_SQL_DIR/$element"
  if [ ! -f $zoek_file ]
   then
     echo "ERROR: Non Existing file $element"
     exit 1
  fi
  # maak nu ook de sqlinfo file aan
#
#
#  cat $zoek_file | sed "s/\"//g" | grep -Eo "\w+\.\w+" | sort | uniq | egrep -i "^CIVL|^IVL" | tr '[:lower:]' '[:upper:]' | awk -v ticketid=$CIVL_TICKET -v buildid=$BUILD_ID -v sqlfilename=$element -v project=$CIVL_PROJECT '{print ticketid"|"buildid"|"project"|"sqlfilename"|sqlobject|" $0}' >> $CIVL_TARGET_SQL_DIR/${CIVL_TICKET}.sqldetailinfo
#
#
# Using CIVL or IVL
  cat $zoek_file | sed "s/\"//g" | grep -Eo "\w+\.\w+" | sort | uniq | tr '[:lower:]' '[:upper:]' | egrep -i "^CIVL|^IVL" | awk -v ticketid=$CIVL_TICKET -v buildid=$BUILD_ID -v sqlfilename=$element -v project=$CIVL_PROJECT '{print ticketid"|"buildid"|"project"|"sqlfilename"|sqlobject|" $0"#USING"}' >> $CIVL_TARGET_SQL_DIR/${CIVL_TICKET}.sqldetailinfo

# CIVL
  cat $zoek_file | sed "s/\"//g" | grep -v "^--" | tr '[:lower:]' '[:upper:]' | sed -e 's/^[ \t]*//' | grep -v "^PROMPT " | grep -v "^WHENEVER" | grep -v "^REM " | grep -v "^\/" | tr -d '\015' | sed '/^\s*$/d' | tr '\n' ' ' | tr ';' '\n' | sed -e 's/^[ \t]*//' | egrep "^UPDATE|^DELETE|^ALTER|^CREATE|^TRUNCATE" | awk '{ for(i = 1; i <= 20; i++) { if ($i ~ /^CIVL_/) print $i"#"$1 } }' | sed 's/([^:(]*#/#/g' | grep "\." | sort | uniq | awk -v ticketid=$CIVL_TICKET -v buildid=$BUILD_ID -v sqlfilename=$element -v project=$CIVL_PROJECT '{print ticketid"|"buildid"|"project"|"sqlfilename"|sqlobject|" $0}' >> $CIVL_TARGET_SQL_DIR/${CIVL_TICKET}.sqldetailinfo

# IVL
  cat $zoek_file | sed "s/\"//g" | grep -v "^--" | tr '[:lower:]' '[:upper:]' | sed -e 's/^[ \t]*//' | grep -v "^PROMPT " | grep -v "^WHENEVER" | grep -v "^REM " | grep -v "^\/" | tr -d '\015' | sed '/^\s*$/d' | tr '\n' ' ' | tr ';' '\n' | sed -e 's/^[ \t]*//' | egrep "^UPDATE|^DELETE|^ALTER|^CREATE|^TRUNCATE" | awk '{ for(i = 1; i <= 20; i++) { if ($i ~ /^IVL_/) print $i"#"$1 } }' | sed 's/([^:(]*#/#/g' | grep "\." | sort | uniq | awk -v ticketid=$CIVL_TICKET -v buildid=$BUILD_ID -v sqlfilename=$element -v project=$CIVL_PROJECT '{print ticketid"|"buildid"|"project"|"sqlfilename"|sqlobject|" $0}' >> $CIVL_TARGET_SQL_DIR/${CIVL_TICKET}.sqldetailinfo

  #cat $zoek_file | tr '\r\n' ' '|  tr  '\n' ' ' | tr '/' ' ' | sed "s/;/;\n/g" | sed -e 's/^[ \t]*//' | sed -e 's/\t/ /g' | egrep -i "^UPDATE|^DELETE|^ALTER|^CREATE" | cut -c 1-100 | tr '[:lower:]' '[:upper:]' | tr -s ' ' | sort | uniq |  awk -v ticketid=$CIVL_TICKET -v buildid=$BUILD_ID -v sqlfilename=$zoek_file -v project=$CIVL_PROJECT '{print ticketid"|"buildid"|"project"|"sqlfilename"|sqlcommand|" $0}' >> $CIVL_TARGET_SQL_DIR/${CIVL_TICKET}.sqldetailinfo

done < $OUTPUT_LIST

#echo "start build deploy info ddl for "$CIVL_TICKET
##civl_build_deploy_info_ddl $CIVL_TICKET $CIVL_PROJECT

#DDL_WRK=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/wrk_tmp/release_ddl.lst

#/usr/bin/find $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/sql/* -maxdepth 2 -type f -not -name ".*" -name "*_main_sql.sql" | xargs -I{} dirname {} | /usr/bin/sort | uniq | awk '{ print gensub( ".*/", "", 1 );  }' > $DDL_WRK

RELEASE_ORDER=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/wrk_tmp/$CIVL_TICKET.lst_srt
echo "10.0|"$CIVL_TICKET > $RELEASE_ORDER

echo $CIVL_TICKET > $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/parameters/DDL_execution_order.txt

#if [ -f $RELEASE_ORDER ]
#    then
#      grep -f $DDL_WRK <(awk -F "|" '{print $1"|"$2}' $RELEASE_ORDER) | /usr/bin/sort -t '|' -n | cut -d "|" -f2 | awk '{ print NR " - " gensub( ".*/", "", 1 );  }' > $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/parameters/DDL_execution_order.txt
#      grep -f $DDL_WRK <(awk -F "|" '{print $1"|"$2}' $RELEASE_ORDER) | /usr/bin/sort -t '|' -n | cut -d "|" -f2 | awk '{ print NR "_" gensub( ".*/", "", 1 );  }' > $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/parameters/DDL_traceit.wrk
#
#fi

