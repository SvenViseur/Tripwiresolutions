#########################################################################
## global functions used in the deploy-it scripts                      ##
#########################################################################
#
#################################################################
# Change history
#################################################################
# USER # DD/MM/YYYY  # Change Description
# dexa # 19/08/2016  # Added fct LogLineChkDebugLevel
# dexa # 23/08/2016  # Added 3 Unix* fields to GetEnvData
# dexa # 26/08/2016  # Adapt read to cope with last line without CR
# dexa # 01/09/2016  # StapDoel routines
# dexa # 07/09/2016  # svn checkout met optie use-commit-times
# dexa # 22/09/2016  # beveilig IFS dmv oIFS (sbp probleem)
# dexa # 04/10/2016  # HODL_parse: error bij lege file (dus leeg ticket)
# dexa # 07/10/2016  # Add fct MaakTmpTicketFolder (Jira ticket
#      #             #   ONDERSTEUN-966) en Clean... en CleanAll
# dexa # 28/10/2016  # Toev Handover_GetOpl_Local()
# dexa # 15/11/2016  # gebruik DEPLOYIT_SVN_SERVER voor
#      #             # ONDERSTEUN-1007. Idem HOT_ENV in Handover.
# dexa # 15/11/2016  # ONDERSTEUN-1002: capture STDERR van svn call
# dexa # 05/12/2016  # ONDERSTEUN-1012: gebruik deploy_errorwarns.sh
# dexa # 08/12/2016  # ONDERSTEUN-834: GetTicketInfo
# dexa # 06/01/2017  # ONDERSTEUN-1101: toev java tmp optie
# dexa # 24/01/2017  # Commentaar bij RippleUp over -o optie die
#      #             # zal verdwijnen
# dexa # 08/03/2017  # Toev veld TicketReleaseNm bij GetTicketInfo
# dexa # 16/06/2017  # ONDERSTEUN-1504: remove 3 velden ADCENV2SRV
# dexa # 10/07/2017  # ONDERSTEUN-1375: added error checking in ssh call
# dexa # 10/07/2017  # ONDERSTEUN-1375: added fct HandoverConfirm
# dexa # 09/08/2018  # toev functie Parse_ExtraOptsSvnTraceIT
#      #             # en TRACEITSIM toelaten
# vevi # 24/10/2018  # Upaded GetBofInfo,this sets BofDeployFolder
# dexa # 20/02/2019  # Verwijder variabele StapDoel, gebruik
#      #             #   enkel nog DeployIT_Stap_Doel
#      #             # GetBofInfo -> echo nr LogLine omzetten
# dexa # Feb/2019    #  1.0.0  # toev ScriptVersion
# dexa # Feb/2020    #  1.1.0  # add TraceIT_UpdStatus fct
# dexa # May/2020    #  1.2.0  # add GetBatchInfo (from bof code)
# dexa # May/2020    #  1.2.1  # TRACEITSIM aparte credentials
#      #             #         #
#################################################################
#
#
ScriptVersion="1.2.1"

source "${ScriptPath}/deploy_errorwarns.sh"

StapDoelStringToInt() {
###### Omzetten van een stap doel naar volgnummer
## stap doel punten worden beheerd in DEPLOYIT.csv
## INPUT
##    $1        Een string met de naam van het doel
## OUTPUT
##    $Deploy_Doel    Numerieke waarde van dat doel
##
StapDoelString=$1
if [ "$StapDoelString" = "REPLACE" ]; then
  Deploy_Doel=$DEPLOYIT_STAP_REPL_PUB
fi
if [ "$StapDoelString" = "UPD_TICKET" ]; then
  Deploy_Doel=$DEPLOYIT_STAP_UPD_TICKET
fi
if [ "$StapDoelString" = "PREDEPLOY" ]; then
  Deploy_Doel=$DEPLOYIT_STAP_PREDEPLOY
fi
if [ "$StapDoelString" = "ACTIVATE" ]; then
  Deploy_Doel=$DEPLOYIT_STAP_ACTIVATE
fi
if [ "$StapDoelString" = "RESTART" ]; then
  Deploy_Doel=$DEPLOYIT_STAP_RESTART
fi
if [ "$StapDoelString" = "EVALUATE" ]; then
  Deploy_Doel=$DEPLOYIT_STAP_EVAL_TICKET
fi
if [ "$StapDoelString" = "DEFAULT" ]; then
  Deploy_Doel=0
fi
}

StapDoelToString() {
###### Omzetten van een stap doel naar volgnummer
## stap doel punten worden beheerd in DEPLOYIT.csv
## INPUT
##    $1        Een numerieke doelniveau
## OUTPUT
##    $Deploy_Doel_Tekst    Beschrijving van dat doelniveau
##
local LStapDoel=$1
if [ "$LStapDoel" -eq "$DEPLOYIT_STAP_REPL_PUB" ]; then
  Deploy_Doel_Tekst="Replace test zonder ticket update"
fi
if [ "$LStapDoel" -eq "$DEPLOYIT_STAP_UPD_TICKET" ]; then
  Deploy_Doel_Tekst="Replace en ticket update"
fi
if [ "$LStapDoel" -eq "$DEPLOYIT_STAP_PREDEPLOY" ]; then
  Deploy_Doel_Tekst="Installatie voorbereiden op de target machines"
fi
if [ "$LStapDoel" -eq "$DEPLOYIT_STAP_ACTIVATE" ]; then
  Deploy_Doel_Tekst="Container stoppen en wijzigingen activeren"
fi
if [ "$LStapDoel" -eq "$DEPLOYIT_STAP_RESTART" ]; then
  Deploy_Doel_Tekst="Container updaten en herstarten"
fi
if [ "$LStapDoel" -eq "$DEPLOYIT_STAP_EVAL_TICKET" ]; then
  Deploy_Doel_Tekst="Container updaten, herstarten en evaluatie doen"
fi
}

StapDoelBepalen() {
###### Omzetten van een stap doel naar volgnummer
## stap doel punten worden beheerd in DEPLOYIT.csv
## INPUT
##    $1                            Een tekst field uit de command line met het doel
##    $DeployIT_Stap_Doel_Default   Het default doel voor deze omgeving
##    $DeployIT_Stap_Doel_Limit     De bovengrens doel voor deze omgeving
## OUTPUT
##    $DeployIT_Stap_Doel           Het effectieve doel voor deze job
##

StapDoelStringToInt $1
DeployIT_Stap_Doel=$Deploy_Doel

## Test voor ontbrekende doelwaarde
if [ "$1" = "" ]; then
  DeployIT_Stap_Doel=$DeployIT_Stap_Doel_Default
fi

## Test voor Default
if [ "$DeployIT_Stap_Doel" -eq 0 ]; then
  DeployIT_Stap_Doel=$DeployIT_Stap_Doel_Default
fi

## Test voor Limit
if [ "$DeployIT_Stap_Doel" -gt "$DeployIT_Stap_Doel_Limit" ]; then
  DeployIT_Stap_Doel=$DeployIT_Stap_Doel_Limit
fi

StapDoelToString $DeployIT_Stap_Doel
echo "Deploy doelstelling is nu ${DeployIT_Stap_Doel} : ${Deploy_Doel_Tekst}"

}

###### Log level conventions
## Debug value      Log level
##     0            CRITICAL
##     1            ERROR
##     2            WARN
##     3            INFO
##     4            DEBUG
##     5            DEBUG2
LogLineChkDebugLevel() {
## Ensures that $DebugLevel has a numeric value
if [ "$DebugLevel" = "" ]; then
  DebugLevel=3  ## Set a default debug level
fi
eval "NumLevel=DebugLevel+1"
local RC=$?
if [ $RC -ne 0 ]; then
  echo "DebugLevel is incorrectly set. Resetting to INFO level."
  DebugLevel=3
fi
}

LogLineWARN() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 1 ]; then
  echo "WARNING: $1"
fi
}
LogLineINFO() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 2 ]; then
  echo $1
fi
}
LogLineDEBUG() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 3 ]; then
  echo $1
fi
}
LogLineDEBUG2() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 4 ]; then
  echo $1
fi
}

