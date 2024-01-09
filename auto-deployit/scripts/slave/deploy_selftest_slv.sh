#!/bin/bash

#### deploy_selftest_slv.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs a selftest of a deployer slave server.
# It is only meant to be run on Jenkins slaves that have that
# functionality. Key tests in this selftest are:
# presence of deployit scripts and csv files
# presence of java, svn, handover and replace tools
# presence of specific credentials files
# presence of a mount point on the okfs server
# determine whether at least one application server is
#     reachable
#
# Command line options:
#          NONE
# Output:
#          NONE
#          RC  = 0 if all is OK
#          RC  = 16 if at least one problem was encountered
#
#################################################################
# Change history
#################################################################
# dexa # aug/2016    # initial version
# dexa # aug/2016    # add test for replace tool
#      #             # add initial list of ls commands om
#      #             #   beter te kunnen debuggen
# dexa # aug/2016    # split in _pck and _slv part
# dexa # 07/10/2016  # call MaakTmpTicketFolder en CleanTmpFolder
# dexa # 04/09/2018  # toev test 6: ook svn is nodig op slv
# dexa # 12/11/2018  # toev ls voor IWS folders
# vevi # 19/11/2018  # toev check voor oracle DB connectie
# dexa # 25/02/2019  # add 3B with grep of ScriptVersion string
# dexa # 21/03/2019  # add ls of deploy-it/tmp folder and groups
# dexa # 21/03/2019  #  1.0.0  # add version info
# dexa # 08/05/2019  #  1.1.0  # toev Oracle software check
# dexa # 30/01/2020  #  1.1.1  # ls ook subdirs van scripts (ivl)
# dexa # 20/11/2020  #  1.1.2  # cd naar homefolder after delete tmpfolder
#################################################################
#

ScriptName="deploy_selftest_slv.sh"
ScriptVersion="1.1.1"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ErrorCount=0
WarningCount=0

