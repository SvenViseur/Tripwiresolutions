
. ../cfg/${BLDR_Omgeving}_omgeving.cfg

# Bijkomend de log informatie
# Niet gebruiken binnen nieuwe setup wegens groovy op een aparte machine gebeurt

. ./civl_orasecurity.sh -s RMC

export RMC_TRACEIT="0"

if [ -f $CIVL_TARGET_DIR_MAIN/traceit.properties ]
then
   export RMC_TRACEIT=$(cat $CIVL_TARGET_DIR_MAIN/traceit.properties | grep -i "^ticketnr" | cut -d "=" -f2)
   echo "BLDR_TRACEIT="$RMC_TRACEIT >> $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties
   export RMC_DB_URL=$ora_srv
   groovy $CIVL_GROOVY_SCRIPTS/civl_register_properties.groovy -f  $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties -t ${RMC_TRACEIT} -r 0

   if [ "$BLDR_Deploytool" == "4ME" ]
   then
     # Check if there are any weblinks with the title = '4ME - Change with ID'
     export WEBLINK_TEXT="4ME - Change "${RMC_TRACEIT}
     export WEBLINK_URL="https://cio-argenta.4me.com/workflows/${RMC_TRACEIT}"

#     echo "Weblink to create: "$WEBLINK_URL

     #Get the id of the weblink if exist
	 
#	 echo "export ids=$(curl -s -k -u $USER_JIRA_SYSTEMTEAMESPERANTO:$PSW_JIRA_SYSTEMTEAMESPERANTO  -X GET -H "Content-Type: application/json" "https://digiwave.atlassian.net/rest/api/2/issue/${BLDR_TicketID}/remotelink" | sed -e "s/,/,\n/g" | egrep "id|title" | sed -e "s/\[//g" | sed "s/{//g" | sed 'N;s/\n/ /' | grep "${WEBLINK_TEXT}" | cut -d ":" -f 2 | cut -d "," -f 1 | sed 's/^ *//g')"
	 
     export ids=$(curl -s -k -u $JIRA_SYSTEMTEAMESPERANTO_USR:$JIRA_SYSTEMTEAMESPERANTO_PSW  -X GET -H "Content-Type: application/json" "https://digiwave.atlassian.net/rest/api/2/issue/${BLDR_TicketID}/remotelink" | sed -e "s/,/,\n/g" | egrep "id|title" | sed -e "s/\[//g" | sed "s/{//g" | sed 'N;s/\n/ /' | grep "${WEBLINK_TEXT}" | cut -d ":" -f 2 | cut -d "," -f 1 | sed 's/^ *//g')

     for id_to_remove in $(echo $ids | sed "s/ /\n/g")
     do
       curl -s -k -u $JIRA_SYSTEMTEAMESPERANTO_USR:$JIRA_SYSTEMTEAMESPERANTO_PSW -X DELETE -H "Content-Type: application/json" "https://digiwave.atlassian.net/rest/api/2/issue/${BLDR_TicketID}/remotelink/${id_to_remove}"
     done

     #Create the weblink now
     printf -v data '{
    "object": {
        "url":"%s",
        "title":"%s",
        "icon":{"url16x16":"https://cio-argenta.4me.com/favicon.ico"},
        "status":{"icon":{}}
     }
}
' "$WEBLINK_URL" "$WEBLINK_TEXT"

#    echo "data is:"
#	 echo $data
#echo "curl -s -k -u $JIRA_SYSTEMTEAMESPERANTO_USR:$JIRA_SYSTEMTEAMESPERANTO_PSW -X POST --data "$data" -H "Content-Type: application/json" "https://digiwave.atlassian.net/rest/api/3/issue/${BLDR_TicketID}/remotelink""

     curl -s -k -u $JIRA_SYSTEMTEAMESPERANTO_USR:$JIRA_SYSTEMTEAMESPERANTO_PSW -X POST --data "$data" -H "Content-Type: application/json" "https://digiwave.atlassian.net/rest/api/3/issue/${BLDR_TicketID}/remotelink"

   fi

fi

#export RMC_DB_URL=$ora_srv
#groovy $CIVL_GROOVY_SCRIPTS/civl_register_properties.groovy -f  $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties -t ${RMC_TRACEIT}
#groovy $CIVL_GROOVY_SCRIPTS/civl_register_odi.groovy -fh $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/odi/$BLDR_TicketID/$BLDR_TicketID.odiinfo -fd $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/odi/$BLDR_TicketID/$BLDR_TicketID.detailodiinfo -t ${RMC_TRACEIT}


