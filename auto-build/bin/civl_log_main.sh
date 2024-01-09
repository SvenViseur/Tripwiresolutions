
. ../cfg/${BLDR_Omgeving}_omgeving.cfg

# Bijkomend de log informatie
# Niet gebruiken binnen nieuwe setup wegens groovy op een aparte machine gebeurt

. ./civl_orasecurity.sh -s RMC

export RMC_TRACEIT="0"

if [ -f $CIVL_TARGET_DIR_MAIN/traceit.properties ]
then
   export RMC_TRACEIT=$(cat $CIVL_TARGET_DIR_MAIN/traceit.properties | grep -i "^ticketnr" | cut -d "=" -f2)
   echo "BLDR_TRACEIT="$RMC_TRACEIT >> $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties
fi

export RMC_DB_URL=$ora_srv
groovy $CIVL_GROOVY_SCRIPTS/civl_register_properties.groovy -f  $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties -t ${RMC_TRACEIT} -r 0
groovy $CIVL_GROOVY_SCRIPTS/civl_register_odi.groovy -fh $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/odi/$BLDR_TicketID/$BLDR_TicketID.odiinfo -fd $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/odi/$BLDR_TicketID/$BLDR_TicketID.detailodiinfo -t ${RMC_TRACEIT} -r 0
groovy $CIVL_GROOVY_SCRIPTS/civl_register_sql.groovy -fd $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/sql/$BLDR_TicketID/${BLDR_TicketID}.sqldetailinfo -t ${RMC_TRACEIT} -r 0