# Test 0: Preliminary information commands that
#         can assist during debugging
echo "whoami"
whoami
echo "groups that I am member of:"
groups $(whoami)
echo "hostname"
hostname
echo "uname -a"
uname -a
echo "pwd"
pwd
echo "ls -ld /data/deploy-it"
ls -ld /data/deploy-it
echo "ls -l /data/deploy-it"
ls -l /data/deploy-it
echo "ls -l /data/deploy-it/bin"
ls -l /data/deploy-it/bin
echo "ls -lR /data/deploy-it/scripts"
ls -lR /data/deploy-it/scripts
echo "ls -l /data/deploy-it/configdata"
ls -l /data/deploy-it/configdata
echo "ls -l /data/deploy-it/tmp"
ls -l /data/deploy-it/tmp
echo "ls -l /mnt"
ls -l /mnt
echo "ls -l /mnt/deploy-it"
ls -l /mnt/deploy-it
echo "mount"
mount
echo "df -h"
df -h
echo "du -hs /tmp/deploy-it/*"
du -hs /tmp/deploy-it/*
echo "du -hs /data/deploy-it/tmp/*"
du -hs /data/deploy-it/tmp/*

echo "einde van informatie-overzicht"

# Test 1: Check existence of required script files
echo "Start test S1 - benodigde scripts"
TestFile="${ScriptPath}/deploy_initial_settings.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg script: ${TestFile}"
  let "ErrorCount += 1";
fi
TestFile="${ScriptPath}/deploy_global_settings.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg script: ${TestFile}"
  let "ErrorCount += 1";
fi
TestFile="${ScriptPath}/deploy_global_functions.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg script: ${TestFile}"
  let "ErrorCount += 1";
fi
TestFile="${ScriptPath}/deploy_replace_tool.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg script: ${TestFile}"
  let "ErrorCount += 1";
fi
TestFile="${ScriptPath}/deploy_specific_settings.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg script: ${TestFile}"
  let "ErrorCount += 1";
fi

if [ ${ErrorCount} -gt 0 ]; then
  echo "Selftest voortijdig beeindigd wegens fouten."
  echo "Aantal gevonden fouten: ${ErrorCount}"
  echo "Bovenstaande fouten maken een verdere zelftest onmogelijk."
  exit 16
fi

# Uitvoeren required script files
source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

DebugLevel=3

LogLineINFO "Script ${ScriptName} started."

# Test 2: Check existence of extra required script files
echo "Start test S2 - andere benodigde scripts"
TestFile="${ScriptPath}/ssh/ssh_srv_toptoa.sh"
if [ ! -s "${TestFile}" ];
then
  echo "WARNING: ontbrekend of leeg script: ${TestFile}"
  let "WarningCount += 1";
fi

# Test 3: Check existence of required parameter files
echo "Start test S3 - benodigde parameterbestanden"
TestFile="${ConfigDataFolder}/DEPLOYIT.csv"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg parameterbestand: ${TestFile}"
  let "ErrorCount += 1";
fi

TestFile="${ConfigDataFolder}/bash_deployit_settings.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg parameterbestand: ${TestFile}"
  let "ErrorCount += 1";
fi

# Test 3B: Check existence of required parameter files
echo "Start test S3B - toon versie informatie script bestanden"
grep "^ScriptVersion" /data/deploy-it/scripts/*
echo "Test S3B - script bestanden zonder versie informatie:"
grep -L "^ScriptVersion" /data/deploy-it/scripts/*
echo "Einde test S3B"

# Test 4: Test java presence
echo "Start test S4 - JAVA versie"
java -version
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: java versie kan niet opgevraagd worden."
  let "ErrorCount += 1";
  echo "Selftest voortijdig beeindigd wegens fouten."
  echo "Aantal gevonden fouten: ${ErrorCount}"
  echo "Zonder java kunnen handover en replace tool niet getest worden."
  exit 16
fi

# Test 5: Test handover tool
echo "Start test S5 - handover-tool"
ActionType="selftest-slv"
ArgEnv="SLV"
MaakTmpEnvFolder
cd ${TmpEnvFolder}
Jar="${BinFolder}/handover-tool-app.jar"
Fctn="be.argenta.handover.svn.DownloadService"
Config="${ConfigDataFolder}/credentials/handover-tool_settings.conf"
java -cp $Jar -DHOT_ENV=prd $Fctn -c $Config -sc -ss -o ACC -t "8324"
RC=$?
echo "RC = $RC"
if [ $RC -ne 0 ]; then
  echo "ERROR: handover-tool werkt niet naar behoren."
  let "ErrorCount += 1";
fi
TmpFolder=${TmpEnvFolder}
CleanTmpFolder
cd "~"

# Test 6: Test presence of svn program
echo "Start test P6 - svn programma"
svn --version --quiet
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: svn versie kan niet opgevraagd worden."
  let "ErrorCount += 1";
  echo "Selftest voortijdig beeindigd wegens fouten."
  echo "Aantal gevonden fouten: ${ErrorCount}"
  echo "Zonder svn kan de repository niet benaderd worden."
  exit 16
fi

# Test 7: Test replacer tool
echo "Start test S7 - replace tool"
ActionType="selftest-slv"
ArgEnv="SLV"
MaakTmpEnvFolder
cd ${TmpEnvFolder}
cat >Plh_test.csv << EOL
testcase|ACC|@@Testcase1#@|Value1|
testcase|ACC|@@Testcase2a#@|Value2a|
testcase|ACC|@@Testcase2b#@|Value2b|
EOL
cat >Plh_test.input << EOL
Dit moet juist zijn:
Value1=@@Testcase1#@

En dit ook:
Value2a=@@Testcase2a#@
EOL
Jar="${BinFolder}/train-tools-replace.jar"
Fctn="be.argenta.train.tools.csv.CsvToProperties"
java -cp $Jar $Fctn -I Plh_test.csv -E ACC -A testcase -O Plh_test.prop
RC=$?
echo "RC van replace tool deel 1 = $RC"
if [ $RC -ne 0 ]; then
  echo "ERROR: replace tool deel 1 werkt niet."
  let "ErrorCount += 1";
fi
Fctn="be.argenta.train.tools.replace.PropertyReplace"
java -cp $Jar $Fctn -I Plh_test.input -A -S Plh_test.prop -O Plh_test.output
RC=$?
echo "RC van replace tool deel 2 = $RC"
if [ $RC -ne 0 ]; then
  echo "ERROR: replace tool deel 2 werkt niet."
  let "ErrorCount += 1";
fi
TmpFolder=${TmpEnvFolder}
CleanTmpFolder

# Test 8: Check existence of svn sourced files
echo "Start test S8 - configuratiefiles uit SVN"
TestFile="${SvnConfigDataFolder}/ADC2CNTUSRDIR.csv"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg SVN gegevensbestand: ${TestFile}"
  let "ErrorCount += 1";
fi

TestFile="${SvnConfigDataFolder}/ADCENV2SRV.csv"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg SVN gegevensbestand: ${TestFile}"
  let "ErrorCount += 1";
fi

TestFile="${SvnConfigDataFolder}/ENV2DEPLSETTINGS.csv"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg parameterbestand: ${TestFile}"
  let "ErrorCount += 1";
fi

# Test 9: Check existence of mount points
echo "Start test S9 - test mount point locaties en onderliggende structuur"
mount | grep "/mnt/deploy-it"
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ontbrekende mount point: /mnt/deploy-it is nodig om te deployen"
  let "ErrorCount += 1";
fi
mount | grep "/mnt/scriptura_templates"
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ontbrekende mount point: /mnt/scriptura_templates* is nodig om scriptura templates te deployen"
  let "ErrorCount += 1";
fi
mount | grep "/mnt/iws-deploy"
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ontbrekende mount point: /mnt/iws-deploy* is nodig om IWS te deployen"
  let "ErrorCount += 1";
fi
ls -ld /mnt/iws-deploy-*/packages
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ontbrekende packages subfolder voor /mnt/iws-deploy*. Deze is nodig om IWS te deployen"
  let "ErrorCount += 1";
