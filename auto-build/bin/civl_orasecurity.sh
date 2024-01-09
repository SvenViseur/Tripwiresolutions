#!/bin/bash

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--set)
    exec_part="set"
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
  echo "-s|--set <section name>"
fi

if [ $exec_part == "set" ]
then

  export INIFILE=$CIVL_HOME_CFG/CIVL_ORA.cfg
  export ora_srv=$(cat $INIFILE | sed -n -e "/^\[$SECTION\]/,/^\s*\[/{/^[^;].*\=.*/p;}" | grep "ora_srv=" | cut -d "=" -f2-);

fi

