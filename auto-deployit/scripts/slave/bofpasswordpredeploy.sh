#!/bin/bash

#### bofpasswordpredeploy.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script performs the preparation activities to allow
# a bof password type ticket deployment.
# It pushes the required files to the deployIT mount point,
# then contacts all target servers to download those files
# into the container but without actication.
#
# Command line options:
#     APPL    : The ADC name being deployed
#     TICKETNR    : The ticket number being deployed
#     ENV   : The target environment
#     DOEL    : The StapDoel that determines up to
#                            what point the deploy process
#                            should go
#
#################################################################
# Change history
#################################################################
# jaden       # Mar/2018    # initial POC versie
# vevi        # Oct/2018    # Updated PoC
# lekri       # Jun/2021    # SSGT-65: openssl key hashing -> sha256
# lekri       # 12/11/2021  # ondersteuning ACC & SIM TraceIT/4me
#################################################################

ScriptName="bofpasswordpredeploy.sh"
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

## Call GetEnvData
GetEnvData
SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

ActionType="bof-psw-predeploy"
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
GetBofInfo
## Output: $TheUsr, $TheFld

## Determine the target elements for this predeploy:
## - the BOF server: $TheBOFServer
## - the root path where to deploy: $TheBOFTargetPath
TheBOFServer="bof_${TheBof}.argenta.be"
TheBOFTargetPath="/${ArgEnv}/${TheFld}"

## Doe een PING naar de BOF server
ping -c 2 "${TheBOFServer}" > /dev/null
RC=$?
if [ $RC -ne 0 ]; then
  LogLineERROR "Server ping failed for server ${TheBOFServer}"
  exit 16
fi

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

# Test 3: ensure downloaded.txt only contains lines with "password"
if [ $(grep -v password ${HandoverDownloadedList} | wc -l) -ne 0 ];
then
  echo "ERROR: Ticket contains download files outside the password folder. This is not supported here."
  exit 16
fi

## Extract the *secondpart* variable from the first line of the downloaded or deleted file
# Under password there should be only 1 subfolder, which is typical for this ADC. Extract it.
line1=$(cat ${HandoverDownloadedList} ${HandoverDeletedList} | head -n 1)
echo "line1 = " ${line1}
## expected format: OK      password/<adc-folder>/...
## remove the "OK" + tab section
line1=${line1:3}
## echo "line1 (stripped) = " ${line1}
firstpart=${line1%%"/"*}
restpart=${line1:${#firstpart}+1}
secondpart=${restpart%%"/"*}
## echo "first folder part is:" ${firstpart}
## echo "second folder part is:" ${secondpart}
if [[ ${firstpart} -eq "password" ]] && [[ ${secondpart} -eq ${ArgAppl,,} ]]; then
  echo "Line 1 is in the expected format!"
else
  echo "ERROR: downloaded.txt or deleted.txt has a first line that is outside the expected location!"
  echo ">>${firstpart}<< should be >>password<<"
  echo ">>${secondpart}<< should be >>${ArgAppl,,}<<"
  exit 16
fi

## Currently, we only support to deploy the password files that were generated by our own tools
ToInstallSubfolder="${TmpTicketFolder}/password/${secondpart}/generated/${ArgEnv}"
TmpSrcFld="${TmpTicketFolder}/ReplacedPub"
TmpRetarFld=${TmpTicketFolder}/retar
mkdir -p ${TmpRetarFld}
Tarfilename="TI${ArgTicketNr}-${TheADC}-psw.tar"
# Tar the environment specific config files without compression.
cd ${ToInstallSubfolder}
TarFile ./ ${TmpRetarFld} ${Tarfilename}
# Now we have to put the tar on the bof-server.
## We're doing this through making a tar-package and sending it to the target
TargetFolder="/home/${UnixUserOnApplSrv}/autodeploy/tmp/TI${ArgTicketNr}/psw/"

# prepare scripts to create tmpfolder on target server(s)
TmpCmdFile="${TmpTicketFolder}/preptargetfolder.sh"
rm -f $TmpCmdFile
cat >${TmpCmdFile} << EOL
#!/bin/ksh
mkdir -p ${TargetFolder}
RC=\$?
if [ \$RC -ne 0 ]; then
  echo "Could not create the ticket specific folder."
  echo "Attempted folder name is: >>>${TargetFolder}<<<"
  exit 16
fi
EOL
chmod +x ${TmpCmdFile}

TmpCmd2File="${TmpTicketFolder}/untarPsw.sh"
rm -f ${TmpCmd2File}
cat >${TmpCmd2File} <<EOL
#!/usr/local/bin/bash
TargetFld=${TargetFolder}
TheADC=${TheADC}
TheEnv=${TheEnv}
TheFld=${TheFld}
TmpExtractFld="\${TargetFld}extract-psw"
Tarfilename=${Tarfilename}
Tarfile="\${TargetFld}\${Tarfilename}"
case \$(uname) in
  HP-UX*)
    # This is required to use the gtar-version.
    GTarBinary="/usr/local/bin/gtar"
  SetACLBin=\$(which setacl)
  GetACLBin=\$(which getacl)
    ;;
  Linux*)
    GTarBinary=\$(which tar)
  SetACLBin=\$(which setfacl)
  GetACLBin=\$(which getfacl)
  
    ;;
  *)
    GTarBinary=\$(which tar)
  SetACLBin=\$(which setfacl)
  GetACLBin=\$(which getfacl)
    ;;
