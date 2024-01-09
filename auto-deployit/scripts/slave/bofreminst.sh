#
#### bofreminst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# IMPORTANT! The code in this script will only run on TARGET servers,
# not on DeployIT servers (depm/depp/deps). Hence, you CANNOT use
# the DeployIT libraries like global_functions, error or warning log
# functions etc.
#
# This script must be SOURCE'd by the calling script to be able to
# call the functions in this script.
# It must therefore also be transferred to the target system during the
# the deploy process.
#
# All parameters from the calling system (ticket nr, ...) should be
# passed as parameters to functions that are published here. No global
# variables should be used here.
#
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Feb/2019      # 1.0.0   # initial version
# dexa  # Feb/2019      # 1.1.0   # make functions for ToptoaCopy
# dexa  # Mar/2019      # 1.2.0   # improve performance by reducing sudo calls
# dexa  # Apr/2019      # 1.3.0   # extend for JavaBatch types
#############################################################################
#
ScriptName="bofreminst.sh"
ScriptVersion="1.3.0"

ToptoaCopyWithRCTest() {
  local FromX=$1
  local ToX=$2
  local CopyOpt=$3
  local LogFile=$4
  sudo /bin/su - toptoa -c "cp ${CopyOpt}  ${FromX}  ${ToX}" >> ${LogFile}
  if [ ${?} -eq 0 ]; then
    echo "Succesfully copied  \"${FromX}\" to \"${ToX}\"."
  else
    echo "Failed copying \"${FromX}\" to \"${ToX}\"."
    exit 16
  fi
}	

ToptoaROCopyWithRCTest() {
## This function copies a folder recursively taking into account that
## the target files ar read-only to the owner.
  local FromX=$1
  local ToX=$2
  local CopyOpt=$3
  local LogFile=$4
  for TheFullFile in $(find ${FromX} -type f); do
    echo $TheFullFile
    TheFile=${TheFullFile/$FromX/''}
    echo $TheFile
    if sudo /bin/su - toptoa -c "test -f $ToX/$TheFile"; then
      ## add user write rights
      echo "setting write access"
      sudo /bin/su - toptoa -c "$SetACLBin -m u::rwx ${ToX}/${TheFile}" >> ${LogFile}
    fi
    echo "copying the file"
    ToptoaCopyWithRCTest $FromX/$TheFile $ToX/$TheFile "-R" $LogFile
    ## remove user write rights on the copied file
    echo "removing write access"
    sudo /bin/su - toptoa -c "$SetACLBin -m u::rx ${ToX}/${TheFile}" >> ${LogFile}
  done
}

DetermineTAR_ACL() {
case $(uname) in
  HP-UX*)
    # This is required to use the gtar-version.
    GTarBinary="/usr/local/bin/gtar"
  SetACLBin=$(which setacl)
  GetACLBin=$(which getacl)
    ;;
  Linux*)
    GTarBinary=$(which tar)
  SetACLBin=$(which setfacl)
  GetACLBin=$(which getfacl)
    ;;
  *)
    GTarBinary=$(which tar)
  SetACLBin=$(which setfacl)
  GetACLBin=$(which getfacl)
    ;;
esac
}

