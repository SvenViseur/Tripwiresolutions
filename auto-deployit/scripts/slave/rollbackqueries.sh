#!/bin/bash

#### rollbackqueries.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     TICKETNR		: The ticket number being deployed
#     ENV		: The environment on which to rollback
#     HOTENV		: The environment that provides the HOT tables
#                         default is PRD
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa     # 20/06/2019    # 1.0.0   # initial version                      #
#          # 24/07/2019    # 1.1.0   # move output to html report file      #
#          #   /  /        #         #                                      #
#          #   /  /        #         #                                      #
#############################################################################
#

ScriptName="rollbackqueries.sh"
ScriptVersion="1.1.0"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

SQLPLUS_PATH=""
SQLCommand=""
SQLOutput=""

RunSQLCmd() {
  ## this function takes string SQLCommand, executes it against
  ## the database, and stores the resulting data in SQLOutput
SQLOutput=$(echo "set heading off linesize 400 feedback off pagesize 50000 colsep \",\";
${SQLCommand}" | ${SQLPLUS_PATH})

}

EchoOF() {
  echo $1 >> ${OutputFile}
}


DebugLevel=3
ArgTicketNr=$1
ArgEnv=$2
ArgHOTEnv=$3
OutputFile="${WORKSPACE}/report_${ArgTicketNr}.html"
echo "Output will be written to file $OutputFile"
##read the credentials settings
credfile="${ConfigDataFolder}/credentials/handover-tool_settings.conf"
dbuserline=$(grep "db.user" "$credfile")
dbuser=${dbuserline:8}
dbpasswordline=$(grep "db.password" "$credfile")
dbpassword=${dbpasswordline:12}

if [[ "$ArgHOTEnv" = "" ]]; then
  DB_HOST="(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=TLS_PRD)(PORT=1613))(CONNECT_DATA=(SID=TLS_PRD)))"
fi
if [[ "$ArgHOTEnv" = "SIM" ]]; then
  DB_HOST="(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=TLS_SIM)(PORT=1613))(CONNECT_DATA=(SID=TLS_SIM)))"
fi
if [[ "$ArgHOTEnv" = "ACC" ]]; then
  DB_HOST="(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=TLS_ACC)(PORT=1613))(CONNECT_DATA=(SID=TLS_ACC)))"
fi

SQLPLUS_PATH="/usr/bin/sqlplus -s ${dbuser}/${dbpassword}@${DB_HOST}"

## Write html header to the output file
EchoOF "<!DOCTYPE html>"
EchoOF "<html lang=""en"">"
EchoOF "  <head>"
EchoOF "    <meta charset=""utf-8"">"
EchoOF "    <title>Rollback report TI-${ArgTicketNr} for ${ArgEnv}</title>"
EchoOF "  </head>"
EchoOF "  <body>"

CurDate=$(date)

## Write html body header
EchoOF "<h1>Rollback analyse voor ticket ${ArgTicketNr}</h1>"
EchoOF "<h2>Report details</h2>"
EchoOF "Rapport gemaakt op $CurDate</br>"
EchoOF "Server: $HOSTNAME</br>"
EchoOF "Jenkins build tag: ${BUILD_TAG}</br>"
EchoOF "Jenkins build URL: <a href=""${BUILD_URL}"">link</a>"
if [[ "$ArgHOTEnv" = "SIM" ]]; then
  EchoOF "<div style=""text-align:center;border:3px solid red"">WAARSCHUWING! Deze analyse gebeurde met de HOT data van $ArgHOTEnv en niet van PRD!</div>"
fi
if [[ "$ArgHOTEnv" = "ACC" ]]; then
  EchoOF "<div style=""text-align:center;border:3px solid red"">WAARSCHUWING! Deze analyse gebeurde met de HOT data van $ArgHOTEnv en niet van PRD!</div>"
fi
EchoOF "</br>"

## determine list of objects in the ticket based on HOT query
SQLCommand="SELECT DISTINCT HOT_CFM.PATH FROM HOT.HOT_CFM HOT_CFM WHERE HOT_CFM.TIC_NBR=$ArgTicketNr AND HOT_CFM.ENV='$ArgEnv' AND HOT_CFM.ERR='N';"
RunSQLCmd
OIFS=$IFS
IFS=$'\n'
## read -a ItemList <<< $SQLOutput
ItemList=($SQLOutput)
IFS=$OIFS

## Write html info on result
EchoOF "<h2>Analysis results</h2>"
EchoOF "Aantal objecten in het ticket: ${#ItemList[@]}"

## Check whether all objects were last deployed using the current ticket
AllItemsOK=1
for Item in "${ItemList[@]}"
do
  # read the most recent version for the current env
  SQLCommand="SELECT HOT_CFM.REV, to_char(HOT_CFM.DTE,'yyyy-mm-dd HH24:mi:ss'), HOT_CFM.TIC_NBR
              FROM HOT.HOT_CFM HOT_CFM
              WHERE HOT_CFM.PATH='$Item' AND HOT_CFM.ENV='$ArgEnv' AND
              HOT_CFM.DTE=(SELECT MAX(M.DTE) FROM HOT.HOT_CFM M WHERE M.PATH='$Item' AND
                           M.ENV='$ArgEnv' AND M.ERR='N');"
  RunSQLCmd
  ## echo $SQLOutput
  IFS="," read IVrs IDte ITic <<< $SQLOutput
  ## echo "Most recent deploy was done by ticket $ITic on date $IDte for version $IVrs"
  # remove leading whitespace characters
  ITic="${ITic#"${ITic%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  ITic="${ITic%"${ITic##*[![:space:]]}"}"   
  # Test if it is our current ticket
  if [[ "$ITic" = "$ArgTicketNr" ]]; then
    echo "most recent deploy of $Item was with current ticket. Continuing analysis"
  else
    echo "ERROR: The most recent deploy of object $Item in environment $ArgEnv was done"
    echo "by ticket $ITic, which is a different ticket you want to rollback."
    EchoOF "<p style=""color:red;""><strong>FOUT!</strong> Het object $Item werd laatst"
    EchoOF "uitgerold naar omgeving $ArgEnv door ticket <strong>$ITic</strong> en dus niet door ticket $ArgTicketNr."
    EchoOF "Hierdoor kan de analyse NIET verder gaan.</p></br>"
    AllItemsOK=0
  fi
done
if [ $AllItemsOK -eq 0 ]; then
  EchoOF "Wegens bovenstaande problemen wordt de analyse hier afgebroken.</br>"
  EchoOF "  </body>"
  EchoOF "</html>"
  exit 16
fi

## Alle objecten zijn consistent met het opgegeven ticket. Maak een rapport

## Table header in html
EchoOF "<table style=""width:100%"" border=""1"">"
EchoOF "<tr><th>Omgeving</th><th>Welke</th><th>SVN versie</th><th>TraceIT ticket</th><th>Deploy date</th></tr>"

## Cycle over each object, and analyse possible candidate rollback versions
echo "Number of items in ticket: ${#ItemList[@]}"
for Item in "${ItemList[@]}"
do
  echo "Analysis for object $Item"
  EchoOF "<tr><td colspan=""5"" style=""background-color:LightGray""><div style=""text-align:center;font-size:large;"">Object $Item</div></td></tr>"
  # read the most recent version for the current env
  SQLCommand="SELECT HOT_CFM.REV, to_char(HOT_CFM.DTE,'yyyy-mm-dd HH24:mi:ss'), HOT_CFM.TIC_NBR
              FROM HOT.HOT_CFM HOT_CFM
              WHERE HOT_CFM.PATH='$Item' AND HOT_CFM.ENV='$ArgEnv' AND
              HOT_CFM.DTE=(SELECT MAX(M.DTE) FROM HOT.HOT_CFM M WHERE M.PATH='$Item' AND
                           M.ENV='$ArgEnv' AND M.ERR='N');"
  RunSQLCmd
  ## echo $SQLOutput
  IFS="," read IVrs IDte ITic <<< $SQLOutput
  ## echo "Most recent deploy was done by ticket $ITic on date $IDte for version $IVrs"
  CurVrs=$IVrs
  EchoOF "<tr><td>$ArgEnv</td><td>Huidige versie</td><td>$IVrs</td><td>$ITic</td><td>$IDte</td></tr>"
  
  ## Find last good deploy of Item, excluding the current ticket nr
  SQLCommand="SELECT HOT_CFM.REV, to_char(HOT_CFM.DTE,'yyyy-mm-dd HH24:mi:ss'), HOT_CFM.TIC_NBR
              FROM HOT.HOT_CFM HOT_CFM
              WHERE HOT_CFM.PATH='$Item' AND HOT_CFM.ENV='$ArgEnv' AND
              HOT_CFM.DTE=(SELECT MAX(M.DTE) FROM HOT.HOT_CFM M WHERE M.PATH='$Item' AND
                           M.ENV='$ArgEnv' AND M.TIC_NBR<>$ArgTicketNr AND M.ERR='N');"
  RunSQLCmd
  ## echo $SQLOutput
  IFS="," read IVrs IDte ITic <<< $SQLOutput
  EchoOF "<tr><td>$ArgEnv</td><td>Vorige versie</td><td>$IVrs</td><td>$ITic</td><td>$IDte</td></tr>"
  echo "Candidate found: previous version in environment $ArgEnv:"
  echo "Version $IVrs was deployed on $IDte via ticket $ITic"
  
  if [[ "$ArgEnv" = "ACC" ]]; then
    echo "There is no lower environment to analyse. Skipping."
  else
    LowerEnv="ACC"
    if [[ "$ArgEnv" = "VAL" ]]; then
      LowerEnv="SIM"
    fi
    if [[ "$ArgEnv" = "PRD" ]]; then
      LowerEnv="VAL"
    fi
    ## Find last good deploy of Item on LowerEnv, excluding the current ticket nr
    SQLCommand="SELECT HOT_CFM.REV, to_char(HOT_CFM.DTE,'yyyy-mm-dd HH24:mi:ss'), HOT_CFM.TIC_NBR
              FROM HOT.HOT_CFM HOT_CFM
              WHERE HOT_CFM.PATH='$Item' AND HOT_CFM.ENV='$LowerEnv' AND
              HOT_CFM.DTE=(SELECT MAX(M.DTE) FROM HOT.HOT_CFM M WHERE M.PATH='$Item' AND
                           M.ENV='$LowerEnv' AND M.TIC_NBR<>$ArgTicketNr AND M.ERR='N');"
    RunSQLCmd
    ## echo $SQLOutput
    IFS="," read IVrs IDte ITic <<< $SQLOutput
    if [ -n "$IVrs" ]; then 
      EchoOF "<tr><td>$LowerEnv</td><td>Laatste BDT</td><td>$IVrs</td><td>$ITic</td><td>$IDte</td></tr>"
      echo "Candidate found: valid version in environment $LowerEnv:"
      echo "Version $IVrs was deployed on $IDte via ticket $ITic"
    else
      EchoOF "<tr><td>$LowerEnv</td><td colspan=""4"">Geen enkele versie gevonden</td></tr>"
      echo "No valid version found in environment $LowerEnv."
    fi
  fi
  
  if [[ "$ArgEnv" = "PRD" ]]; then
    echo "There is no higher environment to analyse. Skipping."
  else
    HigherEnv="PRD"
    if [[ "$ArgEnv" = "ACC" ]]; then
      HigherEnv="SIM"
    fi
    if [[ "$ArgEnv" = "SIM" ]]; then
      HigherEnv="VAL"
    fi
    ## Find last good deploy of Item on HigherEnv, excluding the current ticket nr
    SQLCommand="SELECT HOT_CFM.REV, to_char(HOT_CFM.DTE,'yyyy-mm-dd HH24:mi:ss'), HOT_CFM.TIC_NBR
              FROM HOT.HOT_CFM HOT_CFM
              WHERE HOT_CFM.PATH='$Item' AND HOT_CFM.ENV='$HigherEnv' AND
              HOT_CFM.DTE=(SELECT MAX(M.DTE) FROM HOT.HOT_CFM M WHERE M.PATH='$Item' AND
                           M.ENV='$HigherEnv' AND M.TIC_NBR<>$ArgTicketNr AND M.ERR='N');"
    RunSQLCmd
    ## echo $SQLOutput
    IFS="," read IVrs IDte ITic <<< $SQLOutput
    if [ -n "$IVrs" ]; then 
      EchoOF "<tr><td>$HigherEnv</td><td>Laatste BDT</td><td>$IVrs</td><td>$ITic</td><td>$IDte</td></tr>"
      echo "Candidate found: valid version in environment $HigherEnv:"
      echo "Version $IVrs was deployed on $IDte via ticket $ITic"
    else
      EchoOF "<tr><td>$HigherEnv</td><td colspan=""4"">Geen enkele versie gevonden</td></tr>"
      echo "No valid version found in environment $HigherEnv."
    fi
  fi
done
## Sluit html table
EchoOF "</table>"
EchoOF "Einde van de analyse voor dit ticket.</br>"

## Write html trailer to the output file
EchoOF "  </body>"
EchoOF "</html>"

