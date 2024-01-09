#!/bin/bash

export N_WORKSPACE=$(echo "/"$WORKSPACE | tr '\\' '/' | sed "s/://g")

export CIVL_HOME_DIR=$N_WORKSPACE
export CIVL_BIN_BIN=$CIVL_HOME_DIR/bin
export CIVL_WORK_DIR=$N_WORKSPACE/work_dir
export CIVL_LIST_TICKETS=""

mkdir $CIVL_WORK_DIR

omgevingen[0]="CIVL"
omgevingen[1]="IVL"

echo "##############################"
echo "tns_admin info: ["$TNS_ADMIN"]"
echo "##############################"

export access_is_ok=$(curl -Isk -u $USER_JIRA_SYSTEMTEAMESPERANTO:$PSW_JIRA_SYSTEMTEAMESPERANTO https://digiwave.atlassian.net/rest/api/2/search | head -n 1 | cut -d " " -f2)

if [ "${access_is_ok}" != "200" ]
then
   echo "### !!!!!!!!!!!!!!!!!!!!!!!! ###"
   echo "### ERROR: access is not ok  ###"
   echo "### Returnd code : ${access_is_ok}       ###"
   echo "### !!!!!!!!!!!!!!!!!!!!!!!! ###"
   export BLDR_Info="ERR RTRN ${access_is_ok}"
   echo "BLDR_Info="${BLDR_Info} > $N_WORKSPACE/work_dir/returned_value.txt
   # check access first
   curl -s -k -u $USER_JIRA_SYSTEMTEAMESPERANTO:$PSW_JIRA_SYSTEMTEAMESPERANTO https://digiwave.atlassian.net/rest/api/2/search > $N_WORKSPACE/work_dir/access_not_ok.log

   exit 1
fi

#exit 0

nbr_processed_tickets=0

for omgeving in "${omgevingen[@]}"
do

   echo "#########################"
   echo "### Processing ... "${omgeving}
   echo "#########################"

   # get all tickets

   jira_tickets=($( curl -s -k -u $USER_JIRA_SYSTEMTEAMESPERANTO:$PSW_JIRA_SYSTEMTEAMESPERANTO -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=issuetype%20in%20(%22Story%22%2C%22Bug%22%2C%22Enabler%22%2C%22Maintenance%22%2C%22Task%22%2C%22Sub-task%22%2C%22Problem%22%2C%22Test%20Defect%22)%20AND%20Fixversion%3D%20%22Send%20Request%20to%20Build%20via%20Jenkins%22%20AND%20Repository%20%3D%20%22$omgeving%22&startAt=0&maxResults=500&fields=key" | grep -Po '"key": *\K"[^"]*"' |  sed "s/\"//g" | sed "s/ //g" ))

   # Process per ticket returned

   for JIRA_TICKET in "${jira_tickets[@]}"
   do

      if [ "$CIVL_LIST_TICKETS" != "" ]
      then
        export CIVL_LIST_TICKETS=${CIVL_LIST_TICKETS}","
      fi
      export CIVL_LIST_TICKETS=${CIVL_LIST_TICKETS}${JIRA_TICKET}

      echo "#############################"
      echo "## Ticket: ${omgeving} - ${JIRA_TICKET} "
      echo "#############################"

      cd $CIVL_BIN_BIN
      subversion_dir=$N_WORKSPACE/$omgeving"_jenkins_release"

      # Get the ticket info from JIRA
      curl -s -k -u $USER_JIRA_SYSTEMTEAMESPERANTO:$PSW_JIRA_SYSTEMTEAMESPERANTO -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=key%20%3D%20%22"$JIRA_TICKET"%22&startAt=0&maxResults=1" > $CIVL_WORK_DIR/${JIRA_TICKET}.tmp

      # Create now the property file based on the json file from JIRA
      groovy JIRA_BUILD.groovy -f $CIVL_WORK_DIR/${JIRA_TICKET}.tmp -o $CIVL_WORK_DIR/${JIRA_TICKET}.properties  -t issue -b Y

      # Create the directory in the proper subversion directory
      # Copy the property file
      # Perform an svn commit 

      if [ -d $subversion_dir/$JIRA_TICKET ]
      then
        svn del $subversion_dir/$JIRA_TICKET
        svn commit -m "Removed" $subversion_dir/$JIRA_TICKET
      fi

      mkdir $subversion_dir/$JIRA_TICKET

      cd $subversion_dir/$JIRA_TICKET
      cp $CIVL_WORK_DIR/${JIRA_TICKET}.properties $subversion_dir/$JIRA_TICKET/${JIRA_TICKET}.properties
      rm -f $CIVL_WORK_DIR/${JIRA_TICKET}.tmp
      rm -f $CIVL_WORK_DIR/${JIRA_TICKET}.properties

      cd $subversion_dir
      svn update
      svn cleanup
      svn add $JIRA_TICKET/ --force
      svn commit $JIRA_TICKET/  --force-log -m "$JIRA_TICKET"

#      # Update the JIRA now to remove it from the FixVersion 
      curl -s -k -u $USER_JIRA_SYSTEMTEAMESPERANTO:$PSW_JIRA_SYSTEMTEAMESPERANTO -H "Content-Type: application/json" -X PUT --data '{"update":{"fixVersions":[{"remove":{"name":"Send Request to Build via Jenkins"}} ,{"add":{"name":"Request Sent to Jenkins"}}]}}'  "https://digiwave.atlassian.net/rest/api/3/issue/$JIRA_TICKET"

      export nbr_processed_tickets=$((nbr_processed_tickets + 1))
      export BLDR_Info=${nbr_processed_tickets}" tickets"

   done
done

echo "BLDR_Info="${BLDR_Info} > $CIVL_WORK_DIR/returned_value.txt

if [ "$CIVL_LIST_TICKETS" == "" ]
then
   export CIVL_LIST_TICKETS="No tickets"
fi

echo "BLDR_DESC="${CIVL_LIST_TICKETS} > $CIVL_WORK_DIR/build_desc.txt

