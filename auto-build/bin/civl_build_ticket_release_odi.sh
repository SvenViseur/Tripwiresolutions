#!/bin/bash

#. ../cfg/CIVL_omgeving_odi.cfg

export CIVL_PARAMS=$@

#set > ../log/settings_ODI.log

unset CLASSPATH

CIVL_SOURCE=""
CIVL_RELEASE=""
CIVL_LP_SKIP=""
CIVL_PROJECT=IVL

while [ $# -ne 0 ]
do
case "$1" in
  "--source")
    shift
    export CIVL_SOURCE=$1
    shift
    ;;
  "--ticket")
    shift
    export CIVL_TICKET=$1
    shift
    ;;
  "--skip_lp")
    shift
    export CIVL_LP_SKIP=$1
    shift
    ;;
  "--env")
    shift
    export CIVL_ENV=$1
    shift
    ;;
  "--project")
    shift
    export CIVL_PROJECT=$1
    shift
    ;;
  *)
    echo "ERROR: parameters incorrect."
	echo "ERROR: usage: --source <source_file> --ticket <release_number> --skip_lp <Yes/No> --project <IVL|CIVL> --env <IVL_DEV>"
        exit 1
    ;;
esac
done

if [ "$CIVL_SOURCE" = "" ] | [ "$CIVL_TICKET" = "" ]
then
    echo "ERROR: parameters incorrect."
        echo "ERROR: usage: --source <source_file> --ticket <release_number> --skip_lp <Yes/No> --project <IVL|CIVL> --env <IVL_DEV>"
        exit 1
fi

echo "----------------------------------------"
echo "-----------    "$CIVL_TICKET"    ----------"
echo "----------------------------------------"
echo "INFO: "$(date "+%m/%d/%y %H:%M:%S")  " : Start release : "$CIVL_TICKET" - Source: "$CIVL_SOURCE 
echo "INFO: "$(date "+%m/%d/%y %H:%M:%S")  " : Parameters given : "$CIVL_PARAMS 

export CIVL_WORK=$CIVL_SOURCE.wrk

echo "########################################################"
echo "INFO: tns_admin info on odi machine : ["$TNS_ADMIN"]"
echo "########################################################"

#echo $CIVL_SOURCE
dos2unix $CIVL_SOURCE 2> /dev/null

# Add comment release build

#  printf -v data  '{"body": "Release ODI build started for ticket %s"}' "$CIVL_TICKET"
#  curl -s -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X POST --data "$data" "https://digiwave.atlassian.net/rest/api/2/issue/$CIVL_TICKET/comment"

#echo $CIVL_TICKET

export CIVL_CFG_FILE=$CIVL_PROJECT"_omgeving_odi.cfg"

# Dynamische config file op basis van het project (meegegeven als parameter)
# Bepaalt dan ook de juiste repository die moet benadert worden

#. $CIVL_HOME_CFG/$CIVL_CFG_FILE

. ../cfg/$CIVL_CFG_FILE


export CIVL_PATH=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/odi/$CIVL_TICKET
export oraLogDir=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/log
export CIVL_TMP_DIR=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/wrk_tmp

echo "#################"
echo "# Groovy Info : #"
echo "#################"
echo "INFO: "$(groovy --version)
echo "#################"
#cat $GROOVY_CONF
#echo "#################"

#All settings are now correct

#Add by default IVL_LP_ + release as the Loadplan needs to be in place also
# Added also the LF before the IVL_LP !!

if [ "$CIVL_LP_SKIP" = "No" ]; then
echo '
IVL_LP_'$CIVL_TICKET >> $CIVL_SOURCE
fi

#Copy source to source.wrk
cp $CIVL_SOURCE $CIVL_WORK
cp $CIVL_SOURCE $CIVL_SOURCE".orig"

# Keep only unique values
# Remove empty lines
# Remove white spaces
# Replace upper PHYSICAL to Physical
# Replace upper INITIAL_LOAD to Initial_Load
cat $CIVL_WORK | sort | uniq | sed '/^IVL_S/ s=INITIAL_LOAD=Initial_Load=g' | sed '/^IVL_S/ s=PHYSICAL=Physical=g' | sed 's/ //g' | sed '/^$/d' > $CIVL_SOURCE

export CIVL_CHECK=0
export CIVL_ERRORS=0

######################################
# How to make diff between DVL & SIC #
######################################

. ./civl_odisecurity.sh -s $CIVL_PROJECT"_"$CIVL_ENV"_"$CIVL_ENV

########################################################################

