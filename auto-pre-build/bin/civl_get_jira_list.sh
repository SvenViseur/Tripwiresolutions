#!/bin/bash

. $HOME/.bash_profile

logfile=$HOME/civl_release/prd/bin_prebuilder/bin/loginfo.log

subversion_dir=$HOME/subversion

omgevingen[0]="CIVL"
omgevingen[1]="IVL"

for omgeving in "${omgevingen[@]}"
do

#   jira_tickets=($(curl -s -k -u systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=issuetype%20in%20(Story%2CBug%2CEnabler%2CMaintenance%2CTask%2CSub-task%2CProblem%2CTest%20Defect)%20AND%20Fixversion%3D%20%22Send%20Request%20to%20Build%20via%20Jenkins%22%20AND%20Repository%20%3D%20%22$omgeving%22&startAt=0&maxResults=500&fields=key" | python -m json.tool | grep "\"key\"\:" | cut -d ":" -f2 | sed "s/,//g" | sed "s/\"//g" | sed "s/ //g"))

   jira_tickets=($( curl -s -k -u systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=issuetype%20in%20(%22Story%22%2C%22Bug%22%2C%22Enabler%22%2C%22Maintenance%22%2C%22Task%22%2C%22Sub-task%22%2C%22Problem%22%2C%22Test%20Defect%22)%20AND%20Fixversion%3D%20%22Send%20Request%20to%20Build%20via%20Jenkins%22%20AND%20Repository%20%3D%20%22$omgeving%22&startAt=0&maxResults=500&fields=key" | python -m json.tool | grep "\"key\"\:" | cut -d ":" -f2 | sed "s/,//g" | sed "s/\"//g" | sed "s/ //g"))

   for JIRA_TICKET in "${jira_tickets[@]}"
   do

echo  $(date "+%m/%d/%y %H:%M:%S") ": Omgeving: "$omgeving" - ticket : "$JIRA_TICKET>> $logfile

      # Maak een directory aan met het ID van het ticket in de juiste subversion omgeving

      cd $HOME/civl_release/prd/bin_prebuilder/bin
      output_dir=$HOME/civl_release/prd/bin_prebuilder/work_dir
      subversion_dir=$HOME/subversion/$omgeving/jenkins_release_input

# Get the ticket info from JIRA
      curl -s -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=key%20%3D%20%22"$JIRA_TICKET"%22&startAt=0&maxResults=1" > $output_dir/${JIRA_TICKET}.tmp

# Create now the property file based on the json file from JIRA
      groovy JIRA_BUILD.groovy -f $output_dir/${JIRA_TICKET}.tmp -o $output_dir/${JIRA_TICKET}.properties  -t issue -b Y

# Check if all data is correct
#      export BLDR_Stop_Env=$(cat $output_dir/$JIRA_TICKET.properties | grep "BLDR_Stop_Env" | cut -d "=" -f 2)
#      export BLDR_TIProject=$(cat ${output_dir}/${JIRA_TICKET}.properties | grep "BLDR_TIProject" | cut -d "=" -f 2)
#      export BLDR_TIRelease=$(cat ${output_dir}/${JIRA_TICKET}.properties | grep "BLDR_TIRelease" | cut -d "=" -f 2)
#      export BLDR_TIProjectID=$(cat ${output_dir}/${JIRA_TICKET}.properties | grep "BLDR_TIProjectID" | cut -d "=" -f 2)
#      export BLDR_ReleaseType=$(cat ${output_dir}/${JIRA_TICKET}.properties | grep "BLDR_ReleaseType" | cut -d "=" -f 2)
#      export BLDR_AutoDeployACC=$(cat ${output_dir}/${JIRA_TICKET}.properties | grep "BLDR_AutoDeployACC" | cut -d "=" -f 2)
#
#      export propertie_file_msg=""
#
#      if [ "$BLDR_AutoDeployACC" == "Y" ] && [ "$BLDR_ReleaseType" == "Major" ]
#      then
#         error_msg="Major release wordt niet dadelijk op ACC gedeployed"
#         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
#      fi
#
#      if [ "$BLDR_TIProject" == "" ] || [ "$BLDR_TIRelease" == "" ] || [ "$BLDR_TIProject" == "null" ] || [ "$BLDR_TIRelease" == "null" ]
#      then
#         error_msg="Ongekend TraceIT Project of Release"
#         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
#      fi
      
#      if [ "$propertie_file_msg" != "" ]
#      then
#
#        printf -v data  '{"body": "Error for Jenkins Build:  %s"}' "$propertie_file_msg"
#        # Add a comment with error message
#        curl -s -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X POST --data "$data" "https://digiwave.atlassian.net/rest/api/2/issue/$JIRA_TICKET/comment"
#
#        # Empty request on JIRA
#        curl -s -k -u systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X PUT --data '{"update":{"fixVersions":[{"remove":{"name":"Send Request to Build via Jenkins"}}]}}'  "https://digiwave.atlassian.net/rest/api/3/issue/$JIRA_TICKET"
#
#      else

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
        cp $output_dir/${JIRA_TICKET}.properties $subversion_dir/$JIRA_TICKET/${JIRA_TICKET}.properties
        rm -f $output_dir/${JIRA_TICKET}.tmp
        rm -f $output_dir/${JIRA_TICKET}.properties
        rm -f $output_dir/${JIRA_TICKET}.epicinfo

        cd $subversion_dir
        svn update
        svn cleanup
        svn add $JIRA_TICKET/ --force
        svn commit $JIRA_TICKET/  --force-log -m "$JIRA_TICKET"

         # Update the JIRA now to remove it from the FixVersion 
        curl -s -k -u systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X PUT --data '{"update":{"fixVersions":[{"remove":{"name":"Send Request to Build via Jenkins"}} ,{"add":{"name":"Request Sent to Jenkins"}}]}}'  "https://digiwave.atlassian.net/rest/api/3/issue/$JIRA_TICKET"
#      fi
   done
done

