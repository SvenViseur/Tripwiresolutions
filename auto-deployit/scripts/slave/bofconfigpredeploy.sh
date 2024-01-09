#!/bin/bash

#### bofconfigpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the preparation activities to allow
# a bof config type ticket deployment.
# See the bofpredeploy for a 
#
# It will also create 4 in-here script which are sent to the bof-server..
# 1. prepareTarget Folder:	prepares the target folder on the bof-server.
# 2. untar:			Untars the configs to a temp-folder
# 3. Install binaries:		saves the current permissions, clear lib-folder
#                           	set the saved permissions to the extract-folder.
#                           	then installs the config-files to the dest-folder.
# 4. Clean temp:		Removes the previously created tempfolder.
#                           	If you got here, it means the deploy went ok.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#     DOEL		: The StapDoel that determines up to
#                            what point the deploy process
#                            should go
#
#################################################################
# Change history
#################################################################
# jaden     # 13/08/2018  # 1.0-0 Initial Commit
# lekri     # 12/11/2021  # ondersteuning ACC & SIM TraceIT/4me
#           #             #
#################################################################
#
ScriptName="bofconfigpredeploy.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"

DebugLevel=3
ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3
ArgDoel=$4
ArgExtraOpts=$5

echo "Script" ${ScriptName}  "started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"
echo "  DOEL = '${ArgDoel}'"
echo "  EXTRA OPTIONS = '${ArgExtraOpts}'"

## Call GetEnvData
GetEnvData

SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="bof-config-predeploy"
MaakTmpTicketFolder
cd ${TmpTicketFolder}

TmpFld=$TmpTicketFolder
TheEnv=$ArgEnv
TheADC=$ArgAppl

## Get default settings based on the ENV and ADC
GetDeployITSettings

## ExtraOpts is hier nodig, omdat GetDynOplOmg via TraceIT gebeurt
Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

## GetDynOplOmg:
## In: ArgTicketNr, TmpFld    Out: TheOpl
GetDynOplOmg

DebugLevel=$DeployIT_Debug_Level
Replace_Tool_Defaults
EchoDeployITSettings
LoggingBaseFolder="${ConfigNfsFolderRepllogOnServer}/target_${ArgEnv}/"
mkdir -p $LoggingBaseFolder

StapDoelBepalen $ArgDoel

## Opnieuw ExtraOpts parsen, want die kunnen StapDoel wijzigen!
Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

if [ $DeployIT_Stap_Doel -lt $DEPLOYIT_STAP_PREDEPLOY ]; then
  echo "WARN: Predeploy fase naar target servers niet uitgevoerd wegens huidig doel"
  exit 0
fi

if [ ${DeployIT_Can_Ssh_To_Appl_Servers} -ne 1 ]; then
  echo "WARN: Deploy to target servers is skipped due to Deploy-IT settings"
  exit 0
fi

## Get info on container
GetEnvData

GetBofInfo
## Output:, $TheUsr, $TheFld

## Determine the target elements for this predeploy:
## - the BOF server: $TheBOFServer
## - the root path where to deploy: $TheBOFTargetPath
TheBOFServer="bof_${TheBof}.argenta.be"
TheBOFTargetPath="/${ArgEnv^^}/${TheFld}"

## Doe een PING naar de BOF server
ping -c 2 "${TheBOFServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  LogLineERROR "Server ping failed for server ${TheBOFServer}"
  exit 16
fi

cd ${TmpTicketFolder}
## Call Handover tool to download ticket material
Handover_Download_Local

# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

OnlyDeletes=0 ## Default value

# Check the contents of the deleted and downloaded files
# Test 1: ensure deleted.txt AND downloaded.txt are NOT BOTH empty
if [ ! -s ${HandoverDownloadedList} ]; then
  if [ ! -s ${HandoverDeletedList} ]; then
    echo "ERROR: Ticket bevat geen data files (geen nieuwe, gewijzigde of verwijderde files). DeployIT kan dus niets doen."
  fi
  ## Als we dit punt bereiken, dan is er GEEN downloaded file maar wel deleted files.
  ## Dus heeft het geen zin om de downloaded file te parsen.
  OnlyDeletes=1
fi

# Test 3: ensure downloaded.txt only contains lines with "config"
if [ $(grep -v config ${HandoverDownloadedList} | wc -l) -ne 0 ];
then
  echo "ERROR: Ticket contains download files outside the config folder. This is not supported here."
  exit 16
fi

