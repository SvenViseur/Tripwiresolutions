#!/bin/bash

export JIRA_TICKET=""

while [ $# -ne 0 ]
do
case "$1" in
  "--ticket")
    shift
    export JIRA_TICKET=$1
    ;;
esac
shift
done

if [ "$JIRA_TICKET" = "" ]
then
    echo "parameters incorrect."
    echo "usage: --ticket <JIRA_TICKET>"
    exit 1
fi

curl -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=key%20%3D%20%22"$JIRA_TICKET"%22AND%20issuetype%20in%20(Story%2CBug%2CEnabler%2CMaintenance%2CTask%2CSub-task)%20&startAt=0&maxResults=1" > ${JIRA_TICKET}.tmp

groovy JIRA_BUILD.groovy -f ${JIRA_TICKET}.tmp -o ${JIRA_TICKET}.properties -t issue -b Y

#Get EPIC Info

#epic_key=$(cat ${JIRA_TICKET}.properties | grep BLDR_Epic | cut -d "=" -f2)
#echo $epic_key

#get epic info
#curl -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=key=%20%22$epic_key%22&startAt=0&maxResults=1" > ${JIRA_TICKET}.epicinfo

### "customfield_10084": "PR004132 - CIVL 2.0 MAJOR IVL R3 Bron Changes", --> release
### "customfield_10085": "PR004132 - CIVL 2.0 MAJOR IVL R3 Bron Changes", --> project
### "customfield_10096": 77328.0, --> project id

#groovy JIRA_BUILD.groovy -f ${JIRA_TICKET}.epicinfo -o ${JIRA_TICKET}.properties -t epic

#rm -f ${JIRA_TICKET}.tmp
#rm -f ${JIRA_TICKET}.epicinfo
