#!/bin/bash

#### deploy_selftest_targets.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs a selftest of all application servers
# that belong to an environment and that should be reacheable for
# DeployIT reasons
# It is only meant to be run on Jenkins slaves that have
# deployer/slave functionality: They can reach all application
# servers. Key tests in this selftest are:
# on deployer/slave server:
#    presence of deployit scripts and csv files
#    presence of java, svn, replace tools
#    presence of okfs mount point
# on target application servers:
#    ping test
#    ssh test
#    find moint point of okfs
#    check sudo rights
#
# Command line options:
#          $1      Omgeving waarvoor de servers getest moeten worden
# Output:
#          NONE
#          RC  = 0 if all is OK
#          RC  = 16 if at least one problem was encountered
#
#################################################################
# Change history
#################################################################
# dexa # sep/2016    # initial version
# dexa # 07/10/2016  # call MaakTmpTicketFolder en CleanTmpFolder
# dexa # 31/10/2016  # DepsUser dynamisch via GetEnvData
# dexa # 18/10/2017  # Toev scriptura mount points test
# dexa # 21/03/2019  # add groups info, correct count on ssh etc
# dexa # 21/03/2019  #  1.0.0  # add version info
# dexa # 26/02/2020  #  1.1.0  # added T8B: check ivl vault file
# dexa # 26/04/2020  #  1.2.0  # added T22: firest odi tests
# dexa # 26/02/2020  #  1.2.1  # exclude "DoNotAutoDeploy"
# dexa # 26/04/2020  #  1.3.0  # upd T22: multiple odi ADCs
# dexa # 18/05/2020  #  1.3.1  # add T23: initial batch srv test
# dexa # 03/08/2020  #  1.3.2  # remove dep on ivl_functions
#      #             #         #
#################################################################
#

ScriptName="deploy_selftest_targets.sh"
ScriptVersion="1.3.2"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ArgEnv=$1
echo "gekozen omgeving: $ArgEnv"
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
echo "einde van informatie-overzicht"

# Test 1: Check existence of required script files
echo "Start test T1 - benodigde scripts"
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
echo "Start test T2 - andere benodigde scripts"
TestFile="${ConfigDataFolder}/bash_deployit_settings.sh"
if [ ! -s "${TestFile}" ];
then
  echo "WARNING: ontbrekend of leeg script: ${TestFile}"
  let "WarningCount += 1";
fi

# Test 3: Check existence of required parameter files
echo "Start test T3 - benodigde parameterbestanden"
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

# Test 4: Test java presence
echo "Start test T4 - JAVA versie"
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

# Test 7: Test replacer tool
echo "Start test T7 - replace tool"
ActionType="selftest-targets"
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
echo "Start test T8 - configuratiefiles uit SVN"
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

# Test 8B: Check existence of svn sourced vault files
# Please note that the vault file for IVL is needed for actions on
# the IVL target server
echo "Start test T8B - vault files uit SVN"
TestFile="${SvnConfigDataFolder}/ivl_${ArgEnv,,}.psafe3"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg SVN vaultbestand: ${TestFile}"
  let "ErrorCount += 1";
fi

# Test 9: Check existence of okfs mount point
echo "Start test T9 - test /mnt/deploy-it locatie"
mount | grep "/mnt/deploy-it"
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ontbrekende mount point: /mnt/deploy-it is nodig om te deployen"
  let "ErrorCount += 1";
fi

# Test 11: Test connectivity to JBOSS application servers
echo "Start test T11 - test ssh connectie naar JBOSS applicatieservers"
FilterEnv=$ArgEnv

ActionType="selftest-targets"
MaakTmpEnvFolder
cd ${TmpEnvFolder}
grep _WAR\|${FilterEnv}\| ${SvnConfigDataFolder}/ADCENV2SRV.csv | cut -d '|' -f 3 | sort -u > serverlist.txt

SrvCount=0
linecount=0
IFS=" "
while read srv rest
do
  if [ "$srv" = "" ]; then
    echo "invalid file in function GetSrvList for file ${Filename} with missing srv data on line ${linecount}."
    exit 16
  fi
  if [[ "${srv}" == "DoNotAutoDeploy"* ]] || [[ "${srv}" == "jbaas"* ]]; then
    echo "skip $srv"
  else
    ((SrvCount++))
    SrvList[$SrvCount]="$srv"
    linecount=$((linecount + 1))
  fi
