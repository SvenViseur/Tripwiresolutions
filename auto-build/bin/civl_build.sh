#!/bin/bash
####
####
# Create date : 01 Apr 2019
# Create User : Sven Viseur
####
#
####
# Usage example:
# civl_build.sh --ticket <input file>
####
#First convert all with dos2unix 
find .. -type f -not -path '*/\.*' -type f \( ! -iname ".*" \) | grep -v .jar | xargs -I{} dos2unix {} 2> /dev/null

. ../cfg/${BLDR_Omgeving}_omgeving.cfg

OIFS=$IFS;
IFS=";";

IN_ODI_LIST=""
IN_DDL_LIST=""

echo "##############################"
echo "tns_admin info: ["$TNS_ADMIN"]"
echo "##############################"

######################################
### CHECK IF AUTO-BUILD IS ALLOWED ###
######################################

if [ -f $CIVL_HOME_CFG/autobuild.stop ]
then
  if [ ! "$BLDR_TicketID" == "DREAM-5441" ] && [ ! "$BLDR_TicketID" == "DREAM-5442" ] && [ ! "$BLDR_TicketID" == "DREAM-5558" ] && [ ! "$BLDR_TicketID" == "DREAM-5557" ] && [ ! "$BLDR_TicketID" == "DREAM-6158" ]  && [ ! "$BLDR_TicketID" == "DREAM-6190" ]  && [ ! "$BLDR_TicketID" ==  "EST-6117" ]   && [ ! "$BLDR_TicketID" ==  "EST-5978" ] && [ ! "$BLDR_TicketID" ==  "DREAM-7164" ] && [ ! "$BLDR_TicketID" ==  "EST-10215" ]

  then
    echo '##################################################'
    echo '###   AUTO-BUILD NOT ALLOWED FOR THIS MOMENT   ###'
    echo '##################################################'
    exit 1
  fi
fi

if [ "${BLDR_DeployShort}" == "NORMAL_DPLY" ]
then

   echo '###########################################'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q    Q  Q  C                      ###'
   echo '###   Q     Q Q  C                      ###'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###           Q                         ###'
   echo '###########################################'

   error_msg=""

   if [ "$BLDR_AutoDeployACC" == "Y" ] && [ "$BLDR_ReleaseType" != "Independent" ]
   then
      error_msg="[soort release] "$BLDR_ReleaseType" release wordt nooit dadelijk op ACC gedeployed (autodeploy)"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ReleaseType" != "Emergency" ]
   then
      if [ "BLDR_Deploytool" == "TRACEIT" ]
      then
        if [ "$BLDR_TIProject" == "" ] || [ "$BLDR_TIRelease" == "" ] || [ "$BLDR_TIProject" == "null" ] || [ "$BLDR_TIRelease" == "null" ]
        then
          error_msg="Lege informatie TraceIT Project en/of Release"
          propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
        fi
      fi
      if [ "$BLDR_Deploytool" == "4ME" ]
      then
        if [ "$BLDR_TIProjectID" == "" ] || [ "$BLDR_TIProjectID" == "null" ]
        then
          error_msg="Lege informatie 4ME Project ID"
          propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
        fi
      fi
   fi

   if [ "$BLDR_Assignee" == "" ]
   then
      error_msg="Ticket heeft geen Assignee toegekend gekregen"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Deploytool" == "" ]
   then
      error_msg="Deploy Tool is ongekend: selecteer TraceIT of 4me"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ODI_List" == "" ] && [ "$BLDR_DDL_List" == "" ]
   then
      error_msg="ODI lijst EN DDL lijst bevatten geen gegevens"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Stop_Env" == "" ]
   then
      error_msg="Stop Environment setting staat niet correct"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_AutoDeployACC" == "" ]
   then
      error_msg="Auto Deploy naar ACC setting staat niet correct"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [[ $BLDR_TIProject =~ ['–'] ]] || [[ $BLDR_TIRelease  =~ ['–'] ]]
   then
      error_msg="Release/Project bevat een verkeerd karakter"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$propertie_file_msg" != "" ]
   then
      echo '############################################'
      echo
      echo -e ${propertie_file_msg}  | awk '{ if ($0) print "ERROR QC: " $0; }'
      echo
      echo '############################################'
      echo '###   QC FAILED                          ###'
      echo '############################################'
      # build failed
      exit 1
   fi

   echo '############################################'
   echo '###   QC PASSED                          ###'
   echo '############################################'

   if [ ! -z "${BLDR_ODI_List// }" ]
   then
      IN_ODI_LIST=($BLDR_ODI_List);
   fi
   if [ ! -z "${BLDR_DDL_List// }" ]
   then
      IN_DDL_LIST=($BLDR_DDL_List);
   fi

