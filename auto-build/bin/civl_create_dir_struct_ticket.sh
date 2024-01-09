#!/bin/bash

####
####
# Create date : 01 Apr 2019
# Create User : Sven Viseur
####
#
####
# Usage example: 
# ./civl_create_dir_struct_ticket.sh --ticet "EST-291"
####

. ../cfg/${BLDR_Omgeving}_omgeving.cfg

while [ $# -ne 0 ]
do
case "$1" in
  "--ticket")
    shift
    export CIVL_TICKET_NR=$1
    ;;
esac
shift
done

if [ "$CIVL_TICKET_NR" = "" ]
then
    echo "ERROR: parameters incorrect."
        echo "ERROR: usage: add the ticket id as parameter !!"
        exit 1
fi

mkdir -p $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET_NR
mkdir -p $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET_NR/odi/$CIVL_TICKET_NR
mkdir -p $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET_NR/sql/$CIVL_TICKET_NR
mkdir -p $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET_NR/log
mkdir -p $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET_NR/wrk_tmp
mkdir -p $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET_NR/parameters
mkdir -p $CIVL_TARGET_DIR_MAIN/$CIVL_TICKET_NR/files