GetEnvData() {
## Determine the list of target servers where to deploy to
## INPUT:    $ArgEnv   : De omgeving waarvoor we werken
##
## OUTPUT:  Onderstaande velden bekomen uit de csv file
##
## Inhoud van de file ENV2DEPLSETTINGS.csv
##
## Field list:
##     env bof opl psw compuser deplgrp depluser pckslvgrp useronapplsrv
## env                 : primary key waarmee gezocht wordt
## bof                 : de bof server die kan gebruikt worden
## opl                 : de svn Oplevering_ omgeving die gebruikt wordt
## psw                 : de vault suffix die gebruikt wordt
## depluser            : de unix user op de slave server
## pckslvgrp           : de shared group tussen packager en slave
## useronapplsrv       : de unix user on the application servers
##
## Voorbeeldlijn:
##  ACC|ACC|Oplevering_DVL|ACC|tacccomp|deploytacc|taccdepl|taccdeps|
LogLineDEBUG2 "Call to GetEnvData() with attributes:"
LogLineDEBUG2 "ArgEnv  = '${ArgEnv}'"
  if [ "$ArgEnv" = "" ]; then
    deploy_error $DPLERR_MissingArgEnv
  fi
Filename="${SvnConfigDataFolder}/ENV2DEPLSETTINGS.csv"
if [ ! -e ${Filename} ]; then
    deploy_error $DPLERR_FileNotFound $Filename
fi
linecount=1
TheBof="NONE"
oIFS=$IFS
IFS="|"
while read env bof opl psw compuser pckslvgrp depluser useronapplsrv || [[ -n "$bof" ]]; do
  if [ "$bof" = "" ]; then
    deploy_error $DPLERR_GetEnvDataMissingBof $Filename $linecount
  fi
  if [ "$opl" = "" ]; then
    deploy_error $DPLERR_GetEnvDataMissingOpl $Filename $linecount
  fi
  if [ "$useronapplsrv" = "" ]; then
    deploy_error $DPLERR_GetEnvDataMissingUsr $Filename $linecount
  fi
  if [ "$ArgEnv" = "$env" ]; then
      TheBof="$bof"
      TheOpl="$opl"
      ThePswEnv="$psw"
      TheCompUser="$compuser"
      TheDeplGrp="$pckslvgrp"
      UnixUserSlave="$depluser"
      UnixGroupPckSlv="$pckslvgrp"
      UnixUserOnApplSrv="$useronapplsrv"
  fi
  linecount=$((linecount + 1))
done < ${Filename}
IFS=$oIFS
if [ "$TheBof" = "NONE" ]; then
  deploy_error $DPLERR_GetEnvDataMissingEnv $Filename $ArgEnv
fi
LogLineDEBUG2 "Scan of file ${FileName} finished:"
LogLineDEBUG2 "linecount = '${linecount}'"
LogLineDEBUG2 "TheBof  = '${TheBof}', TheOpl = '${TheOpl}', ThePswEnv = '${ThePswEnv}', TheCompUser = '${TheCompUser}', TheDeplGrp = '$TheDeplGrp'"
LogLineDEBUG2 "UnixuserSlave  = '${UnixUserSlave}', UnixGroupPckSlv = '${UnixGroupPckSlv}', UnixUserOnApplSrv = '${UnixUserOnApplSrv}'"
}

EchoEnvData() {

echo "TheBof              = '${TheBof}'"
echo "TheOpl              = '${TheOpl}'"
echo "ThePswEnv           = '${ThePswEnv}'"
echo "TheCompUser         = '${TheCompUser}'"
echo "TheDeplGrp          = '$TheDeplGrp'"
echo "UnixuserSlave       = '${UnixUserSlave}'"
echo "UnixGroupPckSlv     = '${UnixGroupPckSlv}'"
echo "UnixUserOnApplSrv   = '${UnixUserOnApplSrv}'"
}

Set_TraceITACC() {
## Deze functie zet de pointers voor SVN en TraceIT naar de ACC servers
if [ "$DEPLOYIT_DYN_ENV" = "DEPLOYITACC" ]; then
  ## deze optie mag enkel op ACC gebruikt worden
  DeployIT_SVN_server="scmacc"
  DeployIT_Handover_HOT_ENV="acc"
  DeployIT_Handover_Credentials="handover-tool_settings-ACC.conf"
else
  deploy_error $DPLERR_TraceITACCInvalidEnv
fi
}

Set_TraceITSIM() {
## Deze functie zet de pointers voor SVN en TraceIT naar de SIM servers
if [ "$DEPLOYIT_DYN_ENV" = "DEPLOYITACC" ]; then
  ## deze optie mag enkel op ACC gebruikt worden
  DeployIT_SVN_server="scmsim.argenta.be"
  DeployIT_Handover_HOT_ENV="sim"
  DeployIT_Handover_Credentials="handover-tool_settings-SIM.conf"
else
  deploy_error $DPLERR_TraceITACCInvalidEnv
fi
}

Parse_ExtraOptsSvnTraceIT() {
local LExtraOpts=$1
if [ "$LExtraOpts" = "" ]; then
  #### There are no extra options given. return without action
  return 0
fi
## Test ExtraOpts voor TraceITACC en TraceITSIM
if [ "$LExtraOpts" = "TRACEITACC" ]; then
  LogLineWARN "Activatie van TraceIT/SVN ACC!!!"
  Set_TraceITACC
  if [[ $DeployIT_Stap_Doel -gt $DEPLOYIT_STAP_UPD_TICKET ]]; then
    ## reduceer StapDoel !! uitrol naar targets is VERBODEN!!
    LogLineWARN "Let op. De uitrol wordt beperkt tot het bijwerken van het ticket!"
    LogLineWARN "De uitrol naar target servers wordt niet toegelaten wegens SVN ACC!!"
    #DeployIT_Stap_Doel=$DEPLOYIT_STAP_UPD_TICKET
  fi
fi
if [ "$LExtraOpts" = "TRACEITSIM" ]; then
  LogLineWARN "Activatie van TraceIT/SVN SIM!!!"
  Set_TraceITSIM
  if [[ $DeployIT_Stap_Doel -gt $DEPLOYIT_STAP_UPD_TICKET ]]; then
    ## reduceer StapDoel !! uitrol naar targets is VERBODEN!!
    LogLineWARN "Let op. De uitrol wordt beperkt tot het bijwerken van het ticket!"
    LogLineWARN "De uitrol naar target servers wordt niet toegelaten wegens SVN SIM!!"
    DeployIT_Stap_Doel=$DEPLOYIT_STAP_UPD_TICKET
  fi
fi
}

GetSrvList() {
## Determine the list of target servers where to deploy to
##  INPUT:    $ArgAppl  : The Application name
##            $ArgEnv   : The Environment where we are currently working in

## OUTPUT:    $SrvCount : The amount of servers found for our given Application and Environment
##            $SrvList  : The list of target servers
##
## Content of ADCENV2SRV.csv and ADCENV2SRV_MAN.csv:
##
## Field list: adc env srv (hb_url hb_to srv_act)
##
## adc                 : application deployment component
## env                 : environment
## srv                 : target server
##
## Example line :   OVERNAMESERVICE_WAR|DVL|sv-arg-jserv-d11|
##
LogLineDEBUG2 "Call to GetSrvList() with attributes:"
LogLineDEBUG2 "ArgAppl = '${ArgAppl}'"
LogLineDEBUG2 "ArgEnv  = '${ArgEnv}'"
  if [ "$ArgAppl" = "" ]; then
    deploy_error $DPLERR_MissingArgAppl
  fi
SrvCount=0
Filename="${SvnConfigDataFolder}/ADCENV2SRV.csv"
if [ ! -e ${Filename} ]; then
  deploy_error $DPLERR_FileNotFound $Filename
fi
linecount=1
# Change 'Internal Field Separator' to '|' To correctly read the word boundaries of the ADCENV2SRV Files
oIFS=$IFS
IFS="|"
# Find all target servers for given ArgAppl and ArgEnv in ADCENV2SRV.csv
while read adc env srv hb_url hb_to srv_act || [[ -n "$adc" ]]; do
  if [ "$srv" = "" ]; then
    echo "invalid file in function GetSrvList for file ${Filename} with missing srv data on line ${linecount}."
    exit 16
  fi
  if [ "$ArgAppl" = "$adc" ]; then
    if [ "$ArgEnv" = "$env" ]; then
      # Target server found and added
      ((SrvCount++))
      SrvList[$SrvCount]="$srv"
    fi
  fi
  linecount=$((linecount + 1))
done < ${Filename}
LogLineDEBUG2 "Scan of file ${FileName} finished:"
LogLineDEBUG2 "linecount = '${linecount}'"

# If a ADCENV2SRV_MAN.csv file exists, find all target servers for given ArgAppl and ArgEnv in ADCENV2SRV_MAN.csv
FilenameMAN="${SvnConfigDataFolder}/ADCENV2SRV_MAN.csv"
if [ -e ${FilenameMAN} ]; then
  LogLineDEBUG2 "Manual File ADCENV2SRV_MAN.csv found"
	linecountMAN=1
  while read adc env srv hb_url hb_to srv_act || [[ -n "$adc" ]]; do
  if [ "$srv" = "" ]; then
    echo "invalid file in function GetSrvList for file ${FilenameMAN} with missing srv data on line ${linecountMAN}."
    exit 16
  fi
  if [ "$ArgAppl" == "$adc" ]; then
    if [ "$ArgEnv" = "$env" ]; then
      # Target server found and added
      ((SrvCount++))
      SrvList[$SrvCount]="$srv"
    fi
  fi
  linecountMAN=$((linecountMAN + 1))
  LogLineDEBUG2 "Scan of file ${FilenameMAN} finished:"
  LogLineDEBUG2 "linecount in ${FilenameMAN} = '${linecountMAN}'"
done < ${FilenameMAN}
fi
# Restore 'Internal Field Separator' to use spaces again
IFS=$oIFS
LogLineDEBUG2 "SrvCount  = '${SrvCount}'"
}

EchoSrvList() {
if [ $DebugLevel -gt 2 ]; then
  echo "Number of target servers: $SrvCount"
  echo "List of target servers:"
  for (( i=1 ; i<=$(( $SrvCount )); i++))
    do
      echo "${SrvList[$i]}"
    done
  echo "End of target server list."
fi
}

