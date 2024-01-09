#!/bin/bash

#### deploy_cleaning_tmp.sh script
#
# This script cleans old files from the tmp dirs on the jenkins
# build nodes.
#
# Command line options:
#          $1    Age in days (optional, default = 30 days)
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
ScriptName="deploy_cleaning_tmp.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DebugLevel=1

if [ "$1" = "" ]; then
  ArgCleanOlderThanDays=30
else
  ArgCleanOlderThanDays=$1
fi
ArgSlv=$2
echo "Alle tmp folders ouder dan $ArgCleanOlderThanDays dagen zullen opgekuist worden."
echo "Options are:"
echo "  AGE = '${ArgCleanOlderThanDays}'"
echo "  SLAVE = '${ArgSlv}'"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

ActionType="cleaning-tmp-${ArgSlv}"
ArgEnv="SLV"
MaakTmpEnvFolder
cd ${TmpEnvFolder}
pwd

TmpBaseFolder="/data/deploy-it/tmp"
echo "Base folder die zal opgekuist worden: $TmpBaseFolder"

### Geef informatief huidige diskspace van de folder
echo "Totale diskspace gebruikt binnen de base folder:"
du -hs $TmpBaseFolder 2> >(grep -v 'Permission denied')

### Make string met juiste time contrstraint voor find
findmtime="+$ArgCleanOlderThanDays"
user=$(whoami)

### Print informatief de lijst met files via find met optie -print
echo "folder lijst die zal opgekuist worden:"
find $TmpBaseFolder -mindepth 2 -maxdepth 2 -regex ".*T[0-9]*" -type d -user $user -mtime "$findmtime" -print 2> >(grep -v 'Permission denied')
echo "einde van folder lijst die zal opgekuist worden."

### Zelfde find, maar nu met optie -printf om rm commandos te maken
### rm opties zijn -fr (force en recursive)
### %p is de filenaam van de gevonden folder
### \n is de line ending
echo "genereren van opkuisinstructies ..."
find $TmpBaseFolder -mindepth 2 -maxdepth 2 -regex ".*T[0-9]*" -type d -user $user -mtime "$findmtime" -printf "rm -fr %p\n" >> "${TmpEnvFolder}/cleanlist.txt" 2> >(grep -v 'Permission denied')

### uitvoeren via het source commando.
echo "uitvoeren van de opkuisinstructies ..."
source "${TmpEnvFolder}/cleanlist.txt"

### Geef informatief huidige diskspace van de folder
echo "Totale diskspace gebruikt binnen de base folder na de opkuisactie:"
du -hs $TmpBaseFolder 2> >(grep -v 'Permission denied')

exit 0