done < serverlist.txt

echo "Aantal te testen servers: $SrvCount"

## Doe ping test naar al die servers
SrvPingOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ping -c 2 "${SrvList[$i]}${DnsSuffix}" > /dev/null
    RC=$?
    if [ $RC -eq 0 ]; then
      ((SrvPingOKCount++))
    else
      echo "WARN: Server ping failed for server ${SrvList[$i]}"
      let "ErrorCount += 1";
    fi
  done
if [ $SrvPingOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers are reachable."
fi

## Bepaal parameters om naar slaves te gaan.
# input: $ArgEnv
GetEnvData

## Doe connectietest naar de deps user
TheDepsUser=$UnixUserOnApplSrv
SshOpts="-t -t -o StrictHostKeyChecking=no"
SrvSshOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ssh $SshOpts ${TheDepsUser}@${SrvList[$i]}${DnsSuffix} "ls /"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "ERROR: ssh met user ${TheDepsUser} naar server ${SrvList[$i]} werkt niet."
      let "ErrorCount += 1";
    else
      ((SrvSshOKCount++))
    fi
  done
if [ $SrvSshOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers can be contacted via SSH."
fi

## Controleer mount point /mnt/deploy-it op elke server
SshOpts="-t -t -o StrictHostKeyChecking=no"
SrvMntOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ssh $SshOpts ${TheDepsUser}@${SrvList[$i]}${DnsSuffix} "mount" | grep "deploy-it"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "ERROR: geen deploy-it mount point op server ${SrvList[$i]}."
      let "ErrorCount += 1";
    else
      ((SrvMntOKCount++))
    fi
  done
if [ $SrvMntOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers have the required deploy-it mount point."
fi

SrvSudoOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ssh $SshOpts ${TheDepsUser}@${SrvList[$i]}${DnsSuffix} "sudo -l" | grep "/bin/su"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "ERROR: geen sudo rechten op server ${SrvList[$i]}."
      let "ErrorCount += 1";
    else
      ((SrvSudoOKCount++))
    fi
  done
if [ $SrvSudoOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers have sudo rights."
fi

## show information on group memberships
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    echo "groups of ${TheDepsUser} on server ${SrvList[$i]}:"
    ssh $SshOpts ${TheDepsUser}@${SrvList[$i]}${DnsSuffix} "groups ${TheDepsUser}"
  done

echo "Preparation for further tests requires call to GetDeployITSettings."
TheEnv="$ArgEnv"
TmpFld="${TmpEnvFolder}"
TheADC="***"
GetDeployITSettings
EchoDeployITSettings

# Test 21: Check existence of scriptura mount points
echo "Start test T21 - test Scriptura mount points locatie"
TargetFolderBase=${DEPLOYIT_SCRIPTURA_TARGET_BASE}
TargetFolderNodes=${DEPLOYIT_SCRIPTURA_TARGET_NODES}
if [ "$TargetFolderBase" = "" ]; then
  echo "ERROR: configuratie instelling voor deze omgeving ontbreekt voor SCRIPTURA_TARGET_BASE"
  let "ErrorCount += 1";
fi
if [ "$TargetFolderNodes" = "" ]; then
  echo "ERROR: configuratie instelling voor deze omgeving ontbreekt voor SCRIPTURA_TARGET_NODES"
  let "ErrorCount += 1";
fi
echo "Scriptura base is currently: $TargetFolderBase"
echo "          and nodes are: $TargetFolderNodes"
echo "First test: find base as mount point."
mount | grep "${TargetFolderBase}"
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR: ontbrekende scriptura base mount point: ${TargetFolderBase}"
  let "ErrorCount += 1";
fi

oIFS="$IFS"
IFS=","
read -r -a nodelist <<< "$TargetFolderNodes"
echo "Size of nodelist: ${#nodelist[@]}"
IFS="$oIFS"
for node in "${nodelist[@]}"
do
  ## copy the complete $ToInstallSubfolder to the TargetFolder
  TargetFolder="${TargetFolderBase}${node}/"
  echo "testing if folder ${TargetFolder} exists:"
  ls -ld ${TargetFolder}
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "ERROR: ontbrekende scriptura mount point: ${TargetFolder}"
    let "ErrorCount += 1";
  fi
done

# Test 22: ODI server checks
echo "Start test T22 - test ODI server"
MissingFiles=0
TestFile="${ScriptPath}/ivlremcfgodi.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg scriptbestand: ${TestFile}"
  MissingFiles=1
fi
TestFile="${ScriptPath}/ivlremcfgoracle.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg scriptbestand: ${TestFile}"
  MissingFiles=1
fi
TestFile="${ScriptPath}/ivlremselftest.sh"
if [ ! -s "${TestFile}" ];
then
  echo "ERROR: ontbrekend of leeg scriptbestand: ${TestFile}"
  MissingFiles=1
fi
if [ $MissingFiles -eq 1 ]; then
  echo "Een of meerdere ontbrekende of lege bestanden: ODI test kan niet afgewerkt worden"
  let "ErrorCount += 1";
else
  ## do grep to find _EDW applications on the current env
  TestFile="${SvnConfigDataFolder}/ADCENV2SRV.csv"
  if [ ! -s "${TestFile}" ];
  then
    echo "ERROR: ${TestFile} is nodig om te bepalen waar ODI deploys gebeuren."
  else
    ## use hard-coded list of ODI ADCs
    ## in the future this may be replaced by a lookup in de ADCENV csv file
    ODIADCListCount=2
    ODIADCList[1]="CIVL_EDW"
    ODIADCList[2]="IVL_EDW"
    for (( i=1 ; i<=$(( $ODIADCListCount )); i++))
      do
        TheADC=${ODIADCList[$i]}
        GetIvlInfo
        echo "OdiTgtServer       = '${OdiTgtServer}'"
        echo "OdiTgtLoggingFolder= '${OdiTgtLoggingFolder}'"
        ## ping the ODI server
        ping -c 2 "${OdiTgtServer}" > /dev/null
        RC=$?
        if [ $RC -ne 0 ]; then
          echo "Server ping failed for server ${OdiTgtServer}"
        else
          ## ping OK, continue testing
          echo "Ping to server $OdiTgtServer was OK."
          ## Do the replace for the remcfg files
          cd $TmpEnvFolder
          mkdir "psw"
          mkdir "psw/in"
          mkdir "psw/out"
          cp "$ScriptPath/ivlremcfgoracle.sh" "psw/in/"
          cp "$ScriptPath/ivlremcfgodi.sh" "psw/in/"
          cp "$ScriptPath/ivlremgroovy-ivl-generic.conf" "psw/in/"
          Ivl_replace "${TmpEnvFolder}/psw/in" "${TmpEnvFolder}/psw/out"
          ## prepare the files to send
          SshCommand="SSH_to_appl_srv"
          ScpPutCommand="SCP_to_appl_srv"
          SSHTargetUser=$UnixUserOnApplSrv
          TargetFolder="/tmp/DeployIT_diagnostics_test"
          TheFld=$TargetFolder

          TmpCmdFile="${TmpEnvFolder}/ivltest.sh"
          rm -f $TmpCmdFile
          cat > ${TmpCmdFile} << EOL
#!/bin/bash
TheEnv=${TheEnv}
TheFld=${TheFld}
TheADC=${TheADC}
LoggingFolder=${OdiTgtLoggingFolder}
BaseFolder=${TargetFolder}

source \${BaseFolder}/ivlremselftest.sh

DoSelftest \${TheEnv} \${TheFld} \${TheADC}

EOL
          chmod +x ${TmpCmdFile}
          $SshCommand $OdiTgtServer "mkdir -p ${TargetFolder}"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Could not make a tmp folder for selftests."
          fi
          $ScpPutCommand ${OdiTgtServer} ${TmpCmdFile} "${TargetFolder}/ivltest.sh"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Could not create tmp file for self test on ODI server (ivltest.sh)!"
          fi
          $ScpPutCommand ${OdiTgtServer} "${TmpEnvFolder}/psw/out/ivlremcfgoracle.sh" "${TargetFolder}/ivlremcfgoracle.sh"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Could not send ivlremcfgoracle.sh to ODI server."
          fi
          $ScpPutCommand ${OdiTgtServer} "${TmpEnvFolder}/psw/out/ivlremcfgodi.sh" "${TargetFolder}/ivlremcfgodi.sh"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Could not send ivlremcfgodi.sh to ODI server."
          fi
          $ScpPutCommand ${OdiTgtServer} "${TmpEnvFolder}/psw/out/ivlremgroovy-ivl-generic.conf" "${TargetFolder}/groovy-ivl-generic.conf"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Could not send groovy-ivl-generic.conf to ODI server."
          fi
          $ScpPutCommand ${OdiTgtServer} "${ScriptPath}/ivl_groovy" "${TargetFolder}/groovy"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Could not send groovy scripts to ODI server."
          fi
          $ScpPutCommand ${OdiTgtServer} "${ScriptPath}/ivlremselftest.sh" "${TargetFolder}/ivlremselftest.sh"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Could not create tmp file for self test on ODI server (ivlremselftest.sh)!"
          fi
          # execute the test script
          $SshCommand $OdiTgtServer "/bin/bash --login ${TargetFolder}/ivltest.sh"
          RC=$?
          if [ $RC -ne 0 ]; then
            echo "Errors occured during execution of diagnostics tests on ODI server $OdiTgtServer for ADC $TheADC."
            let "ErrorCount += 1";
          fi
          $SshCommand $OdiTgtServer "rm -rf ${TargetFolder}"
          ## no testing of return code here
        fi
      done
    ## All ODI servers zijn getest
  fi
fi

# Test 23: Test connectivity to _BATCH application servers
echo "Start test T11 - test ssh connectie naar BATCH applicatieserver(s)"
FilterEnv=$ArgEnv

cd ${TmpEnvFolder}
rm -f serverlist.txt
grep _BATCH\|${FilterEnv}\| ${SvnConfigDataFolder}/ADCENV2SRV.csv | cut -d '|' -f 3 | sort -u > serverlist.txt

SrvCount=0
linecount=0
IFS=" "
while read srv rest
do
  if [ "$srv" = "" ]; then
    echo "invalid file in function GetSrvList for file ${Filename} with missing srv data on line ${linecount}."
    exit 16
  fi
  if [[ "${srv}" == "DoNotAutoDeploy"* ]]; then
    echo "skip $srv"
  else
    ((SrvCount++))
    SrvList[$SrvCount]="$srv"
    linecount=$((linecount + 1))
  fi
done < serverlist.txt

echo "Aantal te testen servers: $SrvCount"

## Doe ping test naar al die servers
SrvPingOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ping -c 2 "${SrvList[$i]}${DnsSuffix}" > /dev/null
    RC=$?
    if [ $RC -eq 0 ]; then
      ((SrvPingOKCount++))
    else
      echo "WARN: Server ping failed for server ${SrvList[$i]}"
      let "ErrorCount += 1";
    fi
  done
if [ $SrvPingOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers are reachable."
fi

## Doe connectietest naar de deps user
TheDepsUser=$UnixUserOnApplSrv
SshOpts="-t -t -o StrictHostKeyChecking=no"
SrvSshOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ssh $SshOpts ${TheDepsUser}@${SrvList[$i]}${DnsSuffix} "ls /"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "ERROR: ssh met user ${TheDepsUser} naar server ${SrvList[$i]} werkt niet."
      let "ErrorCount += 1";
    else
      ((SrvSshOKCount++))
    fi
  done
if [ $SrvSshOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers can be contacted via SSH."
fi

SrvSudoOKCount=0
for (( i=1 ; i<=$(( $SrvCount )); i++))
  do
    ssh $SshOpts ${TheDepsUser}@${SrvList[$i]}${DnsSuffix} "sudo -l" | grep "/bin/su"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "ERROR: geen sudo rechten op server ${SrvList[$i]}."
      let "ErrorCount += 1";
    else
      ((SrvSudoOKCount++))
    fi
  done
if [ $SrvSudoOKCount -lt $SrvCount ]; then
  echo "ERROR: not all target servers have sudo rights."
fi


TmpFolder=${TmpEnvFolder}
CleanTmpFolder

if [ ${ErrorCount} -gt 0 ]; then
  echo "Aantal gevonden fouten: ${ErrorCount}"
  echo "$ScriptName beeindigd met fouten."
  exit 16
fi
echo "$ScriptName beeindigd zonder fouten."
exit 0