esac
# Prereqs-check
if [[ ! -e \${Tarfile} || ! -r \${Tarfile} ]]; then
  echo "Tarfile \"\${Tarfile} doesn't exist or is not readable, exiting now."
  exit 16
fi

TmpExtractFld="\${TargetFld}extract-psw"
mkdir -p \${TmpExtractFld}
if [[ \$? -ne 0 ]]; then
  echo "Failed creating extract folder \"\${TmpExtractFld}\"."
  exit 16
fi
# Perform untar.
\${GTarBinary} -C "\${TmpExtractFld}" -xf "\${Tarfile}"
if [[ \$? -ne 0 ]]; then
  echo "Failed extracting tar \"\${Tarfile}\" to \"\${TmpExtractFld}\"."
  exit 16
else
  echo "Succesfully extracted tarfile \"\${Tarfile}\" to folder \"\${TmpExtractFld}\"."
fi
EOL
chmod +x ${TmpCmd2File}

TmpCmd3File="${TmpTicketFolder}/installPsw.sh"
rm -f ${TmpCmd3File}
cat >${TmpCmd3File} <<EOL
#!/usr/local/bin/bash
TargetFolder=${TargetFolder}
TheADC=${TheADC}
TheFld=${TheFld}
TheEnv=${TheEnv}
SrcFolder="\${TargetFolder}/extract-psw"
chmod -R g+rx  "/home/\${UnixUserOnApplSrv}"

DestFolder="/\${TheEnv}/\${TheFld}"
if [[ !  -d \${DestFolder} ]]; then
    echo "Destination folder  \"\${DestFolder}\" does not exist!."
fi

case \$(uname) in
  HP-UX*)
    typeset SetACLBin=\$(which setacl)
  typeset GetACLBin=\$(which getacl)
  ;;
  Linux*)
    local SetACLBin=\$(which setacl)
  local GetACLBin=\$(which getacl)
  ;;
esac