PingSrvList() {
## Test if all servers are up and running OK (using ping)
SrvPingOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ping -c 2 "${SrvList[$i]}${DnsSuffix}" > /dev/null
    RC=$?
    if [ $RC -eq 0 ]; then
      ((SrvPingOKCount++))
    else
      LogLineWARN "Server ping failed for server ${SrvList[$i]}"
    fi
  done
if [ $SrvPingOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers are reachable."
  exit 16
fi
LogLineDEBUG "$SrvPingOKCount out of $SrvCount had a successfull PING test."
}

GetCntInfo() {
## Determine the container and paths for the given application
##  INPUT:    $ArgAppl  : The Application name
##
##  OUTPUT:   $TheCnt  : Container
##            $TheUsr  : USR
##            $TheFld  : Folder
##
## Content of ADC2CNTUSRDIR.csv and ADC2CNTUSRDIR_MAN.csv:
##
## Field list: adc cnt usr fld (enter)
##
## adc                 : application deployment component
## cnt                 : container
## usr                 : unix system resources
## fld                 : server folder path
##
## Example line :   CODESWS_WAR|JSERV023|jserv023|/data/jboss/jserv023
##
LogLineDEBUG2 "Call to GetCntInfo() with attributes:"
LogLineDEBUG2 "ArgAppl = '${ArgAppl}'"
  if [ "$ArgAppl" = "" ]; then
    deploy_error $DPLERR_MissingArgAppl
  fi
cnt=""
Filename="${SvnConfigDataFolder}/ADC2CNTUSRDIR.csv"
if [ ! -e ${Filename} ]; then
  deploy_error $DPLERR_FileNotFound $Filename
fi
linecount=1
# Change 'Internal Field Separator' to '|' To correctly read the word boundaries of the ADC2CNTUSRDIR.csv Files
oIFS=$IFS
IFS="|"
while read adc cnt usr fld enter || [[ -n "$adc" ]]; do
  if [ "$fld" = "" ]; then
    deploy_error $DPLERR_GetCntInfoMissingFld $Filename $linecount
  fi
  if [ "$ArgAppl" = "$adc" ]; then
    TheCnt="$cnt"
    TheUsr="$usr"
    TheFld="$fld"
  fi
  linecount=$((linecount + 1))
done < ${Filename}

## Search for the Container in Additional _MAN File
FilenameMAN="${SvnConfigDataFolder}/ADC2CNTUSRDIR_MAN.csv"
if [ -e ${FilenameMAN} ]; then
  LogLineDEBUG2 "Manual File ADC2CNTUSRDIR_MAN.csv found"
  if [ "$TheCnt" = "" ]; then
  linecountMAN=1
  IFS="|"
  while read adc cnt usr fld enter || [[ -n "$adc" ]]; do
    if [ "$fld" = "" ]; then
      deploy_error $DPLERR_GetCntInfoMissingFld $FilenameMAN $linecountMAN
    fi
    if [ "$ArgAppl" = "$adc" ]; then
      TheCnt="$cnt"
      TheUsr="$usr"
      TheFld="$fld"
    fi
    linecountMAN=$((linecount + 1))
  done < ${FilenameMAN}
  fi
fi
# Restore 'Internal Field Separator' to use spaces again
IFS=$oIFS
LogLineDEBUG2 "Container = '${TheCnt}'"
LogLineDEBUG2 "User      = '${TheUsr}'"
LogLineDEBUG2 "Folder    = '${TheFld}'"
## The resulting values are mandatory.
if [ "$TheCnt" = "" ]; then
  deploy_error $DPLERR_GetCntInfoMissingAppl $Filename $ArgAppl
fi
}

########################################################################
## TraceIT functies                                                   ##
########################################################################

TraceIT_UpdStatus() {
## Input:
##    $ArgTicketNr : Ticket number
##    $ArgStatus   : The desired status
##    $ArgErrMsg   : The error message to show when failed
##
##        Valid values for $ArgStatus are:
##           ONTWIKKELING, SIC_BUGFIX, AANVRAGEN_ACC,
##           AANVRAGEN_ACC_DRINGEND, AANVRAGEN_INT,AANVRAGEN_INT_DRINGEND,
##           AANVRAGEN_VAL, GOEDKEUREN_ACC, ACC_IN_UITVOER,
##           ACC_UITGEVOERD, ACC_UITGEVOERD_MET_FOUTEN
##
##
## Output:
##    Return code  : The RC of the java call
local TheTicketNr=$ArgTicketNr
local TheStatus=$ArgStatus
if [ "$DeployIT_Handover_HOT_ENV" = "acc" ]; then
  local CredentialsFile="${ConfigDataFolder}/credentials/delivery-tool-acc.sh"
  source $CredentialsFile ## This loads the set_ and clear_ functions used below
fi
if [ "$DeployIT_Handover_HOT_ENV" = "prd" ]; then
  local CredentialsFile="${ConfigDataFolder}/credentials/delivery-tool.sh"
  source $CredentialsFile ## This loads the set_ and clear_ functions used below
fi
set_delivery-tool_credentials
Jar="${BinFolder}/delivery-tool.jar"
Fctn="be.argenta.delivery.UpdateStatus"
LogLineDEBUG2 "java -cp $Jar ${Fctn} -o ${DeployIT_Handover_HOT_ENV} -n $TheTicketNr -s $TheStatus"
java -cp $Jar ${Fctn} -o ${DeployIT_Handover_HOT_ENV} -n $TheTicketNr -s $TheStatus
local RC=$?
clear_delivery-tool_credentials
if [ $RC -ne 0 ]; then
  echo $ArgErrMsg
fi
return $RC
}

## see also below for handover related functions that work with traceIT

#########################################################################
## handover tool related functions                                     ##
#########################################################################

Handover_Download() {
## Input:
##    $ArgTicketNr : Ticket number
##    $TheOpl      : Opleveringsfolder, bekomen via GetEnvData()
## Output: downloaded into current folder, wit the downloaded.txt and the deleted.txt

Handover_Download_via_BOF
}

Handover_Download_Local() {
## Input:
##    $ArgTicketNr : Ticket number
##    $TheOpl      : Opleveringsfolder, bekomen via GetEnvData()
## Output: downloaded into current folder, wit the downloaded.txt and the deleted.txt
local TheTicketNr=$ArgTicketNr

Jar="${BinFolder}/handover-tool-app.jar"
Fctn="be.argenta.handover.svn.DownloadService"
Config="${ConfigDataFolder}/credentials/${DeployIT_Handover_Credentials}"
LogLineDEBUG2 "java -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -sc -ss -o $TheOpl -t $TheTicketNr"
java -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -sc -ss -o $TheOpl -t $TheTicketNr
local RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_HandoverDownloadService
fi

}

Handover_Confirm() {
## Input:
##    $ArgTicketNr : Ticket number
##    $TheOpl      : Opleveringsfolder, bekomen via GetEnvData()
##    The current folder must contain the downloaded.txt and the deleted.txt files!
## Output:
##    NONE
local TheTicketNr=$ArgTicketNr

Jar="${BinFolder}/handover-tool-app.jar"
Fctn="be.argenta.handover.svn.ConfirmationService"
Config="${ConfigDataFolder}/credentials/${DeployIT_Handover_Credentials}"
LogLineDEBUG2 "java -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -sc -ss -o $TheOpl -t $TheTicketNr"
java -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -u DeployIT_bulk -o $TheOpl -t $TheTicketNr
local RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_HandoverConfirmationService
fi

}

GetDynOplOmg() {
Handover_GetOpl_Local

}

Handover_GetOpl_Local() {
## Input:
##    $ArgTicketNr : Ticket number
##    $TmpFld      : Een Temporary folder waar we mogen schrijven
## Output:
##    $TheOpl      : De opleveringsomgeving waarin generated files moeten komen
local TheTicketNr=$ArgTicketNr
local TmpFile=$TmpFld"/T"$TheTicketNr".out"

Jar="${BinFolder}/handover-tool-app.jar"
Fctn="be.argenta.handover.svn.GetSourceSvnRepo"
Config="${ConfigDataFolder}/credentials/${DeployIT_Handover_Credentials}"
java -Djava.io.tmpDir=$TmpFld -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -t $TheTicketNr -oo $TmpFile
local RC=$?
if [ $RC -ne 0 ]; then
  echo "Java call handover tool voor DownloadService is gefaald."
  exit 16
fi
TheOpl=$(cat $TmpFile)
echo "Dynamisch bepaalde opleveromgeving voor dit ticket is: $TheOpl"
rm $TmpFile
}

Handover_GetTicketInfo() {
## Input:
##    $ArgTicketNr : Ticket number
##    $TmpFld      : Een Temporary folder waar we mogen schrijven
## Output:
##    $TicketStatus      (string)    : De status van het ticket
##    $TicketReleaseID   (integer)   : De Technical ID van de release
##    $TicketReleaseNR   (integer)   : De gewone Nr van de release
##    $TicketReleaseNm   (string)    : De naam van de release
##    $TicketOmgeving    (string[3]) : De omgeving waar we nu zitten
##    $TicketSourceSvn   (string)    : De opleveringsomgeving (zie GetOpl)
##    $TicketADCTRC      (string)    : De ADC naam in TraceIT

if [ "$TmpFld" = "" ]; then
  echo "Call to Handover_GetTicketInfo function without a valid TmpFld specified."
  exit 16
fi
local TheTicketNr=$ArgTicketNr
local TmpFile="${TmpFld}/T${TheTicketNr}.info"

Jar="${BinFolder}/handover-tool-app.jar"
Fctn="be.argenta.handover.train.ViewTicket"
Config="${ConfigDataFolder}/credentials/${DeployIT_Handover_Credentials}"
echo "java -Djava.io.tmpDir=$TmpFld -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -t $TheTicketNr -ti $TmpFile"
java -Djava.io.tmpDir=$TmpFld -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -t $TheTicketNr -ti $TmpFile
local RC=$?
if [ $RC -ne 0 ]; then
  echo "Java call handover tool voor $Fctn is gefaald."
  exit 16
fi
## formaat van de output file is bash assignment van deze variablen:
local status="UNDEFINED"
local releaseId="UNDEFINED"
local omgeving="UNDEFINED"
local sourceSvn="UNDEFINED"
local ticket="UNDEFINED"
local adc="UNDEFINED"
## parse de bekomen file
source $TmpFile
## test result values
if [ "$status" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "status"
fi
if [ "$sreleaseNr" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "releaseNr"
fi
if [ "$sreleaseId" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "releaseId"
fi
if [ "$omgeving" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "omgeving"
fi
if [ "$sourcesvn" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "sourcesvn"
fi
if [ "$ticket" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "ticket"
fi
if [ "$ticketId" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "ticketId"
fi
if [ "$adc" = "UNDEFINED" ]; then
  deploy_error $DPLERR_TicketInfoMissing "adc"
fi
if [ "$ticket" != "$ArgTicketNr" ]; then
  deploy_error $DPLERR_TicketInfoWrongTicket $ArgTicketNr $ticket
fi
TicketStatus=$status
TicketID=$ticketId
TicketReleaseID=$releaseId
TicketReleaseNR=$releaseNr
TicketReleaseNm=$releaseNaam
TicketOmgeving=$omgeving
TicketSourceSvn=$sourcesvn
TicketADCTRC=$adc

## verwijder tijdelijke file
rm $TmpFile
}

Handover_Download_via_BOF() {
## Input:
##    $ArgEnv      : Target environment - determines how to call handover tool
##    $ArgTicketNr : Ticket number
##    $TheOpl      : Opleveringsfolder, bekomen via GetEnvData()
##    $TheBof      : The BOF server to use, bekomen via GetEnvData()
##    $SshCommand  : The command to perform a single command via SSH
## Output: downloaded into current folder, wit the downloaded.txt and the deleted.txt

## Belangrijk - de manier van BOF calls is heel voorlopig, want dit moet eruit.
## The targeted BOF server requires a shell script with a specific command line layout
## that calls the handover script with the required settings.
## Logon is done with toptoa
##    The required script is named: ~/autodeploy/bin/handover.sh
##    The call syntax for that script is
##    handover.sh $Fctn $TheOpl $TheTicketNr
##    Where $Fctn determines the java call to perform in the handover tool
##          $TheOpl is the Oplevering_xxx root folder that matches the ticket
##          $TheTicketNr is the Ticket number

## Test if BOF server is reachable

BofServer="bof_${TheBof}${DnsSuffix}"
ping -c 2 "${BofServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  echo "BOF Server (${BofServer} is unreachable. It is needed to fetch the SVN material."
  exit 16
fi

if [ $DebugLevel -gt 0 ]; then
  echo "BOF server PING is OK."
fi

## Call BOF server to perform the handover tool to fetch the SVN material

callscript=""
if [ "$ArgEnv" = "ACC" ]; then
  callscript="~/handover/bin/download"
fi
if [ "$ArgEnv" = "AC5" ]; then
  callscript="~/autodeploy/bin/download_dv5"
fi
if [ "$ArgEnv" = "SI2" ]; then
  callscript="~/autodeploy/bin/download_dv5"
fi
if [ "$ArgEnv" = "SIM" ]; then
  callscript="~/handover/bin/download"
fi

if [ "$callscript" = "" ]; then
  echo "Omgeving niet ondersteund via huidige BOF call infrastructuur!"
  exit 16
fi

TmpCmdFile="./fetchdata.sh"
TargetFolder="~/autodeploy/T${ArgTicketNr}"
# Create the target folder
$SshCommand $BofServer "mkdir ${TargetFolder}"
# NO ERROR CHECKING: the folder may already exist!
# But the below command MUST work!
$SshCommand $BofServer "cd ${TargetFolder}"
RC=$?
if [ $RC -ne 0 ]; then
  echo "Could access ticket specific folder on BOF Server (${BofServer}."
  exit 16
fi
# Make temporary file with commands to run on the BOF server
# Because the BOF server is an HP-UX, we should use ksh instead of bash
rm ${TmpCmdFile}
cat >${TmpCmdFile} << EOL
#!/bin/ksh
cd ${TargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not change to the ticket specific folder."
  exit 16
fi
rm -rf svn
mkdir svn
cd svn
${callscript} ${ArgTicketNr}
EOL
chmod +x ${TmpCmdFile}

$ScpPutCommand $BofServer $TmpCmdFile "autodeploy/T${ArgTicketNr}/fetchdata.sh"
RC=$?
if [ $RC -ne 0 ]; then
  echo "Could not put fetchdata.sh file on the BOF Server (${BofServer})."
  exit 16
fi

# execute the fetchdata.sh script
$SshCommand $BofServer "${TargetFolder}/fetchdata.sh"
RC=$?
if [ $RC -ne 0 ]; then
  echo "SSH call to run fetchdata.sh on the BOF Server (${BofServer}) failed (RC=$RC)."
  exit 16
fi

# fetch the Deleted* and Downloaded* files
$ScpGetCommand $BofServer autodeploy/T${ArgTicketNr}/svn/TI${ArgTicketNr}-deleted.txt handover-deleted.txt
$ScpGetCommand $BofServer autodeploy/T${ArgTicketNr}/svn/TI${ArgTicketNr}-downloaded.txt handover-downloaded.txt
$ScpGetCommand $BofServer autodeploy/T${ArgTicketNr}/svn svn
RC=$?
if [ $RC -ne 0 ]; then
  echo "Could not get svn data from the BOF Server (${BofServer})."
  exit 16
fi

}

## GetBofInfo function
## Input:
##    TmpFld, TheEnv, TheADC
## Output: BofDeployFolder, the bof app folder under /$env/

## This script sets the dest folder variable BofDeployFolder for bof and javabatch ADC's
## It will call the replace tool for BOF_DEPLOY_PATH
## If it finds anything else but 'NA', it will use that value
## Otherwhise, it will take the ADC name, make it lowercase, remove '_bof' 
## and remove all '_' chars.
## Example path: cims (for CIMS_BOF), to be used for eg. /ACC/cims/
##
## Please note that this BOF_DEPLOY_PATH also works for JAVABATCH ADCs and
##   the new _BATCH ADCs!
## Just define that variable with the correct subfolder and it will be
## used for all the deploys of these ADCs.

GetBofInfo() {
LogLineDEBUG2 "Call to GetBofInfo() with attributes:"
LogLineDEBUG2 "TmpFld=$TmpFld"
LogLineDEBUG2 "TheEnv=$TheEnv"
LogLineDEBUG2 "TheADC=$TheADC"

Replace_Tool_Defaults

RT_InFolder="$TmpFld/in"
RT_ScanFilter="*"
RT_OutFolder="$TmpFld/out"
RT_OutFolderEnc=""
RT_Env=$TheEnv
RT_ADC=$TheADC
RT_Tmp=$TmpFld/tmp

rm -rf $RT_InFolder
mkdir -p $RT_InFolder
rm -rf $RT_OutFolder
mkdir -p $RT_OutFolder
rm -rf $RT_Tmp
mkdir -p $RT_Tmp

# make the temp file with the settings list
cat > $RT_InFolder/bof_deploy_settings.sh << EOL
## BOF ADC Deploy Paths
BofDeployFolder=@@BOF_DEPLOY_PATH#@
BofGroupPrefix=@@ACL_GROUP_PREFIX#@
EOL

Replace_Tool

if [ ! -e $RT_OutFolder/bof_deploy_settings.sh ]; then
  echo "Replace tool kan BOF settings file (static) niet correct verwerken!"
  exit 16
fi
LogLineDEBUG2 "BOF settings code:"
if [ $DebugLevel -gt 4 ]; then
  cat $RT_OutFolder/bof_deploy_settings.sh
fi
LogLineDEBUG2 "end of BOF settings code"
source $RT_OutFolder/bof_deploy_settings.sh

if [[ "$BofDeployFolder" == "NA" ]]; then
  LogLineDEBUG2 "No specific deploy path given, will remove _bof from ADC and remove any _"
  BofDeployFolder=${TheADC/_BOF/""}
  BofDeployFolder=${BofDeployFolder/_/""}
  BofDeployFolder=${BofDeployFolder,,}
  LogLineDEBUG "Transformed \"${TheADC}\" to \"${BofDeployFolder}\""
else
  LogLineDEBUG "Custom deploy path specified for  \"${TheADC}\":  \"${BofDeployFolder}\""
fi

BofGroupPrefix5="${BofGroupPrefix}${DEPLOYIT_BOF_GROUP_SUFFIX}"
TheFld=${BofDeployFolder}
LogLineINFO "BofDeployFolder    = '${BofDeployFolder}'"
LogLineINFO "BofGroupPrefix     = '${BofGroupPrefix}'"
LogLineINFO "BofGroupPrefix5    = '${BofGroupPrefix5}'"

## Opkuisen tijdelijke files
rm -f $RT_InFolder/bof_deploy_settings.sh
rmdir $RT_InFolder
rm -f $RT_OutFolder/bof_deploy_settings.sh
rmdir $RT_OutFolder
rmdir $RT_Tmp
}

## GetBatchInfo function
## Input:
##    TmpFld, TheEnv, TheADC
## Output: BatchDeployFolder, the batch app folder under /$env/
##         AclGroupPrefix, AclGroupPrefix5: The 3 letter acl code and the 5 letter one with the env added

## This script sets the dest folder variable BofDeployFolder for bof and javabatch ADC's
## It will call the replace tool for BATCH_DEPLOY_PATH
## If it finds anything else but 'NA', it will use that value
## Otherwhise, it will take the ADC name, make it lowercase, remove '_batch'
## and remove all '_' chars.
## Example path: cims (for CIMS_BOF), to be used for eg. /ACC/cims/
##
## Please note that this BATCH_DEPLOY_PATH also works for JAVABATCH ADCs
## Just define that variable with the correct subfolder and it will be
## used for all the deploys of these ADCs.

GetBatchInfo() {
LogLineDEBUG2 "Call to GetBatchInfo() with attributes:"
LogLineDEBUG2 "TmpFld=$TmpFld"
LogLineDEBUG2 "TheEnv=$TheEnv"
LogLineDEBUG2 "TheADC=$TheADC"

Replace_Tool_Defaults

RT_InFolder="$TmpFld/in"
RT_ScanFilter="*"
RT_OutFolder="$TmpFld/out"
RT_OutFolderEnc=""
RT_Env=$TheEnv
RT_ADC=$TheADC
RT_Tmp=$TmpFld/tmp

rm -rf $RT_InFolder
mkdir -p $RT_InFolder
rm -rf $RT_OutFolder
mkdir -p $RT_OutFolder
rm -rf $RT_Tmp
mkdir -p $RT_Tmp

# make the temp file with the settings list
cat > $RT_InFolder/batch_deploy_settings.sh << EOL
## BATCH ADC Deploy Paths
BatchDeployFolder=@@BATCH_DEPLOY_PATH#@
AclGroupPrefix=@@ACL_GROUP_PREFIX#@
EOL

Replace_Tool

if [ ! -e $RT_OutFolder/batch_deploy_settings.sh ]; then
  echo "Replace tool kan Batch settings file (static) niet correct verwerken!"
  exit 16
fi
LogLineDEBUG2 "BATCH settings code:"
if [ $DebugLevel -gt 4 ]; then
  cat $RT_OutFolder/batch_deploy_settings.sh
fi
LogLineDEBUG2 "end of BATCH settings code"
source $RT_OutFolder/batch_deploy_settings.sh

if [[ "$BatchDeployFolder" == "NA" ]]; then
  LogLineDEBUG2 "No specific deploy path given, will remove _batch from ADC and remove any _"
  BatchDeployFolder=${TheADC/_BATCH/""}
  BatchDeployFolder=${BatchDeployFolder/_/""}
  BatchDeployFolder=${BatchDeployFolder,,}
  LogLineDEBUG "Transformed \"${TheADC}\" to \"${BatchDeployFolder}\""
else
  LogLineDEBUG "Custom deploy path specified for  \"${TheADC}\":  \"${BatchDeployFolder}\""
fi

AclGroupPrefix5="${AclGroupPrefix}${DEPLOYIT_BOF_GROUP_SUFFIX}"
LogLineINFO "BatchDeployFolder    = '${BatchDeployFolder}'"
LogLineINFO "AclGroupPrefix       = '${AclGroupPrefix}'"
LogLineINFO "AclGroupPrefix5      = '${AclGroupPrefix5}'"

## Opkuisen tijdelijke files
rm -f $RT_InFolder/batch_deploy_settings.sh
rmdir $RT_InFolder
rm -f $RT_OutFolder/batch_deploy_settings.sh
rmdir $RT_OutFolder
rmdir $RT_Tmp
}

Handover_RippleUp() {
## Input:
##    $ArgTicketNr : Ticket number
##    $ArgEnv      : Omgeving tot op welk niveau de Ripple moet gaan
## Output: geen.
##
## vanaf versie 1.4.4 van de handover tool zal deze functie niet langer zich baseren op
## de -o optie, maar enkel op de status van het ticket waaruit dan de doelomgeving wordt
## afgeleid. Dit is nodig omdat "INT" op 2 manieren bereikbaar moet zijn voor een ripple up:
## INT als gewone omgeving komt direact na Oplevering_DVL, maar INT_Update is een target
## nadat een ticket via ACC en SIM geweest is. Dan zal de status van het ticket aangeven
## dat de Ripple Up ook over ACC en SIM moet gaan om bij INT_Update uit te komen.
## Op termijn mag dus de optie "-o" verdwijnen uit onderstaande java call.
##
local TheTicketNr=$ArgTicketNr
local TheEnv=$ArgEnv

Jar="${BinFolder}/handover-tool-app.jar"
Fctn="be.argenta.handover.train.GeneratedStagingService"
Config="${ConfigDataFolder}/credentials/${DeployIT_Handover_Credentials}"
java -cp $Jar -DHOT_ENV=${DeployIT_Handover_HOT_ENV} $Fctn -c $Config -o $TheEnv -t $TheTicketNr
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_HandoverGeneratedStagingService
fi

}

HODL_parse() {
## HandOver file TIxxx-downloaded.txt parser
##    voor de specifieke config en password folders
##    om de naam van de ADC eruit te halen
## Input:
## ${HandoverDownloadedList}: Filename van de TIxxx-downloaded.txt file
## Output:
## ${TheTicketType}         : "config" of "password"
## ${TheTicketADCfolder}    : de subfolder onder config of password waar
##                            de bestanden staan voor dit ticket 
##
local line1=$(head -n 1 ${HandoverDownloadedList})
local RC=$?
if [ $RC -ne 0 ]; then
  echo "call to head command in function HODL_parse failed. RC=$RC."
  exit 16
fi
if [ "${line1}" = "" ]; then
  echo "HODL_parse error: file is leeg. Oorzaak is waarschijnlijk dat er geen files aan"
  echo "ticket hangen."
  exit 16
fi
LogLineDEBUG "line1 = ${line1}"
## expected format: OK      config/<adc-folder>/...
##             of : OK      password/<adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
LogLineDEBUG "line1 (stripped) = ${line1}"
firstpart=${line1%%"/"*}
local restpart=${line1:${#firstpart}+1}
secondpart=${restpart%%"/"*}
LogLineDEBUG "first folder part is: ${firstpart}"
LogLineDEBUG "second folder part is: ${secondpart}"
if [[ ${firstpart} -eq "config" ]]; then
  LogLineINFO "Line 1 is in the expected format for a config ticket!"
else
  if [[ ${firstpart} -eq "password" ]]; then
    LogLineINFO "Line 1 is in the expected format for a password ticket!"
  else
    echo "Line 1 is niet in het verwachte formaat. De eerste folder level zou"
    echo "ofwel 'config' ofwel 'password' moeten zijn."
    echo "De eerste folder level is echter: >>${firstpart}<<"
    exit 16
  fi
fi
TheTicketType=${firstpart}
TheTicketADCfolder=${secondpart}
}

Handover_MakeDeleteBashScript() {
## Input:
##    $ArgTicketNr : Ticket number
##                   In de current folder moet de TI<number>-deleted.txt file staan
## Output:
##    "TI${ArgTicketNr}-dodelete.sh" : script met de delete commando's
##
## Deze functie leest de file TI{$ArgTicketNr}-deleted.txt file en maakt ervan
## een bash script file om de benodigde files te deleten op target servers.
##
## Belangrijk: Filenames met spaties of andere speciale characters worden
## geweigerd. Dan moet de delete manueel gebeuren.

Filename="TI${ArgTicketNr}-deleted.txt"
FilenameUnix="TI${ArgTicketNr}-deleted.txt.unix"
dos2unix -n $Filename $FilenameUnix
DeleteScript="TI${ArgTicketNr}-dodelete.sh"
rm -f $DeleteScript
oIFS=$IFS
IFS=$' \t'
linecount=1
echo "#!/bin/bash" > $DeleteScript
while read status fname1 fname2 || [[ -n "$status" ]]; do
  if [ "$status" != "OK" ]; then
    deploy_error $DPLERR_HandoverDeleteNotOK $linecount
  fi
  if [ "$fname2" != "" ]; then
    deploy_error $DPLERR_HandoverDeleteFNameSpace $linecount
  fi
  firstpart=${fname1%%"/"*}
  local restpart1=${fname1:${#firstpart}+1}
  secondpart=${restpart1%%"/"*}
  local restpart2=${restpart1:${#secondpart}+1}
  thirdpart=${restpart2%%"/"*}
  local restpart3=${restpart2:${#thirdpart}+1}
  ## 5 mogelijkheden:
  ## firstpart = "config" & thirdpart = "generated" : negeer de lijn (enkel templates behouden)
  ## firstpart = "password" & thirdpart = "generated" : negeer de lijn (idem)
  ## firstpart = "config" & thirdpart = "template" : pad begint NA config/ADC/template/, dus restpart3
  ## firstpart = "password" & thirdpart = "template" : pad begint NA password/ADC/template/, dus restpart3
  ## firstpart = <iets anders> : pad begint NA ADC/, dus restpart1
  DeleteFName=$restpart1
  if [ "$firstpart" = "config" ] && [ "$thirdpart" = "generated" ]; then
    DeleteFName="SKIP-THIS-LINE"
  fi
  if [ "$firstpart" = "password" ] && [ "$thirdpart" = "generated" ]; then
    DeleteFName="SKIP-THIS-LINE"
  fi
  if [ "$firstpart" = "config" ] && [ "$thirdpart" = "template" ]; then
    DeleteFName="$restpart3"
  fi
  if [ "$firstpart" = "password" ] && [ "$thirdpart" = "template" ]; then
    DeleteFName="$restpart3"
  fi
  if [ "$DeleteFName" != "SKIP-THIS-LINE" ]; then
    echo "rm -f $DeleteFName" >> $DeleteScript
  fi
  linecount=$((linecount + 1))
done < ${FilenameUnix}
rm $FilenameUnix
IFS=$oIFS
chmod +x $DeleteScript
}

######################################################################
##                                                                  ##
##    SVN gerelateerde functies                                     ##
##                                                                  ##
######################################################################



Svn_set_options() {
## Interne functie om Svn opties klaar te maken voor de verschillende
## routines die Svn aanroepen

## Inlezen van Svn credentials
source ${ConfigDataFolder}/credentials/svn.password.properties
## Samenstellen van alle Svn opties
SvnCredentials=" --username ${SvnUsername} --password ${SvnPassword} "
SvnUCT="--config-option config:miscellany:use-commit-times=yes"
SvnOpts="${SvnCommonOpts} ${SvnCredentials} ${SvnUCT}"
}

Svn_co() {
## SVN Checkout functie
## Input:
## DeployIT_SVN_server
## TmpTicketFolder
## TheOpl             (de Opleverings-root-folder, bekomen via GetEnvData()  )
## OplFolder          (de opleverings-subfolder, meestal config/$EnvAppl of password/$EnvAppl  )
## Output:
## svn folder structure under $TmpTicketFolder/svnupd

if [ -z "${TmpTicketFolder}" ]; then
  echo "ERROR: Svn_co was called with missing \$TmpTicketFolder value"
  exit 16
fi
if [ -z "${DeployIT_SVN_server}" ]; then
  echo "ERROR: Svn_co was called with missing \$DeployIT_SVN_server value"
  exit 16
fi
if [ -z "${TheOpl}" ]; then
  echo "ERROR: Svn_co was called with missing \$TheOpl value"
  exit 16
fi
if [ -z "${OplFolder}" ]; then
  echo "ERROR: Svn_co was called with missing \$OplFolder value"
  exit 16
fi

# Check out de source directory

mkdir ${TmpTicketFolder}/svnupd
cd ${TmpTicketFolder}/svnupd

Svn_set_options

svn ${SvnOpts} co https://${DeployIT_SVN_server}/deployment/${TheOpl}/${OplFolder}
local RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SvnCheckout $RC
fi

if [ $DebugLevel -gt 3 ]; then
  echo "ls van check out folder:"
  ls -lR *
fi

}

Svn_commit() {
## SVN Commit functie
## Input:
## Current folder moet een svn folder zijn
## ${ArgTicketNr} moet het ticket nummer zijn waarvoor ingecheckt moet worden
## ${TmpTicketFolder} een folder met schrijfrechten voor temp bestanden
## Output:
## Geen

if [ -z "${TmpTicketFolder}" ]; then
  echo "ERROR: Svn_commit was called with missing \$TmpTicketFolder value"
  exit 16
fi
if [ -z "${ArgTicketNr}" ]; then
  echo "ERROR: Svn_commit was called with missing \$ArgTicketNr value"
  exit 16
fi
if [ $DebugLevel -gt 3 ]; then
  echo "SVN status output:"
  svn status --depth infinity
fi

Svn_set_options

local TmpStdOut="${TmpTicketFolder}/svncommit.stdout"
local TmpStdErr="${TmpTicketFolder}/svncommit.stderr"

svn ${SvnOpts} commit * --depth infinity -m "TI:${ArgTicketNr}" > ${TmpStdOut} 2> ${TmpStdErr}
local RC=$?

if [ $DebugLevel -gt 3 ]; then
  echo "SVN STDOUT output:"
  cat $TmpStdOut
  echo "SVN STDERR output:"
  cat $TmpStdErr
fi

if [ $RC -ne 0 ]; then
  echo "SVN STDOUT output:"
  cat $TmpStdOut
  echo "SVN STDERR output:"
  cat $TmpStdErr
  deploy_error $DPLERR_SvnCommit "Return code = $RC"
fi
if [[ -s "$TmpStdErr" ]]; then
  echo "SVN call returned an STDERR output:"
  cat $TmpStdErr
  deploy_error $DPLERR_SvnCommit "STDERR output was not empty (see above)"
fi
svnError1="Warning:[[:blank:]]post-commit[[:blank:]]hook[[:blank:]]failed"
if grep -q -e $svnError1 $TmpStdOut; then
  echo "SVN call returned a specific string \"$svnError1\" in STDOUT output:"
  cat $TmpStdOut
  deploy_error $DPLERR_SvnCommit "Specific string \"$svnError1\" was found."
fi
rm $TmpStdOut
rm $TmpStdErr
}

Svn_add() {
## SVN ADD functie, complete folder en subfolders
##            met error checking
## Input:
## Current folder moet een svn folder zijn
## Output:
## Geen

svn add --force * --depth infinity
local RC=$?
if [ $RC -ne 0 ]; then
  echo "svn call in function Svn_add failed. RC=$RC."
  exit 16
fi

}

SSH_to_appl_srv() {
## SSH call to an application server
## Input:
## ${SSHTargetUser}         : The user account with which to connect
## $1                       : The target server to connect to
## $2                       : The command to execute
## Output:
##     NONE

if [ -z "${SSHTargetUser}" ]; then
  echo "call to SSH_to_appl_srv with empty SSHTargetUser value."
  exit 16
fi
LogLineDEBUG "ssh ${SSHDefaultOpts} ${SSHTargetUser}@$1 $2"
ssh ${SSHDefaultOpts} ${SSHTargetUser}@$1 $2

}

SCP_to_appl_srv() {
## SSH call to an application server
## Input:
## ${SSHTargetUser}         : The user account with which to connect
## $1                       : The target server to connect to
## $2                       : The input file to copy
## $3                       : The output file name on the target
## Output:
##     NONE
## Notes:  By default, the recursive option "-r" is used
LogLineDEBUG "scp ${SCPDefaultOpts} $2 ${SSHTargetUser}@$1:$3"
scp ${SCPDefaultOpts} $2 ${SSHTargetUser}@$1:$3

}


#### Convertion functions


ConvertADCTRCToDeployITADC() {
## IN:   $ADCTRC               e.g. KASSA WAR config
## OUT:  $DeployITADC          e.g. KASSA_WAR
##       $DeployITType         e.g. config or WAR or password
##       $DeployITJob          e.g. KASSA_WAR%20config

local JobType="war"
local JobBase=$ADCTRC
if [ "${ADCTRC:(-7)}" == " config" ]; then
  JobType="config"
  JobBase=${ADCTRC% config}
fi
if [ "${ADCTRC:(-9)}" == " password" ]; then
  JobType="password"
  JobBase=${ADCTRC% password}
fi


if [ "${JobBase:(-4)}" == " WAR" ]; then
  JobBase="${JobBase% WAR}_WAR"
fi
if [ "${JobBase:(-4)}" == " BOF" ]; then
  JobBase="${JobBase% BOF}_BOF"
  JobType=""
fi
if [ "${JobBase:(-4)}" == "_BOF" ]; then
  JobType=""
fi
if [ "${JobBase:(-3)}" == "_JB" ]; then
  JobType=""
fi

if [[ ! -z "${JobType}" ]]; then
  echo "JobType2 is is not empty "
  DeployITJob="${JobBase}%20${JobType}"
else
  DeployITJob="${JobBase}"
fi
DeployITADC=$JobBase
DeployITType=$JobType
}


MaakTmpBase() {
## Input:
## ${UnixGroupPckSlv}    : (uit GetEnvData) group voor tmp base
## Output:
## ${TheBaseTmp}         : De locatie van de tmp folder die aangemaakt is
## Als de BaseTmp al bestaat, moet de UnixGroupPckSlv niet meegegeven worden
TheBaseTmp="/data/deploy-it/tmp"

if [ ! -d ${TheBaseTmp} ]; then
  if [ -z "${UnixGroupPckSlv}" ]; then
    echo "ERROR: MaakTmpBase was called with missing \$UnixGroupPckSlv value."
    echo "       This is mostly due to the missing call to GetEnvData."
    exit 16
  fi
  mkdir $TheBaseTmp
  chgrp ${UnixGroupPckSlv} ${TheBaseTmp}
  chmod 770 ${TheBaseTmp}
fi
# Nu weten we dat de TheBaseTmp bestaat, en dat zowel packager
# als slave erin kunnen schrijven.
}

MaakTmpTicketFolder() {
## Input:
## ${ActionType}         : String die aangeeft wat er zal gebeuren
##                         bv. config-depl, verify, dry-run, ...
## ${ArgTicketNr}        : Het ticket nummer waarvoor gewerkt wordt
## ${UnixGroupPckSlv}    : (uit GetEnvData) group voor tmp base
## Output:
## ${TmpTicketFolder}    : De locatie van de tmp folder die aangemaakt is
## Belangrijke opmerking:
##  De TmpTicketFolder houdt GEEN rekening met de omgeving waarvoor
##  gewerkt wordt. Dus een SIM run gaat ook de ACC files overschrijven.
##  Dit stelt normaal geen probleem, want een ticket kan slechts aangeboden
##  worden voor 1 omgeving per keer.
MaakTmpBase
if [ -z "${ActionType}" ]; then
  echo "ERROR: MaakTmpTicketFolder was called with missing \$ActionType value"
  exit 16
fi
if [ -z "${ArgTicketNr}" ]; then
  echo "ERROR: MaakTmpTicketFolder was called with missing \$ArgTicketNr value"
  exit 16
fi
TmpTicketFolder="${TheBaseTmp}/${ActionType}/T${ArgTicketNr}"
## Clean up local traces of previous runs of this same ticket
rm -rf ${TmpTicketFolder}
mkdir -p ${TmpTicketFolder}

}

MaakTmpEnvFolder() {
## Input:
## ${ActionType}         : String die aangeeft wat er zal gebeuren
##                         bv. config-depl, verify, dry-run, ...
## ${ArgEnv}             : De omgeving waarvoor gewerkt wordt
## ${UnixGroupPckSlv}    : (uit GetEnvData) group voor tmp base
## Output:
## ${TmpEnvFolder}       : De locatie van de tmp folder die aangemaakt is
MaakTmpBase
if [ -z "${ActionType}" ]; then
  echo "ERROR: MaakTmpEnvFolder was called with missing \$ActionType value"
  exit 16
fi
if [ -z "${ArgEnv}" ]; then
  echo "ERROR: MaakTmpEnvFolder was called with missing \$ArgEnv value"
  exit 16
fi
TmpEnvFolder="${TheBaseTmp}/${ActionType}/${ArgEnv}"
## Clean up local traces of previous runs of this same action
rm -rf ${TmpEnvFolder}
mkdir -p ${TmpEnvFolder}

}

MaakTmpApplEnvFolder() {
## Input:
## ${ActionType}         : String die aangeeft wat er zal gebeuren
##                         bv. config-depl, verify, dry-run, ...
## ${ArgAppl}            : De ADC waarvoor gewerkt wordt
## ${ArgEnv}             : De omgeving waarvoor gewerkt wordt
## ${UnixGroupPckSlv}    : (uit GetEnvData) group voor tmp base
## Output:
## ${TmpApplEnvFolder}   : De locatie van de tmp folder die aangemaakt is
MaakTmpBase
if [ -z "${ActionType}" ]; then
  echo "ERROR: MaakTmpApplEnvFolder was called with missing \$ActionType value"
  exit 16
fi
if [ -z "${ArgEnv}" ]; then
  echo "ERROR: MaakTmpApplEnvFolder was called with missing \$ArgEnv value"
  exit 16
fi
if [ -z "${ArgAppl}" ]; then
  echo "ERROR: MaakTmpApplEnvFolder was called with missing \$ArgAppl value"
  exit 16
fi
TmpApplEnvFolder="${TheBaseTmp}/${ActionType}/${ArgEnv}/${ArgAppl}"
## Clean up local traces of previous runs of this same action
rm -rf ${TmpApplEnvFolder}
mkdir -p ${TmpApplEnvFolder}

}

CleanTmpFolder() {
## Input:
## ${TmpFolder}      : De specifieke TmpFolder die opgeruimd moet
##                     worden.
## ${DeployIT_Keep_Temporary_Files}   : Flag die aangeeft of tmp files
##                                      behouden moeten worden.

if [ -z "${TmpFolder}" ]; then
  echo "ERROR: CleanTmpFolder was called with missing \$TmpFolder value"
  exit 16
fi
if [ -z "${DeployIT_Keep_Temporary_Files}" ]; then
  ## Set default: delete Temp files
  DeployIT_Keep_Temporary_Files=0
fi
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpFolder}
fi

}


CleanAll() {
if [ ! -z "${TmpTicketFolder}" ]; then
  TmpFolder=${TmpTicketFolder}
  CleanTmpFolder
fi
if [ ! -z "${TmpEnvFolder}" ]; then
  TmpFolder=${TmpEnvFolder}
  CleanTmpFolder
fi
if [ ! -z "${TmpApplEnvFolder}" ]; then
  TmpFolder=${TmpApplEnvFolder}
  CleanTmpFolder
fi
}
trap CleanAll 0


### Helper Functions
BackupDir() {
# Input:	Dir			GLB_installFolder
#			Share		GLB_BackupFolder
#			gunzip		1 || 0

Compress=0
if [[ "${#}" -eq 1 ]]; then
  if [[ "${1}" -ne 0 ]]; then
    Compress=1
  fi
fi

backupShare="/tmp/share/"
local BackupFile="$(date \"+%Y%m%d\")_${ADC}.tar"
if [[ ! -d ${InstallFolder} && ! -r ${InstallFolder} ]]; then
  # can't backup non-readable or non-existing folder.
  deploy_error $DPLERR_BackupInvalidDir ${InstallFolder}
fi

if [[ -e "${BackupDir}/${BackupFile}" ]]; then
  LogLineINFO "Backup ${BackupFile} already seems to exist."
else
  if [[ ${Compress} -eq 0 ]]; then
    RC=$(tar --preserve --acls -cf ${backupShare}/${BackupFile} ${BackupDir})
  else
    BackupFile="${BackupFile}.gz"
    RC=$(tar --preserve --acls -czf ${backupShare}/${BackupFile} ${BackupDir})
  fi
  if [[ "${RC}" -eq 0 ]]; then
    LogLineINFO "Succesfuly backed up the Dir='\${BackupDir}'"
  else
    deploy_error $DPLERR_BackupFailed
  fi
fi
}
Rollback(){
# Input:	InputTar
Compress=0
if [[ ${#} -eq 1 ]]; then
  if [[ ! -z ${1} ]]; then
    tarfile="${1}"
    if [[ ! -e "${tarfile}" && ! -r "${tarfile}" ]]; then
	  deploy_error $DPLERR_RollbackInvalidTar ${tarfile}
	fi
  else
    deploy_error $DPLERR_RollbackInvalidTar ${1}
  fi	
else
  deploy_error $DPLERR_RollbackMissingParam
fi

if [[ ! -d ${InstallFolder} && ! -w ${InstallFolder} ]]; then
  deploy_error $DPLERR_RollbackInvalidDest
fi

if [[ $(echo ${tarfile} | grep gz) -eq 0 ]]; then
  RC=$(tar --preserve --acls -C "${InstallFolder}" -xzf "${tarfile}")
else
  # non-gunzipped tar.
  RC=$(tar --preserve --acls -C "${InstallFolder}" -xf "${tarfile}")
fi
if [[ "${RC}" -eq 0 ]]; then
  LogLineINFO "Succesfuly rolled back ADC='\$ADC' from tar='\${tarfile}'."
else
  deploy_error $DDPLERR_RollbackFailed ${ADC} ${tarfile}
fi
}
UntarFile(){
##	This function will extract a tarfile to the directory listed
##		Input:	Tarfile
##				DestinationDir
##				Force_overwrite: Optional
##				ClearDestination: Optional
##				Tar_Options: Optional
##		Output: None
## Example: ExtractTarFile /tmp/toUntar.tar /tmp/toDirectory 0 0
#echo "${SHELL}" | grep -i bash
#uname -s | grep -i "linux"
case $(uname) in
  HP-UX*)
    LogLineDEBUG "Running on a HP-UX system."
	GtarBinary="/usr/local/bin/gtar"
    typeset TarFile=""
    typeset DestinationDir=""
    typeset -i ForceOverwrite=0		#Optional 0=False;1=True
    typeset -i ClearDestination=0	#Optional 0=False;1=True
    ;;
  Linux*)
    LogLineDEBUG "Running on a linux system."
    GtarBinary=$(which tar)
    local TarFile=""
    local DestinationDir=""
    local -i ForceOverwrite=0	#Optional 0=False;1=True
    local -i ClearDestination=0	#Optional 0=False;1=True
    ;;
  *)
    LogLineWARN "Running on an unsupported system-type."
    exit 16
#    GtarBinary=\$(which tar)
#    local TarFile=""
#    local DestinationDir=""
#    local -i ForceOverwrite=0	#Optional 0=False;1=True
#    local -i ClearDestination=0	#Optional 0=False;1=True
    ;;
esac

if [[ "${#}" -lt 2 && "${#}" -gt 4 ]]; then 
  echo "UntarFile() Needs at least 2 parameters, maximum 4." \
   "Tarfile:			File which need to be untarred." \
   "Destination:		Destination to which the untar must run." \
   "ForceOverwrite:		<Optional> 0=False;1=True" \
   "ClearDestination:	<Optional> 0=False;1=True" \
   "Exiting Now"
  deploy_error $DPLERR_UntarMissingParam
else
  # Check if tarfile is valid and readable
  if [[ ! -z "${1}" && -r "${1}" ]]; then
    TarFile="${1}"
	LogLineINFO "Using ${TarFile}" 
  else
    deploy_error $DPLERR_InvalidTarFile "${1}"
  fi
  
  # Check if destination directory is valid and writable
  if [[ ! -z "${2}" && -w "${2}" ]]; then
    DestinationDir="${2}"
  else
    deploy_error $DPLERR_InvalidDestDir "${2}"
  fi
  
  # Check if we are given more parameters.
  if [[ "${#}" -gt 2 ]]; then
    # Parse 3th Param.
    if [ "${3}" -gt 0  ]]; then
      LogLineINFO "We will overwrite the DestinationDir \"${DestinationDir}\"."
	  ForceOverwrite=1
    else
      LogLineINFO "We Won't overwrite the DestionationDir \"${DestinationDir}\"."
	  ForceOverWrite=0
    fi
  fi 
  if [[ "${#}" -gt 3 ]]; then
    # Parse 4th Param
	# check if we need to clean the destination directory before untarring.
	if [[ "${4}" -gt 0 ]]; then
	  LogLineINFO "We will clear the destionation directory \"${DestinationDir}\" before untarring."
	  ClearDestination=1
	else
	  LogLineINFO "We won't clear the destination directory \"${DestinationDir}\" before untarring."
	  ClearDestination=0
	fi
  fi
fi

# Clear Destination if required.
if [[ "${ClearDestination}" ]]; then
  rm -f "${DestionationDir}"/*
  if [[ "${RC}" -eq 0 ]]; then
    LogLineINFO "Succesfully cleared the DestinationDir \"${DestinationDir}\"."
  else
    LogLineDEBUG "Failed to clean the DestinationDir \"${DestinationDir}\" even though this was necessary, exiting now."
	exit 16
	deploy_error $DPLERR_UntarClearDestinationDir "${DestionationDir}"
  fi
fi
# Add overwrite option if required
if [[ "${ForceOverwrite}" ]]; then
  if [[ $(echo ${TarFile} | grep "gz$") -eq 0 ]]; then
    RC=$(tar --preserve-permissions  --acls --overwrite -C "${DestinationDir}" --overwrite -xzf "${TarFile}")
  else 
    RC=$(tar --preserve-permissions  --acls --overwrite -C "${DestionationDir}" -xf "${TarFile}")
  fi
  if [[ "${RC}" -eq 0 ]]; then
    LogLineINFO "Succesfully untarred \"${TarFile}\" to \"${DestinationDir}\" with overwrite option."
  else
	deploy_error $DPLERR_UntarFailedWithOverwrite "${Tarfile}" "${DestionationDir}"
  fi
else
  if [[ $(echo ${TarFile} | grep "gz$") -eq 0 ]]; then
    RC=$(tar --preserve-permissions --same-owner --acls -C "${DestinationDir}" -xzf "${TarFile}")
  else 
    RC=$(tar --preserve-permissions --same-owner --acls -C "${DestionationDir}" -xf "${TarFile}")
  fi
  if [[ "${RC}" -eq 0 ]]; then
    LogLineINFO "Succesfully untarred \"${TarFile}\" to \"${DestinationDir}\" without overwrite option."
  else
    deploy_error $DPLERR_UntarFailedWithoutOverwrite "${Tarfile}" "${DestionationDir}"
  fi
fi
}
TarFile(){
##	This function will build a tarfile from the directory or file listed
##		Input:	${SrcDir} ${DstDir} ${DstFile} [${gunzip}]
##		Input:	Tarfile
##				DestinationDir
##              Destination Filename
##				Gunzip: Optional 0=No|1=Yes
##		Output: None
## Example: TarFile /tmp/ /tmp/toDirectory temp.tar 0
case $(uname) in
  HP-UX*)
    LogLineDEBUG "Running on a HP-UX system."
	GtarBinary="/usr/local/bin/gtar"
    typeset SrcDir=""
    typeset DstDir=""
	typeset DstFile=""
    typeset -i Compress=0		#Optional 0=False;1=True
    ;;
  Linux*)
    LogLineDEBUG "Running on a linux system."
	GTarBinary=$(which tar)
    local SrcDir=""
    local DstDir=""
	local DstFile=""
	local -i compress=0			#Optional 0=False;1=True
    ;;
  *)
    LogLineWARN "Running on an unknown system-type."
    GTarBinary=$(which tar)
    local SrcDir=""
    local DstDir=""
	local DstFile=""
	local -i compress=0			#Optional 0=False;1=True
    ;;
esac

if [[ "${#}" -lt 3 && "${#}" -gt 4 ]]; then 
  echo "TarFile() Needs at least 3 parameters, maximum 4." \
   "SrcDir:			Source to tar." \
   "DstDir:			Destination dir of tar" \
   "DstFile:		The new tar-filename" \
   "Compress:	<Optional> 0=False;1=True" \
   "Exiting Now"
  deploy_error $DPLERR_TarMissingParam
else
  # Check if SrcDir is valid and readable
  if [[ ! -z "${1}" && -r "${1}" ]]; then
    SrcDir="${1}"
	LogLineINFO "Tarring the file/folder \"${SrcDir}\"" 
  else
    deploy_error $DPLERR_InvalidTarFolder "${1}"
  fi
  
  # Check if DstDir is valid and writable
  if [[ ! -z "${2}" && -w "${2}" ]]; then
    DstDir="${2}"
  else
    deploy_error $DPLERR_InvalidDestDir "${2}"
  fi
  
  # Check if The DstDir does exist, but the to-build tar not.
  if [[ -e "${DstDir}" && ! -e "${DstDir}/${3}" ]]; then
    ## file doesn't exist yet.
	DstFile=${3}
	LogLineINFO "Will tar to \"${DstDir}/${DstFile}\"."
  else
    ## File already exists.
	LogLineDEBUG "Somehow the to-build tar already exists."
  fi
  
  if [[ "${#}" -gt 3 ]]; then
    # Parse 4th Param
	# check if we need to clean the compress the tar.
	if [[ "${4}" -gt 0 ]]; then
	  LogLineINFO "We will compress the tar \"${DstFile}\"."
	  Compress=1
	else
	  LogLineINFO "We won't compress the tar \"${DstFile}\"."
	  Compress=0
	fi
  fi
fi

# Compress if required

if [[ "${Compress}" ]]; then
  RC=$(tar --preserve-permissions --same-owner --acls -czf "${DstDir}/${DstFile}" "${SrcDir}")
else 
  RC=$(tar --preserve-permissions --same-owner --acls -cf "${DstDir}/${DstFile}" "${SrcDir}")
fi
if [[ "${RC}" -eq 0 ]]; then
  if [[ ${Compress} ]]; then
    LogLineINFO "Succesfully tarred \"${SrcDir}\" to \"${DstFile}\" with compress option."
  else
    LogLineINFO "Succesfully tarred \"${SrcDir}\" to \"${DstFile}\" without compress option."
  fi
else
  deploy_error $DPLERR_tarFailedWithCompress "${DstFile}" "${DestionationDir}"
fi
}
SavePermissions(){
## This function will save the permissions to a specified file.
##
##	Input:	InputFolder >	Should be the global-InstallFolder
##			OutputFile	>	Should be the TmpTicketFolder/acl.txt
##	Output: Outputfile	>	Should be the same as above.
case $(uname) in
  HP-UX*)
    LogLineDEBUG "Running on a linux system."
    typeset InputFolder=""
    typeset OutputFile=""
    typeset SetACLBin=$(which setacl)
	typeset GetACLBin=$(which getacl)
    ;;
  Linux*)
    LogLineDEBUG "Running on a linux system."
    local InputFolder=""
    local OutputFile=""
	local SetACLBin=$(which setfacl)
	local GetAclBin=$(which getfacl)
    ;;
  *)
    LogLineINFO "Running on an unknown system."
    ;;
esac
  
if [[ "${#}" -ne 2 ]]; then
  LogLineDEBUG "SavePermissions() Needs 2 parameters."
  LogLineDEBUG "InputFolder:	Folder for which we need to save the permissions."
  LogLineDEBUG "OutputFile:		Absolute path to Outputfile to where we will save"
  LogLineDEBUG "				the permissions."
  LogLineDEBUG ""
  deploy_error $DPLERR_SavePermissionsMissingParam
else
  # We have the mandetory parameters.
  # Check validity of directory.
  if [[ ! -z "${1}" && -r "${1}" ]]; then
    InputFolder="${1}"
  else
    deploy_error $DPLERR_SavePermissionsInvalidDir "${1}"
  fi
  # check the validity of the outputfile.
  if [[ ! -z "${2}" ]]; then
    OutPutFile="${2}"
	Currentdir="$(pwd)"
    OutDir="$(cd "$(dirname "${2}")" && pwd)"
	if [[ "${?}" -ne 0 ]]; then
	  LogLineWARN "Failed to find the absolute directory of the output file ${OutPutFile}."
	fi
	cd "${Currentdir}"
	FileName="$(basename "${2}")"
	OutputFile="${OutDir}/${FileName}"
	touch "${OutputFile}"
	if [[ "${?}" -ne 0 ]]; then
	  echo "Failed to create file \"${OutputFile}\"."
	  return 3
	  deploy_error $DPLERR_SavePermissionsInvalidFile "${OutputFile}"
	fi
  fi
  ${GetAclBin} -R "${InputFolder}" > "${OutputFile}"
  if [[ "${?}" -eq 0 ]]; then
    echo "Succesfully saved the permissions of directory \"*{InputFolder}\"."
  else
    echo "Failed saving the permissions of directory \"*{InputFolder}\"."
	return 4
	deploy_error $DPLERR_SavePermissionsFailed "${InputFolder}" "${OutPutFile}"
  fi
fi
return 0
}
ResetPermissions(){
## This function will reset the permissions accordingly
##	Input:	Directory			>	Should be installFolder
##			InputFile <ACL>		>	Should be ACLFile
##
#echo "${SHELL}" | grep -i bash
case $(uname -o) in
  HP-UX*)
    LogLineDEBUG "Running on a HP-UX system."
    typeset InputFolder=""
    typeset InputACL=""
	typeset SetACLBin=$(which setacl)
	typeset GetACLBin=$(which getacl)
    ;;
  Linux*)
    LogLineDEBUG "Running on a linux system."
    local InputFolder=""
    local InputACL=""
	local SetACLBin=$(which setfacl)
	local GetAclBin=$(which getfacl)
    ;;
  *)
    LogLineWARN "Running on an unknown system-type."
    local InputFolder=""
    local InputACL=""
	local SetACLBin=$(which setfacl)
	local GetAclBin=$(which getfacl)
    ;;
esac

if [[ "${#}" -lt 2 ]]; then
  deploy_error $DPLERR_ResetPermissionsMissingParam
  echo "Usage: $ResetPermissions() <InputFolder> <InputACL>"
  return 1
fi

if [[ ! -z "${1}" ]]; then
  InputFolder="${1}"
  if [[ ! -w "${InputFolder}" ]]; then 
	deploy_error $DPLERR_ResetPermissionsInvalidDir "${InputFolder}"
  fi
else
  deploy_error $DPLERR_ResetPermissionsInvalidDir "${InputFolder}"
fi   

if [[ ! -z "${2}" ]]; then
  InputACL="${2}"
  if [[ ! -r "${InputACL}" ]]; then
    echo "Can't read from the provided InputFile \"${InputACL}\"."
	return 3
	deploy_error $DPLERR_ResetPermissionsInvalidACL "${InputACL}"
  fi
  echo "Passed empty string as InputFile to ResetPermissions()."
  deploy_error $DPLERR_ResetPermissionsInvalidACL "${InputACL}"
else
  deploy_error $DPLERR_ResetPermissionsInvalidACL "${InputACL}"
fi
  
echo "Resetting permissions of directory \"${InputFolder}\" using inputfile \"${InputACL}\"."
${SetACLBin} --restore="${InputACL}"
if [[ "${?}" -eq 0 ]]; then
  LogLineINFO "Succesfully restored permissions of directory \"${InputFolder}\" using ACL-File \"${InputACL}\"."
  return 0
else
  echo "Failed restoring permissions of directory \"${InputFolder}\" using ACL-File \"${InputACL}\"."
  return 3
  deploy_error $DPLERR_ResetPermissionsFailed "${InputFolder}" "${InputACL}"
fi
}