DeployTarsViaPublicHtml() {
local LocationOfTarFiles=$1
local DestFolderFinal=$2
local ToInstallSubfolder=$3
local DebugLevel=$4
local tarfile

echo "DeployTarsViaPublicHtml started with these options:"
echo "LocationOfTarFiles=$1"
echo "DestFolderFinal=$2"
echo "ToInstallSubfolder=$3"

DetermineTAR_ACL

cd "$LocationOfTarFiles"
for tarFile in $(find  . -name "*.tar" -type f); do

  ## TAR files need to be placed under public_html, and extracted to the parent folder of public_html
  moduleName=${tarFile%.tar}
  echo "Copying  \"${tarFile}\" to \"${DestFolderFinal}/public_html\"."
  ToptoaCopyWithRCTest "${LocationOfTarFiles}/${tarFile}" "${DestFolderFinal}/public_html/" "-R" "${ToInstallSubfolder}/toptoa_ssh.log"
  sudo /bin/su - toptoa -c "$SetACLBin -m u::rw,g::rx,o:r ${DestFolderFinal}/public_html/${tarFile}" >> ${ToInstallSubfolder}/toptoa_ssh.log
  if [ ${?} -eq 0 ]; then
    echo "Succesfully set permissions for   \"${tarFile}\" in \"${DestFolderFinal}/public_html\"."
  else
    echo "Failed setting permission for \"${tarFile}\" in \"${DestFolderFinal}/public_html\"."
    exit 16
  fi
  sampleJar=$(find ${DestFolderFinal}/lib/${moduleName}/  -name "*.jar" | head -n 1)
  if [[ -e $sampleJar ]]; then
    $GetACLBin ${sampleJar} > perms.acl
  fi
  echo "Deleting libs folder for ${moduleName} at  \"${DestFolderFinal}/lib/${moduleName}/*\""
  sudo /bin/su - toptoa -c "rm -rf ${DestFolderFinal}/lib/${moduleName}/*.jar" >> ${ToInstallSubfolder}/toptoa_ssh.log
  if [ ${?} -eq 0 ]; then
    echo "Succesfully emptied lib-folder \"${DestFolderFinal}/lib/${moduleName}\"."
  else
    echo "Failed to empty lib-folder \"${DestFolderFinal}/lib/${moduleName}\"."
    exit 16
  fi
  echo "Extracting TAR-file at  \"${DestFolderFinal}/public_html/${tarFile}\" to \"${DestFolderFinal}\""
  sudo /bin/su - toptoa -c "${GTarBinary} -xf ${DestFolderFinal}/public_html/${tarFile} -C ${DestFolderFinal}/" >> ${ToInstallSubfolder}/toptoa_ssh.log
  if [ ${?} -eq 0 ]; then
   echo "Succesfully extracted  \"${DestFolderFinal}/public_html/${tarFile}\"."
  else
   echo "Failed extracting  \"${DestFolderFinal}/public_html/${tarFile}\"."
   exit 16
  fi
  if [[ -e perms.acl ]]; then
   sudo /bin/su - toptoa -c "$SetACLBin -f perms.acl '${DestFolderFinal}/lib/${moduleName}/*.jar'" >> ${ToInstallSubfolder}/toptoa_ssh.log
  fi
  echo "Setting permissions for extracted files in  \"${DestFolderFinal}/\"."

  sudo /bin/su - toptoa -c "$SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/ini/${moduleName}/*.properties &&
  $SetACLBin -m u::rx,g::rx,o:0 ${DestFolderFinal}/ini/${moduleName}/*-passwd.properties &&
  $SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/sql/*.sql &&
  $SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/sh/*.sh &&
  $SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/xsd/*.xsd &&
  $SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/xsl/*.xsl &&
  $SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/bin/${moduleName}/*" >> ${ToInstallSubfolder}/toptoa_ssh.log
 done;
## Cleanup perm.acl
rm -rf perm.acl
}

DoInstallBOFFilesOLD() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local ToInstallSubfolder=$4
local BofDeployFolder=$5
local UnixUserOnApplSrv=$6
local DebugLevel=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BofDeployFolder}"
local AclFile="${TargetFolder}/acl.txt"
local useronapplsrv="${UnixUserOnApplSrv}"

if [[ ! -d ${DestFolderFinal} ]]; then
 echo "Het target path ${DestFolderFinal} voor ADC ${TheADC} bestaat niet!"
 exit 16
fi

## Save the current acl-permissions
mkdir -p ${ACLFolder}
if [ $? -eq 0 ]; then
  echo "Succesfully created ACL-folder \"${ACLFolder}\"."
else
  echo "Failed creating ACL-folder \"${ACLFolder}\"."
  exit 16
fi

cd ${ToInstallSubfolder}/${FormattedADC}

chmod -R g+rx  "/home/${useronapplsrv}"

DeployTarsViaPublicHtml ${ToInstallSubfolder}/${FormattedADC} ${DestFolderFinal} ${ToInstallSubfolder} ${DebugLevel}

echo "Start executing the actual install of the subfolders."
for subfolder in $(ls -d ${ToInstallSubfolder}/${FormattedADC}/*/ ); do
  fullFolder="${ToInstallSubfolder}/${FormattedADC}"
  subfolder=${subfolder/$fullFolder/''}
  if [[ $(basename ${subfolder}) != "ini" ]]; then
    ToptoaROCopyWithRCTest "${ToInstallSubfolder}/${FormattedADC}/${subfolder}/./" "${DestFolderFinal}/${subfolder}/" "-R" "${ToInstallSubfolder}/toptoa_ssh.log"
  else
    # First we must check if we have the 'old' properties files in the ini-folder, or the generated template files
    if [[ -e $fullFolder/${subfolder}/generated ]]; then
      echo "\"${subfolder}\" contains a \"generated\" folder, we will use this as a source."
      if [[ $(find $fullFolder/${subfolder} -type f) ]]; then
       echo "Folder \"${subfolder}\" contains generated files AND legacy property-files, only one may be used. Cannot continue."
       exit 16
      fi
      ToptoaCopyWithRCTest "$fullFolder/${subfolder}/generated/${TheEnv}/./" "${DestFolderFinal}/${subfolder}/" "-R" "${ToInstallSubfolder}/toptoa_ssh.log"
    else
      echo "\"${subfolder}\" contains legacy property files."
      if [[ -e $fullFolder/${subfolder}/${TheEnv} ]]; then
       echo "Found a folder for \"${TheEnv}\",  copying all files to \"${DestFolderFinal}/${subfolder}\" "

        ## We need to make sure we can overwrite the properties
       echo "Adding write privileges to property-files"
       for propertyFolder in $(ls $fullFolder/${subfolder}/${TheEnv}/); do

         sudo /bin/su - toptoa -c "$SetACLBin -m u::rwx,g::rx,o:r ${DestFolderFinal}/ini/${propertyFolder}/*.properties &&
           $SetACLBin -m u::rwx,g::rx,o:0 ${DestFolderFinal}/ini/${propertyFolder}/*-passwd.properties" >> ${ToInstallSubfolder}/toptoa_ssh.log
       done
      echo "Start copy of property files"
      ToptoaCopyWithRCTest "$fullFolder/${subfolder}/${TheEnv}/./" "${DestFolderFinal}/${subfolder}/" "-R" "${ToInstallSubfolder}/toptoa_ssh.log"
      ## Removing write properties
      echo "Removing write privileges to property-files"
       for propertyFolder in $(ls $fullFolder/${subfolder}/${TheEnv}/); do
         sudo /bin/su - toptoa -c "$SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/ini/${propertyFolder}/*.properties &&
           $SetACLBin -m u::rx,g::rx,o:0 ${DestFolderFinal}/ini/${propertyFolder}/*-passwd.properties" >> ${ToInstallSubfolder}/toptoa_ssh.log
       done 
      else
       echo "No folder for \"${TheEnv}\" was found under \"${subfolder}\", skipping."
      fi
    fi
  fi
done
echo "Finished copying subfolders to the Install-Folder."
}

DoInstallViaToptoa() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local ToInstallSubfolder=$5
local BofDeployFolder=$6
local BofGroupPrefix5=$7
local DebugLevel=$8
local ToptoaAction=$9

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BofDeployFolder}"
local AclFile="${TargetFolder}/acl.txt"

if [[ ! -d ${DestFolderFinal} ]]; then
 echo "Het target path ${DestFolderFinal} voor ADC ${TheADC} bestaat niet!"
 exit 16
fi

if [ $DebugLevel -gt 3 ]; then
  echo "DoInstallViaToptoaFiles functie gestart met deze opties:"
  echo "TheEnv                = ${TheEnv}"
  echo "TheFld                = ${TheFld}"
  echo "TheADC                = ${TheADC}"
  echo "TicketNr              = ${TicketNr}"
  echo "ToInstallSubfolder    = ${ToInstallSubfolder}"
  echo "BofDeployFolder       = ${BofDeployFolder}"
  echo "BofGroupPrefix5       = ${BofGroupPrefix5}"
  echo "DebugLevel            = ${DebugLevel}"
  echo "ToptoaAction          = ${ToptoaAction}"
fi

## Save the current acl-permissions
mkdir -p ${ACLFolder}
if [ $? -eq 0 ]; then
  echo "Succesfully created ACL-folder \"${ACLFolder}\"."
else
  echo "Failed creating ACL-folder \"${ACLFolder}\"."
  exit 16
fi

## make sure toptoa has read and execute rights on the script as well
## as on the data files that come from the ticket
chmod -R g+rx ${ToInstallSubfolder}
## call script with toptoa from
if [ $DebugLevel -gt 3 ]; then
  echo "Issuing command: sudo /bin/su - toptoa -c \"${ToInstallSubfolder}/bofremtoptoainst.sh ${ToptoaAction} ${TheEnv} ${TheFld} ${TheADC} ${TicketNr} ${ToInstallSubfolder} ${BofDeployFolder} ${BofGroupPrefix5} ${DebugLevel}\""
fi
sudo /bin/su - toptoa -c "${ToInstallSubfolder}/bofremtoptoainst.sh $ToptoaAction ${TheEnv} ${TheFld} ${TheADC} ${TicketNr} ${ToInstallSubfolder} ${BofDeployFolder} ${BofGroupPrefix5} ${DebugLevel}"
if [ $? -eq 0 ]; then
  echo "Uitvoering van toptoa sessie is goed gebeurd."
else
  echo "Failed execution of toptoa session. Please consult the below log for details:"
  cat "/home/toptoa/autodeploy/TI${TicketNr}/log.txt"
  exit 16
fi

## fetch the log file that was issued during this session
echo "log file produced by toptoa session:"
cat "/home/toptoa/autodeploy/TI${TicketNr}/log.txt"
echo "End of toptoa session log."
## delete the log
rm "/home/toptoa/autodeploy/TI${TicketNr}/log.txt"
}
