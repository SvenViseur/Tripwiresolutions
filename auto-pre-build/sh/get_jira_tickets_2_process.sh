#!/bin/bash

export N_WORKSPACE=$(echo "/"$WORKSPACE | tr '\\' '/' | sed "s/://g")


## TEMPORARY
## export N_WORKSPACE="/home/oracle/civl_release/prd/bin_pre_new"
###

export PREBLD_HOME_DIR=$N_WORKSPACE
export PREBLD_BIN_BIN=$PREBLD_HOME_DIR/sh
export PREBLD_LIB_DIR=$PREBLD_HOME_DIR/lib
export PREBLD_TMP_DIR=$PREBLD_HOME_DIR/tmp
export PREBLD_CFG_DIR=$PREBLD_HOME_DIR/cfg
export PREBLD_LIST_TICKETS=""

mkdir $PREBLD_TMP_DIR

# Check if connection to JIRA is correct
# User = USER_JIRA_SYSTEMTEAMESPERANTO as defined in the Jenkins Job

export access_is_ok=$(curl -Isk -u $USER_JIRA_SYSTEMTEAMESPERANTO:$PSW_JIRA_SYSTEMTEAMESPERANTO https://digiwave.atlassian.net/rest/api/2/search | head -n 1 | cut -d " " -f2)

## TEMPORARY
## access_is_ok="200"
###

if [ "${access_is_ok}" != "200" ]
then
   echo "### !!!!!!!!!!!!!!!!!!!!!!!! ###"
   echo "### ERROR: access is not ok  ###"
   echo "### Returnd code : ${access_is_ok}       ###"
   echo "### !!!!!!!!!!!!!!!!!!!!!!!! ###"
   export BLDR_Info="ERR RTRN ${access_is_ok}"
   echo "BLDR_Info="${BLDR_Info} > $N_WORKSPACE/work_dir/returned_value.txt
   # check access first
   curl -s -k -u $JIRA_SYSTEMTEAMESPERANTO_USR:$JIRA_SYSTEMTEAMESPERANTO_PSW https://digiwave.atlassian.net/rest/api/2/search > $N_WORKSPACE/work_dir/access_not_ok.log

   exit 1
fi

nbr_processed_tickets=0

for PREBLD_FILE in $(ls ${PREBLD_CFG_DIR}/*.prb)
do

   #Read the prebuild file first
   source ${PREBLD_FILE}

   #Start processing the curl command to get the keys

   echo "#########################"
   echo "### Processing ... "${PREBUILD_DESCRIPTION}
   echo "#########################"


   # get all tickets
   jira_tickets=($( curl -s -k -u ${JIRA_SYSTEMTEAMESPERANTO_USR}:${JIRA_SYSTEMTEAMESPERANTO_PSW} -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=${PREBUILD_JIRA_JQL}&startAt=0&maxResults=500&fields=key" | grep -Po '"key": *\K"[^"]*"' |  sed "s/\"//g" | sed "s/ //g" ))

   # Process per ticket returned

   for jira_ticket in "${jira_tickets[@]}"
   do

      if [ "$PREBLD_LIST_TICKETS" != "" ]
      then
        export CIVL_LIST_TICKETS=${CIVL_LIST_TICKETS}","
      fi
      export CIVL_LIST_TICKETS=${CIVL_LIST_TICKETS}${jira_ticket}


      echo "#############################"
      echo "## Ticket: ${PREBUILD_INFO} - ${jira_ticket} "
      echo "#############################"

      cd $PREBLD_BIN_BIN
      subversion_dir=$PREBUILD_TARGET_SUBVERSION

      # Get the ticket info from JIRA
      curl -s -k -u ${JIRA_SYSTEMTEAMESPERANTO_USR}:${JIRA_SYSTEMTEAMESPERANTO_PSW} -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=key%20%3D%20%22"$jira_ticket"%22&startAt=0&maxResults=1" > $PREBLD_TMP_DIR/${jira_ticket}.tmp

      # Create now the property file based on the json file from JIRA
      # Parameters: -f <input file> -o <output file> -t type (issue only -b 
      groovy ${PREBLD_LIB_DIR}/${PREBUILD_GROOVY} -f ${PREBLD_TMP_DIR}/${jira_ticket}.tmp -o ${PREBLD_TMP_DIR}/${jira_ticket}.properties  -t issue -b Y

      # Create the directory in the proper subversion directory
      # Copy the property file
      # Perform an svn commit

      if [ -d $subversion_dir/$jira_ticket ]
      then
        svn del $subversion_dir/$jira_ticket
        svn commit -m "Removed" $subversion_dir/$jira_ticket
      fi

      mkdir $subversion_dir/$jira_ticket

      cd $subversion_dir/$jira_ticket
      cp $PREBLD_TMP_DIR/${jira_ticket}.properties $subversion_dir/$jira_ticket/${jira_ticket}.properties
      rm -f $PREBLD_TMP_DIR/${jira_ticket}.tmp
      rm -f $PREBLD_TMP_DIR/${jira_ticket}.properties

      cd $subversion_dir
      svn update
      svn cleanup
      svn add $jira_ticket/ --force
      svn commit $jira_ticket/  --force-log -m "$jira_ticket"

      # Update the JIRA now to remove it from the FixVersion
      curl -s -k -u ${JIRA_SYSTEMTEAMESPERANTO_USR}:${JIRA_SYSTEMTEAMESPERANTO_PSW} -H "Content-Type: application/json" -X PUT --data '{"update":{"fixVersions":[{"remove":{"name":"Send Request to Build via Jenkins"}} ,{"add":{"name":"Request Sent to Jenkins"}}]}}'  "https://digiwave.atlassian.net/rest/api/3/issue/$jira_ticket"

      export nbr_processed_tickets=$((nbr_processed_tickets + 1))
      export BLDR_Info=${nbr_processed_tickets}" tickets"

   done

   unset PREBUILD_INFO
   unset PREBUILD_DESCRIPTION
   unset PREBUILD_JIRA_JQL
   unset PREBUILD_GROOVY
   unset PREBUILD_TARGET_SUBVERSION

done

echo "BLDR_Info="${BLDR_Info} > $PREBLD_TMP_DIR/returned_value.txt

if [ "$PREBLD_LIST_TICKETS" == "" ]
then
   export CIVL_LIST_TICKETS="No tickets"
fi

echo "BLDR_DESC="${CIVL_LIST_TICKETS} > $PREBLD_TMP_DIR/build_desc.txt