fi
## Informatief de inhoud van de packages folders tonen.
## Deze zouden leeg moeten zijn.
echo "Indien onderstaande folders niet leeg zijn, is er mogelijk een probleem met de afhandeling van IWS packages aan de kant van Cegeka."
ls -l /mnt/iws-deploy-*/packages
echo "Einde IWS packages overzicht."
mount | grep "/mnt/win-apps"
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ontbrekende mount point: /mnt/win-apps* is nodig om Delphi te deployen"
  let "ErrorCount += 1";
fi


# Test 10: Test connectivity to application servers
echo "Start test S10 - test ssh connectie naar applicatie-server"
TestServer="sv-arg-jfrnt-a1"
TestUser="taccdeps"
SshOpts="-t -t -o StrictHostKeyChecking=no"
ssh $SshOpts ${TestUser}@${TestServer} "ls /"
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ssh met user ${TestUser} naar server ${TestServer} werkt niet."
  let "ErrorCount += 1";
fi

# Test 11: Check existence of credentials files
echo "Start test P11 - credentials files"
TestFile="${ConfigDataFolder}/credentials/openssl.acc.psw"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg SVN gegevensbestand: ${TestFile}"
  let "ErrorCount += 1";
fi
TestFile="${ConfigDataFolder}/credentials/handover-tool_settings.conf"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg SVN gegevensbestand: ${TestFile}"
  let "ErrorCount += 1";
fi
TestFile="${ConfigDataFolder}/credentials/svn.password.properties"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg SVN gegevensbestand: ${TestFile}"
  let "ErrorCount += 1";
fi

# Test 12: Test connectivity to Oracle DB
echo "Start test S12a - test Oracle software beschikbaarheid"
TestFile="/usr/bin/sqlplus"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg Oracle applicatie: ${TestFile}"
  let "ErrorCount += 1";
fi

echo "Start test S12b - test Oracle connectie "

TheEnv=$(whoami)
TheEnv=${TheEnv/depl/""}
TheEnv=${TheEnv/t/""}

 DB_USER="/"
  DB_PWD=""
  DB_HOST="ARG_${TheEnv^^}"
  SQLPLUS_PATH="/usr/bin/sqlplus -s ${DB_USER}@${DB_HOST}"
SQLCommand="SELECT 1 FROM APL;"

  SQLOutput=$(echo "set heading off;
${SQLCommand}" | ${SQLPLUS_PATH})

if [[ $SQLOutput != *"rows selected"* ]]; then
  echo "ERROR: SQL Connectie naar Oracle DB op ${DB_HOST} werkt niet."
  let "ErrorCount += 1";
fi

if [ ${ErrorCount} -gt 0 ]; then
  echo "Aantal gevonden fouten: ${ErrorCount}"
  echo "$ScriptName beeindigd met fouten."
  exit 16
fi
echo "$ScriptName beeindigd zonder fouten."
exit 0