#   echo "#################################################"
#   echo "DDL_LIST => [" $BLDR_DDL_List"]"
#   echo "#################################################"
#   echo "#################################################"
#   echo "ODI_LIST => [" $BLDR_ODI_List"]"
#   echo "#################################################"
#   echo "#################################################"
#   echo "TIOmschrijving => [" $BLDR_TIOmschrijving"]"
#   echo "#################################################"
   IFS=$OIFS;

   #create default directory structure
   ./civl_create_dir_struct_ticket.sh --ticket "$BLDR_TicketID"

   if [ ! -z "${BLDR_DDL_List// }" ]
   then


      echo '##################################################################################################'
      echo '###   DDDD        DDDD        L             BBBBBBB   U       U  IIIIIII  L        DDDD        ###'
      echo '###   D   D       D   D       L             B      B  U       U     I     L        D   D       ###'
      echo '###   D    D      D    D      L             B      B  U       U     I     L        D    D      ###'
      echo '###   D     D     D     D     L             BBBBBBB   U       U     I     L        D     D     ###'
      echo '###   D      D    D      D    L             B      B  U       U     I     L        D      D    ###'
      echo '###   D       D   D       D   L             B      B  U       U     I     L        D       D   ###'
      echo '###   DDDDDDDDD   DDDDDDDDD   LLLLLLLLL     BBBBBBB    UUUUUUU   IIIIIII  LLLLLLL  DDDDDDDDD   ###'
      echo '##################################################################################################'

      # create the sqllist file
      EXP_TGT_DDL=$CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/sql/$BLDR_TicketID/$BLDR_TicketID.dit

      echo > $EXP_TGT_DDL

      for i in "${IN_DDL_LIST[@]}"
      do
        if [ "${i// }" != "" ]
        then
           echo $i >> $EXP_TGT_DDL
        fi
      done

      #
      # Build the sql
      ./civl_build_ticket_release_sql.sh --ticket $BLDR_TicketID --sqllist $EXP_TGT_DDL --project $BLDR_Omgeving
      #
      script_err=$?

      if [ $script_err -gt 0 ]
      then
         exit $script_err
      fi

      echo '############################################'
      echo '###                                      ###'
      echo '###   END DDL BUILD                      ###'
      echo '###                                      ###'
      echo '############################################'


   fi

   if [ ! -z "${BLDR_ODI_List// }" ]
   then

      echo '###################################################################################################'
      echo '###    OOOOOOO   DDDD       IIIIIIIII        BBBBBBB   U       U  IIIIIII  L        DDDD        ###'
      echo '###   O       O  D   D          I            B      B  U       U     I     L        D   D       ###'
      echo '###   O       O  D    D         I            B      B  U       U     I     L        D    D      ###'
      echo '###   O       O  D     D        I            BBBBBBB   U       U     I     L        D     D     ###'
      echo '###   O       O  D      D       I            B      B  U       U     I     L        D      D    ###'
      echo '###   O       O  D       D      I            B      B  U       U     I     L        D       D   ###'
      echo '###    OOOOOOO   DDDDDDDDD  IIIIIIIII        BBBBBBB    UUUUUUU   IIIIIII  LLLLLLL  DDDDDDDDD   ###'
      echo '###################################################################################################'

      # create the odi export file
      EXP_TGT_ODI=$CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/odi/$BLDR_TicketID/$BLDR_TicketID.dat

      echo > $EXP_TGT_ODI

      for i in "${IN_ODI_LIST[@]}"
      do
        if [ "${i// }" != "" ];
        then
           echo $i >> $EXP_TGT_ODI
        fi
      done

      export TGT_DIR_MAIN=${CIVL_TARGET_DIR_MAIN}
      export TGT_BIN_DIR=${CIVL_HOME_DIR}

      # Switch to correct odi environment now
      . ../cfg/${BLDR_Omgeving}_omgeving_odi.cfg

      export SSHTargetUser=$UnixUserOnApplSrv
      export SSHTargetServer=${ODISERVER}
      export SCPDefaultOpts="-o StrictHostKeyChecking=no -p -r -i ${ODISSHKEY}"
      export SSHDefaultOpts="-t -t -o StrictHostKeyChecking=no -i ${ODISSHKEY}"

      export SCPSrcDirectory=${TGT_DIR_MAIN}/${BLDR_TicketID}
      export SCPTgtDirectory=${CIVL_BLDSRV_WORKSPACE}/${BLDR_TicketID}

      # Build the odi

      ## Doe een PING naar de ODI server
 #     ping -n 2 "${SSHTargetServer}" > /dev/null
 #     RC=$?
 #     if [ $RC -ne 0 ]; then
 #       echo "ERROR: Server ping failed for server ${SSHTargetServer}"
 #       exit 1
 #     else
 #       echo "INFO: Server ping successful ${SSHTargetServer}"
 #     fi

      #   echo "./civl_build_ticket_release_odi.sh --source $EXP_TGT_ODI --ticket $BLDR_TicketID --project $BLDR_Omgeving --env BLDR_Source"

      ####
      ## SSH command to cleanup the "target" workspace on the build odi linux server
      ####

      export SSHCommand="/bin/bash --login cleanupAutoBuild${BLDR_Omgeving}.sh"
	  
	  #export SSHCommand="/bin/bash --login  rm -rf ${CIVL_BLDSRV_WORKSPACE}; mkdir ${CIVL_BLDSRV_WORKSPACE}"

      ssh ${SSHDefaultOpts} ${SSHTargetUser}@${SSHTargetServer} ${SSHCommand}

      script_err=$?

      if [ $script_err -gt 0 ]
      then
          exit $script_err
      fi

      ####
      ## SCP command to copy the directories auto_build + <ticket>  from jenkins workspace to build odi linux server.
      ####

      export SCPSrcDirectory=${TGT_BIN_DIR}
      export SCPTgtDirectory=${CIVL_BLDSRV_WORKSPACE}/auto_build

      scp ${SCPDefaultOpts} ${SCPSrcDirectory} ${SSHTargetUser}@${SSHTargetServer}:${SCPTgtDirectory}

      export SCPSrcDirectory=${TGT_DIR_MAIN}/${BLDR_TicketID}
      export SCPTgtDirectory=${CIVL_BLDSRV_WORKSPACE}/${BLDR_TicketID}

      scp ${SCPDefaultOpts} ${SCPSrcDirectory} ${SSHTargetUser}@${SSHTargetServer}:${SCPTgtDirectory}

      script_err=$?

      if [ $script_err -gt 0 ]
      then
          exit $script_err
      fi

      ####
      ## SSH Launch now the build odi on the remote server
      ####
      SSH_EXP_TGT_ODI=${CIVL_BLDSRV_WORKSPACE}/${BLDR_TicketID}/odi/${BLDR_TicketID}/${BLDR_TicketID}.dat
      export SSHCommand="export DVL_ODI_BUILD_PSW=$DVL_ODI_BUILD_PSW;export DVL_ODI_BUILD_USR=$DVL_ODI_BUILD_USR;export DVL_ODI_MASTER_PSW=$DVL_ODI_MASTER_PSW;export DVL_ODI_MASTER_USR=$DVL_ODI_MASTER_USR;export SIC_ODI_BUILD_PSW=$SIC_ODI_BUILD_PSW;export SIC_ODI_BUILD_USR=$SIC_ODI_BUILD_USR;export SIC_ODI_MASTER_PSW=$SIC_ODI_MASTER_PSW;export SIC_ODI_MASTER_USR=$SIC_ODI_MASTER_USR; export BUILD_ID=$BUILD_ID; cd ${CIVL_BLDSRV_BIN_DIR}; /bin/bash --login ${CIVL_BLDSRV_BIN_DIR}/civl_build_ticket_release_odi.sh --source ${SSH_EXP_TGT_ODI} --ticket ${BLDR_TicketID} --project ${BLDR_Omgeving} --env ${BLDR_Source}"

      ssh ${SSHDefaultOpts} ${SSHTargetUser}@${SSHTargetServer} ${SSHCommand}
      script_err=$?

      if [ $script_err -gt 0 ]
      then
          exit $script_err
      fi

      #./civl_build_ticket_release_odi.sh --source $EXP_TGT_ODI --ticket $BLDR_TicketID --project $BLDR_Omgeving --env $BLDR_Source

      ####
      ## SCP command to copy the directories <ticket> from build odi linux server to jenkins workspace.
      ####

      export SCPTgtDirectory=${TGT_DIR_MAIN}
      export SCPSrcDirectory=${CIVL_BLDSRV_WORKSPACE}/${BLDR_TicketID}

      scp ${SCPDefaultOpts} ${SSHTargetUser}@${SSHTargetServer}:${SCPSrcDirectory} ${SCPTgtDirectory}

      script_err=$?

      if [ $script_err -gt 0 ]
      then
          exit $script_err
      fi

     echo '############################################'
     echo '###                                      ###'
     echo '###   END ODI NORMAL BUILD               ###'
     echo '###                                      ###'
     echo '############################################'

     unset GROOVY_CONF
     . ../cfg/${BLDR_Omgeving}_omgeving.cfg

   fi

   # Draaiboek voor Traceit (Zal later gebruikt worden)
   echo > $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report

   if [ "$BLDR_Stop_Env" == "Y" ]
   then
      echo "De installatie mag NIET starten alvorens de omgeving door het CIVL DevOps Team op non-actief is geplaatst" > $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report
   else
      echo > $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report
   fi

   echo "BLDR_BUILD_ID="$BUILD_ID >> $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties

   cp $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report $CIVL_TARGET_DIR_MAIN/Draaiboek_traceit.report
   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/${BLDR_TicketID}.properties

   ./civl_log_main.sh

   # Zip nu de output directory tot 1 zip file (odi + sql !!)
   cd $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID
   zip -r $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID".zip" ./*

   # Remove the properties file , only to be removed for the auto-build normal build !
   #rm -f $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties

fi

if [ "${BLDR_DeployShort}" == "ODI_STOP" ]
then

   echo '###########################################'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q    Q  Q  C                      ###'
   echo '###   Q     Q Q  C                      ###'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###           Q                         ###'
   echo '###########################################'

   error_msg=""

   if [ "$BLDR_AutoDeployACC" == "Y" ] && [ "$BLDR_ReleaseType" != "Independent" ]
   then
      error_msg="[soort release] "$BLDR_DeployType" wordt nooit dadelijk op ACC gedeployed (autodeploy)"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Deploytool" == "" ]
   then
      error_msg="Deploy Tool is ongekend: selecteer TraceIT of 4me"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi
   
   if [ "$BLDR_Assignee" == "" ]
   then
      error_msg="Ticket heeft geen Assignee toegekend gekregen"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ReleaseType" == "Emergency" ]
   then
      error_msg="Deze operatie is niet van toepassing voor Emergency deploys"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "BLDR_Deploytool" == "TRACEIT" ]
   then
     if [ "$BLDR_TIProject" == "" ] || [ "$BLDR_TIRelease" == "" ] || [ "$BLDR_TIProject" == "null" ] || [ "$BLDR_TIRelease" == "null" ]
     then
       error_msg="Lege informatie TraceIT Project en/of Release"
       propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
     fi

     if [[ $BLDR_TIProject =~ ['–'] ]] || [[ $BLDR_TIRelease  =~ ['–'] ]]
     then
       error_msg="Release/Project bevat een verkeerd karakter"
       propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
     fi
   fi
   if [ "$BLDR_Deploytool" == "4ME" ]
   then
     if [ "$BLDR_TIProjectID" == "" ] || [ "$BLDR_TIProjectID" == "null" ]
     then
       error_msg="Lege informatie 4ME Project ID"
       propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
     fi
   fi

   if [ "$propertie_file_msg" != "" ]
   then
      echo '############################################'
      echo
      echo -e ${propertie_file_msg}  | awk '{ if ($0) print "ERROR QC: " $0; }'
      echo
      echo '############################################'
      echo '###   QC FAILED                          ###'
      echo '############################################'
      # build failed
      exit 1
   fi

   echo '############################################'
   echo '###   QC PASSED                          ###'
   echo '############################################'


   echo '#######################################################################################'
   echo '###    OOOOOOO   DDDD       IIIIIIIII         SSSSSS   TTTTTTTTT   OOOOOO   PPPPPP  ###'
   echo '###   O       O  D   D          I            S             T      O      O  P     P ###'
   echo '###   O       O  D    D         I            S             T      O      O  P     P ###'
   echo '###   O       O  D     D        I             SSSSSS       T      O      O  PPPPPP  ###'
   echo '###   O       O  D      D       I                   S      T      O      O  P       ###'
   echo '###   O       O  D       D      I                   S      T      O      O  P       ###'
   echo '###    OOOOOOO   DDDDDDDDD  IIIIIIIII        SSSSSSS       T       OOOOOO   P       ###'
   echo '#######################################################################################'


   #create default directory structure
   ./civl_create_dir_struct_ticket.sh --ticket "$BLDR_TicketID"

   # copy default run now to ticket.aa file
   cat ${CIVL_HOME_CFG}/${BLDR_Omgeving}_STOP_ODI.defaultaa | sed "s/TI00000/${BLDR_TicketID}/g" > $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}_STOP_ODI.aa

   # copy default stop properties to ticket.scenactions file
   cat ${CIVL_HOME_CFG}/${BLDR_Omgeving}_STOP_ODI.defaultscenactions > $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}_STOP_ODI.scenactions

   # Draaiboek voor Traceit (Zal later gebruikt worden)
   echo > $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report

   echo "BLDR_BUILD_ID="$BUILD_ID >> $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties

   cp $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report $CIVL_TARGET_DIR_MAIN/Draaiboek_traceit.report
   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/${BLDR_TicketID}.properties

   ./civl_log_main.sh

   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties  $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.ticketinfo

   echo '############################################'
   echo '###                                      ###'
   echo '###   END ODI STOP BUILD                 ###'
   echo '###                                      ###'
   echo '############################################'

fi


if [ "${BLDR_DeployShort}" == "ODI_START" ]
then

   echo '###########################################'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q    Q  Q  C                      ###'
   echo '###   Q     Q Q  C                      ###'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###           Q                         ###'
   echo '###########################################'

   error_msg=""

   if [ "$BLDR_AutoDeployACC" == "Y" ] && [ "$BLDR_ReleaseType" != "Independent" ]
   then
      error_msg="[soort release] "$BLDR_DeployType" wordt nooit dadelijk op ACC gedeployed (autodeploy)"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Deploytool" == "" ]
   then
      error_msg="Deploy Tool is ongekend: selecteer TraceIT of 4me"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi
   
   if [ "$BLDR_Assignee" == "" ]
   then
      error_msg="Ticket heeft geen Assignee toegekend gekregen"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ReleaseType" == "Emergency" ]
   then
      error_msg="Deze operatie is niet van toepassing voor Emergency deploys"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "BLDR_Deploytool" == "TRACEIT" ]
   then
     if [ "$BLDR_TIProject" == "" ] || [ "$BLDR_TIRelease" == "" ] || [ "$BLDR_TIProject" == "null" ] || [ "$BLDR_TIRelease" == "null" ]
     then
       error_msg="Lege informatie TraceIT Project en/of Release"
       propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
     fi

     if [[ $BLDR_TIProject =~ ['–'] ]] || [[ $BLDR_TIRelease  =~ ['–'] ]]
     then
       error_msg="Release/Project bevat een verkeerd karakter"
       propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
     fi
   fi

   if [ "$BLDR_Deploytool" == "4ME" ]
   then
     if [ "$BLDR_TIProjectID" == "" ] || [ "$BLDR_TIProjectID" == "null" ]
     then
       error_msg="Lege informatie 4ME Project ID"
       propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
     fi
   fi

   if [ "$propertie_file_msg" != "" ]
   then
      echo '############################################'
      echo
      echo -e ${propertie_file_msg}  | awk '{ if ($0) print "ERROR QC: " $0; }'
      echo
      echo '############################################'
      echo '###   QC FAILED                          ###'
      echo '############################################'
      # build failed
      exit 1
   fi

   echo '############################################'
   echo '###   QC PASSED                          ###'
   echo '############################################'


   echo '##################################################################################################'
   echo '###    OOOOOOO   DDDD       IIIIIIIII         SSSSSS   TTTTTTTTT   AAAAAA   RRRRRR   TTTTTTTTT ###'
   echo '###   O       O  D   D          I            S             T      A      A  R     R      T     ###'
   echo '###   O       O  D    D         I            S             T      A      A  R     R      T     ###'
   echo '###   O       O  D     D        I             SSSSSS       T      AAAAAAAA  RRRRRR       T     ###'
   echo '###   O       O  D      D       I                   S      T      A      A  R  R         T     ###'
   echo '###   O       O  D       D      I                   S      T      A      A  R   R        T     ###'
   echo '###    OOOOOOO   DDDDDDDDD  IIIIIIIII        SSSSSSS       T      A      A  R    R       T     ###'
   echo '##################################################################################################'

   #create default directory structure
   ./civl_create_dir_struct_ticket.sh --ticket "$BLDR_TicketID"

   # copy default run now to ticket.aa file
   cat ${CIVL_HOME_CFG}/${BLDR_Omgeving}_START_ODI.defaultaa | sed "s/TI00000/${BLDR_TicketID}/g" > $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}_START_ODI.aa

   # copy default stop properties to ticket.scenactions file
   cat ${CIVL_HOME_CFG}/${BLDR_Omgeving}_START_ODI.defaultscenactions > $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}_START_ODI.scenactions

   # Draaiboek voor Traceit (Zal later gebruikt worden)
   echo > $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report

   echo "BLDR_BUILD_ID="$BUILD_ID >> $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties

   cp $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report $CIVL_TARGET_DIR_MAIN/Draaiboek_traceit.report
   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/${BLDR_TicketID}.properties

   ./civl_log_main.sh

   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties  $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.ticketinfo

   echo '############################################'
   echo '###                                      ###'
   echo '###   END ODI START BUILD                ###'
   echo '###                                      ###'
   echo '############################################'

fi

if [ "${BLDR_DeployShort}" == "ODI_RUN" ]
then

   echo '###########################################'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q    Q  Q  C                      ###'
   echo '###   Q     Q Q  C                      ###'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###           Q                         ###'
   echo '###########################################'

   error_msg=""

   if [ "$BLDR_AutoDeployACC" == "Y" ] && [ "$BLDR_ReleaseType" != "Independent" ]
   then
      error_msg="[soort release] "$BLDR_ReleaseType" release wordt nooit dadelijk op ACC gedeployed (autodeploy)"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ReleaseType" != "Emergency" ]
   then
     if [ "BLDR_Deploytool" == "TRACEIT" ]
     then
       if [ "$BLDR_TIProject" == "" ] || [ "$BLDR_TIRelease" == "" ] || [ "$BLDR_TIProject" == "null" ] || [ "$BLDR_TIRelease" == "null" ]
       then
         error_msg="Lege informatie TraceIT Project en/of Release"
         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
       fi

       if [[ $BLDR_TIProject =~ ['–'] ]] || [[ $BLDR_TIRelease  =~ ['–'] ]]
       then
         error_msg="Release/Project bevat een verkeerd karakter"
         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
       fi
     fi
     if [ "$BLDR_Deploytool" == "4ME" ]
     then
       if [ "$BLDR_TIProjectID" == "" ] || [ "$BLDR_TIProjectID" == "null" ]
       then
         error_msg="Lege informatie 4ME Project ID"
         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
       fi
     fi

   fi

   if [ "$BLDR_Deploytool" == "" ]
   then
      error_msg="Deploy Tool is ongekend: selecteer TraceIT of 4me"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Assignee" == "" ]
   then
      error_msg="Ticket heeft geen Assignee toegekend gekregen"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ODI_List" == "" ]
   then
      error_msg="ODI lijst bevat geen gegevens"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Stop_Env" == "" ]
   then
      error_msg="Stop Environment setting staat niet correct"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_AutoDeployACC" == "" ]
   then
      error_msg="Auto Deploy naar ACC setting staat niet correct"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$propertie_file_msg" != "" ]
   then
      echo '############################################'
      echo
      echo -e ${propertie_file_msg}  | awk '{ if ($0) print "ERROR QC: " $0; }'
      echo
      echo '############################################'
      echo '###   QC FAILED                          ###'
      echo '############################################'
      # build failed
      exit 1
   fi

   echo '############################################'
   echo '###   QC PASSED                          ###'
   echo '############################################'

   if [ ! -z "${BLDR_ODI_List// }" ]
   then
      IN_ODI_LIST=($BLDR_ODI_List);
   fi

   IFS=$OIFS;

   #create default directory structure
   ./civl_create_dir_struct_ticket.sh --ticket "$BLDR_TicketID"

   if [ ! -z "${BLDR_ODI_List// }" ]
   then

      echo '###############################################################################'
      echo '###    OOOOOOO   DDDD       IIIIIIIII        RRRRRRR   U       U  NN     N  ###'
      echo '###   O       O  D   D          I            R      R  U       U  N N    N  ###'
      echo '###   O       O  D    D         I            R      R  U       U  N  N   N  ###'
      echo '###   O       O  D     D        I            RRRRRRR   U       U  N   N  N  ###'
      echo '###   O       O  D      D       I            R   R     U       U  N    N N  ###'
      echo '###   O       O  D       D      I            R    R    U       U  N     NN  ###'
      echo '###    OOOOOOO   DDDDDDDDD  IIIIIIIII        R     R    UUUUUUU   N      N  ###'
      echo '###############################################################################'

      # copy default run now to ticket.aa file
      cat ${CIVL_HOME_CFG}/${BLDR_Omgeving}_RUN_ODI.defaultaa | sed "s/TI00000/${BLDR_TicketID}/g" > $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}_RUN_ODI.aa

      # create now the odi run properties file
      EXP_PROP_ODI=$CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}_RUN_ODI.scenactions

      echo > $EXP_PROP_ODI

      for i in "${IN_ODI_LIST[@]}"
      do
        if [ "${i// }" != "" ];
        then

           # check number of occurences of the # character

           if [ "${BLDR_Omgeving}" = "CIVL" ]
           then
              annex_lijn="#GLOBAL#CIVLOracleDIAgent5#6#Y"
           else
              annex_lijn="#GLOBAL#OracleDIAgent1#6#Y"
           fi

           nbr_char=$(echo ${i} | tr -d -c '#' | wc -c)
           if [ ${nbr_char} -eq 0 ]
           then
              final_lijn=${i}${annex_lijn}
           else
              final_lijn=${i}
           fi
           echo ${final_lijn}
           echo ${final_lijn} >> $EXP_PROP_ODI

        fi
      done

   fi

   # Draaiboek voor Traceit (Zal later gebruikt worden)
   echo > $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report

   echo "BLDR_BUILD_ID="$BUILD_ID >> $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties

   cp $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report $CIVL_TARGET_DIR_MAIN/Draaiboek_traceit.report
   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/${BLDR_TicketID}.properties

   ./civl_log_main.sh

   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties  $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.ticketinfo

   echo '############################################'
   echo '###                                      ###'
   echo '###   END ODI RUN BUILD                  ###'
   echo '###                                      ###'
   echo '############################################'

fi

if [ "${BLDR_DeployShort}" == "DML_RUN" ]
then

   echo '###########################################'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q       Q  C                      ###'
   echo '###   Q    Q  Q  C                      ###'
   echo '###   Q     Q Q  C                      ###'
   echo '###    QQQQQQQ    CCCCCCCC              ###'
   echo '###           Q                         ###'
   echo '###########################################'

   error_msg=""

   if [ "$BLDR_AutoDeployACC" == "Y" ] && [ "$BLDR_ReleaseType" != "Independent" ]
   then
      error_msg="[soort release] "$BLDR_ReleaseType" release wordt nooit dadelijk op ACC gedeployed (autodeploy)"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ReleaseType" != "Emergency" ]
   then
     if [ "BLDR_Deploytool" == "TRACEIT" ]
     then
       if [ "$BLDR_TIProject" == "" ] || [ "$BLDR_TIRelease" == "" ] || [ "$BLDR_TIProject" == "null" ] || [ "$BLDR_TIRelease" == "null" ]
       then
         error_msg="Lege informatie TraceIT Project en/of Release"
         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
       fi

       if [[ $BLDR_TIProject =~ ['–'] ]] || [[ $BLDR_TIRelease  =~ ['–'] ]]
       then
         error_msg="Release/Project bevat een verkeerd karakter"
         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
       fi
     fi
     if [ "$BLDR_Deploytool" == "4ME" ]
     then
       if [ "$BLDR_TIProjectID" == "" ] || [ "$BLDR_TIProjectID" == "null" ]
       then
         error_msg="Lege informatie 4ME Project ID"
         propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
       fi
     fi
   fi

   if [ "$BLDR_Deploytool" == "" ]
   then
      error_msg="Deploy Tool is ongekend: selecteer TraceIT of 4me"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_ODI_List" == "" ] && [ "$BLDR_DDL_List" == "" ]
   then
      error_msg="ODI lijst EN DDL lijst bevatten geen gegevens"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Stop_Env" == "" ]
   then
      error_msg="Stop Environment setting staat niet correct"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_AutoDeployACC" == "" ]
   then
      error_msg="Auto Deploy naar ACC setting staat niet correct"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$BLDR_Assignee" == "" ]
   then
      error_msg="Ticket heeft geen Assignee toegekend gekregen"
      propertie_file_msg="${propertie_file_msg}"$'\\r\\n'"${error_msg}"
   fi

   if [ "$propertie_file_msg" != "" ]
   then
      echo '############################################'
      echo
      echo -e ${propertie_file_msg}  | awk '{ if ($0) print "ERROR QC: " $0; }'
      echo
      echo '############################################'
      echo '###   QC FAILED                          ###'
      echo '############################################'
      # build failed
      exit 1
   fi

   echo '############################################'
   echo '###   QC PASSED                          ###'
   echo '############################################'

   if [ ! -z "${BLDR_ODI_List// }" ]
   then
      IN_ODI_LIST=($BLDR_ODI_List);
   fi
   if [ ! -z "${BLDR_DDL_List// }" ]
   then
      IN_DDL_LIST=($BLDR_DDL_List);
   fi

   IFS=$OIFS;

   #create default directory structure
   ./civl_create_dir_struct_ticket.sh --ticket "$BLDR_TicketID"

   if [ ! -z "${BLDR_DDL_List// }" ]
   then

      echo '###########################################'
      echo '###   DDDD       MMM    MMM  L          ###'
      echo '###   D   D      M  M   M M  L          ###'
      echo '###   D    D     M   M M  M  L          ###'
      echo '###   D     D    M    M   M  L          ###'
      echo '###   D      D   M        M  L          ###'
      echo '###   D       D  M        M  L          ###'
      echo '###   DDDDDDDDD  M        M  LLLLLLLLL  ###'
      echo '###########################################'


      # create the sqllist file
      EXP_TGT_DDL=$CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/sql/$BLDR_TicketID/$BLDR_TicketID.dit

      echo > $EXP_TGT_DDL

      for i in "${IN_DDL_LIST[@]}"
      do
        if [ "${i// }" != "" ]
        then
           echo $i >> $EXP_TGT_DDL
        fi
      done

      #
      # Build the sql
      ./civl_build_ticket_release_sql.sh --ticket $BLDR_TicketID --sqllist $EXP_TGT_DDL --project $BLDR_Omgeving
      #
      script_err=$?

      if [ $script_err -gt 0 ]
      then
         exit $script_err
      fi

      echo '############################################'
      echo '###                                      ###'
      echo '###   END DML BUILD                      ###'
      echo '###                                      ###'
      echo '############################################'
   fi

   # Draaiboek voor Traceit (Zal later gebruikt worden)
   echo > $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report

   echo "BLDR_BUILD_ID="$BUILD_ID >> $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties

   cp $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/Draaiboek_traceit.report $CIVL_TARGET_DIR_MAIN/Draaiboek_traceit.report
   cp $CIVL_TARGET_DIR_MAIN/${BLDR_TicketID}.properties $CIVL_TARGET_DIR_MAIN/$BLDR_TicketID/parameters/${BLDR_TicketID}.properties

   ./civl_log_main.sh

fi

echo "INFO: Ticket build done"
