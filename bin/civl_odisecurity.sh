#!/bin/bash

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -l|--logout)
    exec_part="logout"
    shift # past value
    ;;
    -i|--info)
    exec_part="info"
    shift # past value
    ;;
    -s|--set)
    exec_part="set_workrep"
    TSECTION="$2"
    export SECTION=$(echo $TSECTION | tr [a-z] [A-Z])
    
    shift # past argument
    shift # past value
    ;;
    -h|--help|-?|?|*)    # unknown option
    exec_part="help"
    shift 
    ;;
esac
done

if [ $exec_part == "help" ]
then
  echo "Parameters to be used are:" 
  echo "-h/--help"
  echo "-s|--set <workrep name>"
  echo "-i|--info : display information of current connection settings"
  echo "-l/--logout" 
fi

if [ $exec_part == "logout" ]
then
  unset ODI_URL
  unset ODI_MASTER_USR
  unset ODI_MASTER_PSW
  unset ODI_WORKREP
  unset ODI_USR
  unset ODI_PSW

  echo "ODI Connection settings: logout succeeded"

fi

if [ $exec_part == "info" ]
then
  echo "URL         : ["$ODI_URL"]"
  echo "MASTER USER : ["$ODI_MASTER_USR"]"
  echo "WORKREP     : ["$ODI_WORKREP"]"
  echo "  USER      : ["$ODI_USR"]"
fi

if [ $exec_part == "set_workrep" ]
then

  export INIFILE=$CIVL_HOME_CFG/CIVL_ODI.cfg

  export ODI_URL=$(cat $INIFILE | sed -n -e "/^\[$SECTION\]/,/^\s*\[/{/^[^;].*\=.*/p;}" | grep "ODI_URL=" | cut -d "=" -f2);
  export ODI_WORKREP=$(cat $INIFILE | sed -n -e "/^\[$SECTION\]/,/^\s*\[/{/^[^;].*\=.*/p;}" | grep "ODI_WORKREP=" | cut -d "=" -f2);

  echo "setting ok for : ["$ODI_WORKREP"]"

fi

