#!/bin/bash

#### ticket_list_processing.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script processes a list of ticket numbers
#
# Mandatory arguments are:
#  ENV                     : De omgeving waarvoor gewerkt wordt
#  ACTION                  : De uit te voeren actie
#
# Currently implemented actions are:
#  REPORT : make a TraceIT status report of the listed tickets
#           Options for REPORT are:
#           EXPSTATUS        : The expected status from
#                [ MAAKT_NIET_UIT, AANGEVRAAGD, IN_UITVOERING
#                  UITGEVOERD ]
#
# The option TRACEITACC may be specified as a second option,
# between ENV and ACTION
#
#################################################################
# Change history
#################################################################
#      #             #
#      #             #
#      #             #
#################################################################
#

ScriptName="ticket_list_processing.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

####### Initialisations

TmpFld=$WORKSPACE
declare -a TAStatus
declare -a TARelease
declare -a TAADC
declare -a TAADCType
declare -a TAOK
ADCArrayCount=0
declare -a AAADC


####### Functions

AddADC()
{
  local i=0
  local found=0
  for ((i=0;i<$ADCArrayCount;i++)) do
    if [ "${AAADC[$i]}" == "$NewADC" ]; then
      echo "Have it already"
      found=1
    fi
  done
  if  [ "$found" -eq "0" ]; then
    AAADC[$ADCArrayCount]=$NewADC
    ADCArrayCount=$((ADCArrayCount + 1))
  fi

}

######### Main processing

ArgEnv=$1
ArgAction=$2

GetEnvData
echo $TheBof

declare -a TicketArray
if [ "$ArgAction" == "REPORT" ]; then
  ExpStatus=$3
  if [ "$ExpStatus" == "MAAKT_NIET_UIT" ]; then
    echo "OK"
  else
    ExpStatus="${TheBof}_$3"
  fi
  shift 3
  TicketArray=("$@")
  TicketCount="${#TicketArray[@]}"
fi


# echo $TicketCount

CountOK=0
CountNOK=0
for ((i=0;i<$TicketCount;i++)) do
  ArgTicketNr=${TicketArray[$i]}
  Handover_GetTicketInfo
  TAStatus[$i]=$TicketStatus
  TARelease[$i]=$TicketReleaseNm
  ###TraceIT ADC naamgeving omzetten naar DeployIT
  ADCTRC=$TicketADCTRC
  ConvertADCTRCToDeployITADC

  TAADC[$i]=$DeployITADC
  TAADCType[$i]=$DeployITType
  ### Voeg ADC toe aan AAADC
  NewADC=$DeployITADC
  AddADC
  ###    Tests
  IsOK=1
  if [ "$ExpStatus" == "MAAKT_NIET_UIT" ] || [ "$ExpStatus" == "$TicketStatus" ]; then
    echo "OK!"
  else
    IsOK=0
  fi
  TAOK[$i]=$IsOK
  if [ "$IsOK" -eq "1" ]; then
    CountOK=$((CountOK + 1))
  else
    CountNOK=$((CountNOK + 1))
  fi
done

if [ "$ArgAction" == "REPORT" ]; then
  echo "******** START OF TICKET REPORT *******"
  for ((i=0;i<$TicketCount;i++)) do
     echo "${TicketArray[$i]};${TAStatus[$i]};${TARelease[$i]};${TAADC[$i]};${TAADCType[$i]}"
  done
  echo "********  END OF TICKET REPORT  *******"

  echo "******** START OF ADC REPORT *******"
  for ((i=0;i<$ADCArrayCount;i++)) do
     echo "${AAADC[$i]}"
  done
  echo "********  END OF ADC REPORT  *******"

fi

#  echo "Ticket : ${TicketArray[$i]}"
#  echo "Status : ${TAStatus[$i]}"
#  echo "Release: ${TARelease[$i]}"
#  echo "ADC    : ${TAADC[$i]}"


echo "Totaal aantal OK: $CountOK"
echo "Totaal aantal niet OK: $CountNOK"

exit 0