## Extract the *secondpart* variable from the first line of the downloaded or deleted file
# Under config there should be only 1 subfolder, which is typical for this ADC. Extract it.
line1=$(cat ${HandoverDownloadedList} ${HandoverDeletedList} | head -n 1)
echo "line1 = " ${line1}
## expected format: OK      config/<adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
## echo "line1 (stripped) = " ${line1}
firstpart=${line1%%"/"*}
restpart=${line1:${#firstpart}+1}
secondpart=${restpart%%"/"*}
## echo "first folder part is:" ${firstpart}
## echo "second folder part is:" ${secondpart}
if [[ ${firstpart} -eq "config" ]] && [[ ${secondpart} -eq ${ArgAppl,,} ]]; then
  echo "Line 1 is in the expected format!"
else
  echo "ERROR: downloaded.txt or deleted.txt has a first line that is outside the expected location!"
  echo ">>${firstpart}<< should be >>config<<"
  echo ">>${secondpart}<< should be >>${ArgAppl,,}<<"
  exit 16
fi

ToInstallSubfolder="${TmpTicketFolder}/config/${secondpart}/generated/${ArgEnv}"
# Tar the config files.
TmpSrcFld="${TmpTicketFolder}/ReplacedPub"
TmpRetarFld=${TmpTicketFolder}/retar
mkdir -p ${TmpRetarFld}
# TarFile <SrcDir> <DstDir> <DstFile>
Tarfilename="TI${ArgTicketNr}-${TheADC}-config.tar"

TarFile ${TmpSrcFld} ${TmpRetarFld} ${Tarfilename}

TargetFolder="/home/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}/config/"
ToInstallFld="/${TheEnv^^}/${TheFld}/ini/${TheADC}"

# prepare script to send to target server(s)
TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm $TmpCmdFile
cat >${TmpCmdFile} << EOL
#!/bin/bash
mkdir -p ${TargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific folder."
  echo "Attempted folder name is: >>>${TargetFolder}<<<"
  exit 16
fi
EOL
chmod +x ${TmpCmdFile}

TmpCmd3File="${TmpTicketFolder}/installConfig.sh"
rm -f ${TmpCmd3File}
cat >${TmpCmd3File} <<EOL
#!/bin/bash
ACLFolder="${ToInstallSubfolder}/ACL"
AclFile="${ACLFolder}/acl.txt"
TargetFolder=${TargetFolder}
TheADC=${TheADC}
TheFld=${TheFld}
TheEnv=${TheEnv}
SrcFolder="\${TargetFolder}/extract-config"
DestFolder="/\${TheEnv}/\${TheFld}/ini/\${TheADC}"
# Create seperate folder for acl-files.
ACLFolder=\${TargetFolder}/acl_files"
mkdir -p "\${ACLFolder}"
TmpACLFile="\${ACLFolder}/\${file}.acl"

case \$(uname -o) in
  HP-UX*)
    typeset SetACLBin=\$(which setacl)
    typeset GetACLBin=\$(which getacl)
    ;;
  Linux*)
    local SetACLBin=\$(which setacl)
    local GetACLBin=\$(which getacl)
    ;;
esac

echo "Start Setting permissions of config-files."
#Take the current permissions
mkdir -p \${ACLFolder}
if [ \${?} -eq 0 ]; then
  echo "Succesfuly created ACL-folder \"\${ACLFolder}\"."
else
  echo "Failed creating ACL-folder \"\${ACLFolder}\"."
  exit 16
fi

cd \${DestFolder}
for file in \$(ls \${DestFolder}); do
  echo "Start saving current permissions of \"\${file}\" to the \"\${TmpAclFile}\"."
  \${GetACLBin} \${file} > \${TmpACLFile}
  if [ \$? -eq 0 ]; then
    echo "Succesfuly got permissions of \"\${file}\" and saved it to  \"\${TmpAclFile}\"."
  else
    echo "Failed getting permissions of \"\${file}\" and save it to  \"\${TmpAclFile}\"."
    exit 16
  fi
done


for file in \$( ls \$(SrcFolder}); do
  echo "Start setting current permissions of \"\${file}\"."
  if [[ -e \${TmpACLFile} ]]; then
    echo "\${SetACLBin} -f \${TmpACLFile} \${file}"
    \${SetACLBin} -f \${TmpACLFile} \${file}
    if [ \$? -eq 0 ]; then
      echo "Succesfuly setted permissions for \"\${file}\"."
    else
      echo "Failed getting permissions of \"\${file}\"."
   	  exit 16
    fi
  else
    # Taking parent folder's permissions.
    echo "\${SetACLBin} -f \${ACLFolder}/parent_acl.txt \${file}"
    \${SetACLBin} -f \${ACLFolder}/parent_acl.txt \${file}
    if [ \$? -eq 0 ]; then
      echo "Succesfuly setted permissions for \"\${file}\" with the same permissions as the parent folder."
    else
      echo "Failed setting permissions of \"\${file}\" with the same permissions as the parent folder."
   	  exit 16
    fi
    ## Removing the write bit for others.
    chmod o-w \${file}
    if [ \$? -eq 0 ]; then
      echo "Succesfuly removed the write-bit for others for file \"\${file}\"."
    else
      echo "Failed removing the write-bit for others for file \"\${file}\"."
      exit 16
    fi
done
echo "Finished Setting permissions of config-files."

cp -pr \${SrcFolder}/* \${DestFolder}/
if [ \$? -eq 0 ]; then
  echo "succesfully installed the config-files to \"\${DestFolder}\"."
else
  echo "Failed installing the config-files into \"\${DestFolder}\"."
fi
EOL
chmod +x ${TmpCmd2File}

TmpCmd3File="${TmpTicketFolder}/cleanTemp.sh"
rm ${TmpCmd3File}
cat > ${TmpCmd3File} <<EOL
#/bin/bash
TmpDeployFolder="${TargetFolder}
if [[ -e \${TmpDeployFolder} ]]; then
  rm -rf \${TmpDeployFolder}
  if [ \$? -eq 0 ]; then
    echo "Succesfuly removed tmpdir \"\${TmpDeployFolder}\"."
  else
    echo "Failed removing tmpdir \"\${TmpDeployFolder}\"."
  fi
fi
EOL
chmod +x ${TmpCmd3File}

# Send defined scripts.
$ScpPutCommand $TheBOFServer $TmpCmdFile "/tmp/T${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $TheBOFServer
fi
# execute the preparetargetfolder.sh script
$SshCommand $TheBOFServer "source /tmp/T${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $TheBOFServer $RC
fi

## Send remaining scripts to TargetFolder
$ScpPutCommand $TheBOFServer $TmpCmd3File "${TargetFolder}/installConfig.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "installConfig.sh" $TheBOFServer
fi
$ScpPutCommand $TargetServer $TmpCmd4File "${TargetFolder}/CleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "CleanTemp.sh" $TheBOFServer
fi

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."