export ODI_MASTER_USR=$(eval echo \$$CIVL_ENV"_ODI_MASTER_USR")
export ODI_MASTER_PSW=$(eval echo \$$CIVL_ENV"_ODI_MASTER_PSW")
export ODI_USR=$(eval echo \$$CIVL_ENV"_ODI_BUILD_USR")
export ODI_PSW=$(eval echo \$$CIVL_ENV"_ODI_BUILD_PSW")


echo "####################################################"
echo "### CHECK IF OBJECTS EXIST                       ###"
echo "####################################################"
echo "INFO: "$(date "+%m/%d/%y %H:%M:%S") " : Start checking ... "

#java -version

# export settings temporary
# echo "###################################################"
# echo "### SETTINGS ODI MACHINE                        ###"
# echo "###################################################"
# set 

# Added -c as=> only check no create

# echo "groovy $CIVL_GROOVY_SCRIPTS/civl_createDeployArchive.groovy  -d $CIVL_TICKET -p $CIVL_PATH -f $CIVL_TICKET.zip -l LP_$CIVL_TICKET.zip -n $CIVL_TICKET -e $CIVL_PROJECT -b $BUILD_ID -c"
groovy $CIVL_GROOVY_SCRIPTS/civl_createDeployArchive.groovy  -d $CIVL_TICKET -p $CIVL_PATH -f $CIVL_TICKET.zip -l LP_$CIVL_TICKET.zip -n $CIVL_TICKET -e $CIVL_PROJECT -b $BUILD_ID -c < $CIVL_SOURCE 
#2> /dev/null

export CIVL_CHECK=$?

if [ "$CIVL_CHECK" == "0" ]
 then

 echo "####################################################"
 echo "### REGENERATING SCENARIOS                       ###"
 echo "####################################################"

 echo $(date "+%m/%d/%y %H:%M:%S") " : Start regenerating scenarios ... "

 groovy $CIVL_GROOVY_SCRIPTS/civl_regenerate_scenarios_list.groovy < $CIVL_SOURCE 2> /dev/null
else
   echo  $(date "+%m/%d/%y %H:%M:%S") "Objects missing in  .dat file (are you sure these are scenarios or loadplan?)" 
#   cp $oraLogDir/* $CIVL_LOG_DIR/.
   exit $CIVL_CHECK
fi

export CIVL_CHECK=$?

if [ "$CIVL_CHECK" == "0" ]
 then

   echo "####################################################"
   echo "### START CREATING DEPLOYMENT ARCHIVE            ###"
   echo "####################################################"

   echo "INFO: "$(date "+%m/%d/%y %H:%M:%S") " : Start creating ... "

   # start Create deploy archive

   #echo "groovy $CIVL_GROOVY_SCRIPTS/civl_createDeployArchive.groovy  -d $CIVL_TICKET -p $CIVL_PATH -f $CIVL_TICKET.zip -l LP_$CIVL_TICKET.zip -n "$CIVL_TICKET"_$(date +"%Y%m%d") -e $CIVL_PROJECT"
   groovy $CIVL_GROOVY_SCRIPTS/civl_createDeployArchive.groovy  -d $CIVL_TICKET -p $CIVL_PATH -f $CIVL_TICKET.zip -l LP_$CIVL_TICKET.zip -n "$CIVL_TICKET"_$(date +"%Y%m%d") -e $CIVL_PROJECT -b $BUILD_ID  < $CIVL_SOURCE 2> /dev/null
   export CIVL_ERRORS=$1
else
   echo  $(date "+%m/%d/%y %H:%M:%S") " objects not existing in .dat file" 
#   cp $oraLogDir/* $CIVL_LOG_DIR/.
   exit $CIVL_CHECK
fi

RELEASE_ORDER=$CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/wrk_tmp/$CIVL_TICKET.lst_srt
echo "10.0|"$CIVL_TICKET > $RELEASE_ORDER

echo $CIVL_TICKET > $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/parameters/ODI_execution_order.txt

echo $CIVL_PROJECT > $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET/parameters/ODI_target_repository.txt

if [ "$CIVL_ERRORS" == "" ]
then
  echo $(date "+%m/%d/%y %H:%M:%S") " : Release "$CIVL_TICKET" ready !! ... " 
  echo "Release "$CIVL_TICKET" ready !!"
else
  echo $(date "+%m/%d/%y %H:%M:%S") " : Error in checking module for release "$CIVL_TICKET 
  echo "Error in checking module for release "$CIVL_TICKET
  echo $CIVL_ERRORS
fi

# Return to original dat file but keep the work to be re-copied to the /IVL/09_ directory
rm -f $CIVL_SOURCE".orig"
rm -f $CIVL_WORK

#cp $oraLogDir/* $CIVL_LOG_DIR/.
echo "------------ END --------------"

exit $CIVL_ERRORS