for filename in \$(find \${SrcFolder} -name '*.enc') ; do
  strpfn=\${filename#"\$SrcFolder/"}
  echo "Processing \${strpfn}"
 

    fl=\$( expr  \${#strpfn} - 4 )
    finalName=\${strpfn:0:\$fl}
    echo "Decrypting file \$strpfn ..."
    openssl enc -d -in \${SrcFolder}/\${strpfn} -out \${SrcFolder}/tempfile -aes256 -md sha256 -pass file:\${TargetFolder}MasterPSW_openssl
    RC=\$?
    if [ \$RC -ne 0 ]; then
      echo "Could not decrypt the password file \${strpfn}."
      exit 16
    fi
    finalPath=\${DestFolder}/\${finalName}
    echo "final path for pswd file is \"\${finalPath}\"" 
    chmod -R g+rx  "/home/\${UnixUserOnApplSrv}"
    sudo /bin/su - toptoa -c " \$SetACLBin -m u::rwx,g::rx,o:0 \${finalPath} >> \${TargetFolder}/toptoa_ssh.log
    sudo /bin/su - toptoa -c "cp -pr \${SrcFolder}/tempfile \${finalPath}"
    if [[ \$? -eq 0 ]]; then
      echo "succesfully installed the password-file to \"\${finalPath}\"."
    else
      echo "Failed installing the password-file into \"\${finalPath}\"."
    fi
    sudo /bin/su - toptoa -c " \$SetACLBin -m u::rx,g::rx,o:0 \${finalPath} >> \${TargetFolder}/toptoa_ssh.log
    rm -rf \${SrcFolder}/tempfile
done



EOL
chmod +x ${TmpCmd3File}

TmpCmd4File="${TmpTicketFolder}/cleanTemp.sh"
rm -f ${TmpCmd4File}
cat > ${TmpCmd4File} <<EOL
#!/usr/local/bin/bash
cd
TmpFolder="/tmp/TI${ArgTicketNr}"
TmpDeployFolder="${TargetFolder}"
if [[ -d \${TmpFolder} ]]; then
  rm -rf \${TmpFolder}
  if [[ \$? -eq 0 ]]; then
    echo "Succesfuly removed tmpdir \"\${TmpFolder}\"."
  else
    echo "Failed removing tmpdir \"\${TmpFolder}\"."
  fi
fi
if [[ -d \${TmpDeployFolder} ]]; then
  rm -rf \${TmpDeployFolder}
  if [[ \$? -eq 0 ]]; then
    echo "Succesfuly removed tmpdir \"\${TmpDeployFolder}\"."
  else
    echo "Failed removing tmpdir \"\${TmpDeployFolder}\"."
  fi
fi
# Remove the remaining files (like prepareTargetFolder)
rm -rf /tmp/TI${ArgTicketNr}*
if [[ \$? -eq 0 ]]; then
  echo "Succesfuly removed the remaining files for TI${ArgTicketNr}."
else
   echo "Failed removing the remaining files under /tmp for TI${ArgTicketNr}."
fi
EOL
chmod +x ${TmpCmd4File}

$ScpPutCommand $TheBOFServer $TmpCmdFile "/tmp/T${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "preparetargetfolder.sh" $TheBOFServer
fi
# execute the preparetargetfolder.sh script
$SshCommand $TheBOFServer "ksh /tmp/T${ArgTicketNr}_preparetargetfolder.sh"
RC=$?
if [ $RC -ne 0 ]; then
   deploy_error $DPLERR_SshExecFailed "preparetargetfolder.sh" $TheBOFServer $RC
fi

## Send remaining scripts to targetfolder.
$ScpPutCommand $TheBOFServer $TmpCmd2File "${TargetFolder}/untarPsw.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "untarPsw.sh" $TheBOFServer
fi
$ScpPutCommand $TheBOFServer ${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw ${TargetFolder}/MasterPSW_openssl
RC=$?
if [ $RC -ne 0 ]; then
   deploy_error $DPLERR_ScpPutFailed "MasterPSW_openssl" $TheBOFServer
fi
$ScpPutCommand $TheBOFServer $TmpCmd3File "${TargetFolder}/installPsw.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "installPsw.sh" $TheBOFServer
fi
$ScpPutCommand $TheBOFServer $TmpCmd4File "${TargetFolder}/cleanTemp.sh"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "cleanTemp.sh" $TheBOFServer
fi

$ScpPutCommand $TheBOFServer "${TmpRetarFld}/${Tarfilename}" "${TargetFolder}/${Tarfilename}"
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ScpPutFailed "${TarFilename}" $TheBOFServer
fi

### Clean up tmp files
TmpFolder=${TmpTicketFolder}
CleanTmpFolder

echo "Script" ${ScriptName}  "ended."

