#!/bin/bash

#### deploy_cleaning_fromfs.sh script
#
# This script cleans old files from the shared file system
# where files are put to be picked up by scripts that are
# sent to the target machines.
#
# Command line options:
#          $1    Age in days (optional, default = 10 days)
#
# Output:
#          NONE
#          RC  = 0 if all is OK
#          RC  = 16 if at least one problem was encountered
#
#################################################################
# Change history
#################################################################
#      #             #
#      #             #
#      #             #
#################################################################
#
ScriptName="deploy_cleaning_fromfs.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DebugLevel=1

if [ "$1" = "" ]; then
  ArgCleanOlderThanDays=10
else
  ArgCleanOlderThanDays=$1
fi
echo "Alle ticket folders ouder dan $ArgCleanOlderThanDays zullen opgekuist worden."


source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

ActionType="cleaning-fromfs"
ArgEnv="SLV"
MaakTmpEnvFolder
cd ${TmpEnvFolder}
pwd

### Voor de call naar GetDeployITSettings is een
### temp folder nodig. Die hebben we net aangemaakt.
TmpFld=$TmpEnvFolder
### Bepaal op welke Autodeploy instance we zitten
### Dit is nodig omdat de shared folder die we cleanen
### daarvan afhangt. Die zit in $ConfigNfsFolderOnServer
### en wordt beheerd via de DEPLOY-IT placeholders.
### De Env en ADC variabelen zijn hier niet nodig.
TheEnv="***"
TheADC="***"
GetDeployITSettings

NfsBaseFolder="${ConfigNfsFolderOnServer}"
echo "Base folder die zal opgekuist worden: $NfsBaseFolder"

### Geef informatief huidige diskspace van de folder
echo "Totale diskspace gebruikt binnen de base folder:"
du -hs $NfsBaseFolder

### Make string met juiste time contrstraint voor find
findmtime="+$ArgCleanOlderThanDays"

### Print informatief de lijst met files via find met optie -print
echo "folder lijst die zal opgekuist worden:"
find $NfsBaseFolder -regex ".*T[0-9]*" -type d -mtime "$findmtime" -print
echo "einde van folder lijst die zal opgekuist worden."

### Zelfde find, maar nu met optie -printf om rm commandos te maken
### rm opties zijn -fr (force en recursive)
### %p is de filenaam van de gevonden folder
### \n is de line ending
echo "genereren van opkuisinstructies ..."
find $NfsBaseFolder -regex ".*T[0-9]*" -type d -mtime "$findmtime" -printf "rm -fr %p\n" >> "${TmpEnvFolder}/cleanlist.txt"

### uitvoeren via het source commando.
echo "uitvoeren van de opkuisinstructies ..."
source "${TmpEnvFolder}/cleanlist.txt"

### Geef informatief huidige diskspace van de folder
echo "Totale diskspace gebruikt binnen de base folder na de opkuisactie:"
du -hs $NfsBaseFolder
