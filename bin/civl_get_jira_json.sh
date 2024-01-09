#!/bin/bash

export JIRA_TICKET=$INPUT_BUILD_JIRA_TICKET

if [ "$JIRA_TICKET" = "" ]
then
    echo "missing ticket id."
    exit 1
fi

export N_WORKSPACE=$(echo "/"$WORKSPACE | tr '\\' '/' | sed "s/://g")

curl -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=key%20%3D%20%22"$JIRA_TICKET"%22AND%20issuetype%20in%20(Story%2CBug%2CEnabler%2CMaintenance%2CTask%2CSub-task)%20&startAt=0&maxResults=1" > ${JIRA_TICKET}.tmp

echo "civl_get_jira_json.groovy -f ${JIRA_TICKET}.tmp -o ${JIRA_TICKET}.properties -t issue -b Y"

groovy ../groovy_scripts/civl_get_jira_json.groovy -f ${JIRA_TICKET}.tmp -o ${JIRA_TICKET}.properties -t issue -b Y

if [ -f ${JIRA_TICKET}.properties ]
then

mv ${JIRA_TICKET}.properties $N_WORKSPACE/${JIRA_TICKET}.properties

fi

#rm -f ${JIRA_TICKET}.tmp

