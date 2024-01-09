#!/usr/local/bin/bash
#### bofremtoptoainst.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# IMPORTANT! The code in this script will only run on TARGET servers,
# not on DeployIT servers (depm/depp/deps). Hence, you CANNOT use
# the DeployIT libraries like global_functions, error or warning log
# functions etc.
#
# IMPORTANT! This script will be COMPLETELY run under the user toptoa.
# No environment variables can be passed from the calling script.
#
# All parameters from the calling system (ticket nr, ...) should be
# passed as parameters to this script.
#
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Mar/2019      # 1.0.0   # initial version
# dexa  # Apr/2019      # 1.2.0   # rework, log functions, ticket folders
# dexa  # Apr/2019      # 1.2.0   # add .enc decryption using openssl
# dexa  # Jun/2019      # 1.2.1   # add chmod o+x for common/cola bin/sh
# lekri # Jun/2021      # 1.2.2   # SSGT-65: openssl key hashing -> sha256
#############################################################################
#
ScriptName="bofremtoptoainst.sh"
ScriptVersion="1.2.2"

## some global vars with defaults
DebugLevel=5
LogFile="/dev/null"
LibToDeleteCount=0

CopyWithRCTest() {
  local FromX=$1
  local ToX=$2
  local CopyOpt=$3
  cp ${CopyOpt}  ${FromX}  ${ToX} >> ${LogFile}
  if [ ${?} -eq 0 ]; then
    LogLineDEBUG "Succesfully copied  \"${FromX}\" to \"${ToX}\"."
  else
    LogLineERROR "Failed copying \"${FromX}\" to \"${ToX}\"."
    exit 16
  fi
}	

ROCopyWithRCTest() {
## This function copies a folder recursively taking into account that
## the target files ar read-only to the owner.
  local FromX=$1
  local ToX=$2
  local CopyOpt=$3
  for TheFullFile in $(find ${FromX} -type f); do
    echo $TheFullFile
    TheFile=${TheFullFile/$FromX/''}
    LogLineDEBUG $TheFile
    if "test -f $ToX/$TheFile"; then
      ## add user write rights
      chmod u+w ${ToX}/${TheFile}
    fi
    LogLineDEBUG "copying the file"
    CopyWithRCTest $FromX/$TheFile $ToX/$TheFile "-R" $LogFile
    ## remove user write rights on the copied file
    LogLineDEBUG "removing write access"
      chmod u-w ${ToX}/${TheFile}
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

##### Log level conventions
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
  echo "DebugLevel is incorrectly set. Resetting to INFO level." >> $LogFile
  DebugLevel=3
fi
}

LogLineWARN() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 1 ]; then
  echo "WARNING: $1" >> $LogFile
fi
}

LogLineERROR() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 1 ]; then
  echo "ERROR: $1" >> $LogFile
fi
}

LogLineINFO() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 2 ]; then
  echo "$1" >> $LogFile
fi
}
LogLineDEBUG() {
## Writes a line to StdOut depending on the log level
## Input: $1   The line to log
LogLineChkDebugLevel
if [ $DebugLevel -gt 3 ]; then
  echo "$1" >> $LogFile
fi
}

DeployTarsViaPublicHtml() {
local LocationOfTarFiles=$1
local DestFolder=$2
local tarfile

LogLineDEBUG "DeployTarsViaPublicHtml started with these options:"
LogLineDEBUG "LocationOfTarFiles=$1"
LogLineDEBUG "DestFolder=$2"

DetermineTAR_ACL

cd "$LocationOfTarFiles"
for tarFile in $(find  . -name "*.tar" -type f); do

  ## TAR files need to be placed under public_html, and extracted to the parent folder of public_html
  moduleName=${tarFile%.tar}
  LogLineDEBUG "Copying  \"${tarFile}\" to \"${DestFolder}/public_html\"."
  CopyWithRCTest "${LocationOfTarFiles}/${tarFile}" "${DestFolder}/public_html/" "-R"

  ## log the LibToDelete folder
  ((LibToDeleteCount++))
  LibToDelete[${LibToDeleteCount}]="lib/${moduleName}"

  LogLineINFO "Extracting TAR-file at  \"${DestFolder}/public_html/${tarFile}\" to \"${DestFolder}\""
  LogLineDEBUG "Issuing command: ${GTarBinary} -xf ${DestFolder}/public_html/${tarFile} -C ${DestFolder}/ >> ${LogFile}"
  "${GTarBinary}" -xf "${DestFolder}/public_html/${tarFile}" -C "${DestFolder}/" >> ${LogFile}
  RC=$?
  if [ $RC -eq 0 ]; then
   LogLineDEBUG "Succesfully extracted  \"${DestFolder}/public_html/${tarFile}\"."
  else
   LogLineERROR "Failed extracting  \"${DestFolder}/public_html/${tarFile}\" with RC=${RC}."
   exit 16
  fi
 done;
}

DoDecryptEncFiles() {
## This function scans a specified folder, finds all .enc files
## and uses openssl aes256 decryption using a specified password file.
## It then also deletes the encrypted password file as it is no longer
## needed.
local Target=$1
local PSWFile=$2
local DecryptCount=0
for TheEncFile in $(find ${Target} -name "*.enc" -type f)
  do
    CurrentFile=${TheEncFile/$Target/''}
    DecryptFile=${CurrentFile/'.enc'/''}
    openssl enc -d -in ${Target}/${CurrentFile} -out ${Target}/${DecryptFile} -aes256 -md sha256 -pass file:${PSWFile}
    RC=$?
    if [ $RC -eq 0 ]; then
      LogLineDEBUG "Succesfully decrypted  \"${Target}/${CurrentFile}\"."
    else
      LogLineERROR "Failed decryption of file \"${Target}/${CurrentFile}\" with RC=${RC}."
      exit 16
    fi
    ## now that the file is decrypted, we can safely delete the encrypted one
    rm -f ${Target}/${CurrentFile}
    ((DecryptCount++))
  done
if [ $DecryptCount -eq 0 ]; then
  LogLineERROR "A decryption was asked, but no files were found to decrypt. Cannot continue."
  exit 16
else
  LogLineINFO "Number of files decrypted: $DecryptCount."
fi
}

DoInstallFromHTDtoEnv() {
TempDeployFolder=$1    ## The HTD folder
DestFolderFinal=$2     ## The Env based target location
BofGroupPrefix5=$3     ## The first 5 letters of the group to assign copied files to
DeployType=$4          ## This string indicates specific types of installs:
                       ## NORMAL  : no special actions to take
                       ## OTHX    : in bin and sh, others should have execute also
                       ## PSW     : all installed files must not be readable to the others

## Now we have everything ready to do the real deploy from the TempDeployFolder to
## the real target location. We need to pay attention to multiple elements:
## - the lib folders for specific applications first must be cleaned.
## - some target files might be read-only to our toptoa account.
## - after the copy of a file, we must set the group correctly according to some rules
## - also after the copy, the acls must be set using chmod.

LogLineDEBUG "Starting DoInstallFromHTDtoEnv with DeployType $DeployType"

## Deploy step 1 - clean the requested lib folders
for (( i=1 ; i<=$(( $LibToDeleteCount )); i++))
  do
    rm -rf "${DestFolderFinal}/lib/LibToDelete[${i}]/*"
    if [ ${?} -ne 0 ]; then
      LogLineERROR "De lib folder ${DestFolderFinal}/lib/LibToDelete[${i}] kon niet leeggemaakt worden."
      exit 16
    fi 
  done

## Deploy step 2 - copy each file and set the correct rights
cd "$TempDeployFolder"
for TheFullFile in $(find $TempDeployFolder -type f)
  do
    CurrentFile=${TheFullFile/$TempDeployFolder/''}
    # if the target file already exists, make it rw to the owner
    if [ -e "${DestFolderFinal}/${CurrentFile}" ]; then
      chmod u+w "${DestFolderFinal}/${CurrentFile}"
      if [ ${?} -ne 0 ]; then
        LogLineWARN "The owner of file ${DestFolderFinal}/${CurrentFile} seems incorrect, leading to a failed chmod command."
        exit 16
      fi 
    fi
    # Copy the file to its target location.
    cp "${TempDeployFolder}/${CurrentFile}" "${DestFolderFinal}/${CurrentFile}"
    if [ ${?} -ne 0 ]; then
      LogLineERROR "The copy for file ${DestFolderFinal}/${CurrentFile} failed. Maybe check file or folder rights."
      exit 16
    fi 
    # Take specific actions based on the base folder name
    # Because the CurrentFile will always start with a "/", we must get the 2nd part
    basefolder=$(echo "$CurrentFile" | awk -F "/" '{print $2}')
    case $basefolder in
      "public_html")
        TheGrp="${BofGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "bin")
        TheGrp="${BofGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "ini")
        TheGrp="${BofGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "lib")
        TheGrp="${BofGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "sh")
        TheGrp="${BofGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "sql")
        TheGrp="${BofGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "xsd")
        TheGrp="${BofGroupPrefix5}e"
        TheOctMode="554"
        ;;
      *)
        LogLineERROR "The file $CurrentFile is not located in one of the authorized folders. Deploy failed."
        exit 16
        ;;  
    esac
    LogLineDEBUG "issuing command: chgrp \"$TheGrp\" \"${DestFolderFinal}/${CurrentFile}\" "
    chgrp "$TheGrp" "${DestFolderFinal}/${CurrentFile}"
    if [ ${?} -ne 0 ]; then
      LogLineERROR "The group for file ${DestFolderFinal}/${CurrentFile} could not be set to $TheGrp. Maybe check file or folder rights."
      exit 16
    fi
    LogLineDEBUG "issuing command: chmod \"$TheOctMode\" \"${DestFolderFinal}/${CurrentFile}\" "
    chmod "$TheOctMode" "${DestFolderFinal}/${CurrentFile}"
    if [ ${?} -ne 0 ]; then
      LogLineERROR "The rights for file ${DestFolderFinal}/${CurrentFile} could not be set to $TheOctMode. Maybe check file or folder rights."
      exit 16
    fi 
    if [ ${DeployType} = "OTHX" ]; then
      if [[ "$basefolder" = "bin" ]] || [[ "$basefolder" = "sh" ]]; then
        LogLineDEBUG "issuing command: chmod o+x \"${DestFolderFinal}/${CurrentFile}\" "
        chmod o+x "${DestFolderFinal}/${CurrentFile}"
        if [ ${?} -ne 0 ]; then
          LogLineERROR "The other rights for file ${DestFolderFinal}/${CurrentFile} could not be set to executable. Maybe check file or folder rights."
          exit 16
        fi
      fi
    fi
    if [ ${DeployType} = "PSW" ]; then
      LogLineDEBUG "issuing command: chmod o-rwx \"${DestFolderFinal}/${CurrentFile}\" "
      chmod o-rwx "${DestFolderFinal}/${CurrentFile}"
      if [ ${?} -ne 0 ]; then
        LogLineERROR "The other rights for file ${DestFolderFinal}/${CurrentFile} could not be removed. Maybe check file or folder rights."
        exit 16
      fi
    fi
  done
}

MakeDefaultSubdirs() {
local TargetFolder=$1
mkdir "${TargetFolder}/bin"
mkdir "${TargetFolder}/ini"
mkdir "${TargetFolder}/lib"
mkdir "${TargetFolder}/public"
mkdir "${TargetFolder}/public_html"
mkdir "${TargetFolder}/sh"
mkdir "${TargetFolder}/sql"
mkdir "${TargetFolder}/xsd"
}

DoInstallBOFFiles() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local ToInstallSubfolder=$5
local BofDeployFolder=$6
local BofGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BofDeployFolder}"
local AclFile="${TargetFolder}/acl.txt"
local useronapplsrv="${UnixUserOnApplSrv}"
local TempDeployFolder="/HTD/autodeploy/TI${TicketNr}"

if [[ ! -d ${DestFolderFinal} ]]; then
 LogLineERROR "Het target path ${DestFolderFinal} voor ADC ${TheADC} bestaat niet!"
 exit 16
fi

## prepare the TempDeployFolder
## All files that come from the ticket, directly or indirectly (via tar)
## will first be installed in this temporary location.
## Then in a second phase, the resulting set of files will be copied
## to the final destination, whereby special attention is paid to
## ownership of files and access rights.

rm -rf ${TempDeployFolder}
mkdir -p ${TempDeployFolder}
if [ ${?} -ne 0 ]; then
  LogLineERROR "De tijdelijke folder ${TempDeployFolder} kon niet aangemaakt worden."
  exit 16
fi 
MakeDefaultSubdirs ${TempDeployFolder}

## first we will expand the tar files there
DeployTarsViaPublicHtml ${ToInstallSubfolder}/${FormattedADC} ${TempDeployFolder}

## now we will go over each subfolder and copy the related files
cd ${ToInstallSubfolder}/${FormattedADC}

echo "Start executing the actual install of the subfolders."
for subfolder in $(ls -d ${ToInstallSubfolder}/${FormattedADC}/*/ ); do
  fullFolder="${ToInstallSubfolder}/${FormattedADC}"
  subfolder=${subfolder/$fullFolder/''}
  if [[ $(basename ${subfolder}) != "ini" ]]; then
    CopyWithRCTest "${ToInstallSubfolder}/${FormattedADC}/${subfolder}/./" "${TempDeployFolder}/${subfolder}/" "-R"
  else
    # First we must check if we have the 'old' properties files in the ini-folder, or the generated template files
    if [[ -e $fullFolder/${subfolder}/generated ]]; then
      LogLineINFO "\"${subfolder}\" contains a \"generated\" folder, we will use this as a source."
      if [[ $(find $fullFolder/${subfolder} -type f) ]]; then
       LogLineERROR "Folder \"${subfolder}\" contains generated files AND legacy property-files, only one may be used. Cannot continue."
       exit 16
      fi
      CopyWithRCTest "$fullFolder/${subfolder}/generated/${TheEnv}/./" "${TempDeployFolder}/${subfolder}/" "-R"
    else
      echo "\"${subfolder}\" contains legacy property files."
      if [[ -e $fullFolder/${subfolder}/${TheEnv} ]]; then
        LogLineINFO "Found a folder for \"${TheEnv}\",  copying all files to \"${TempDeployFolder}/${subfolder}\" "

        ## We need to make sure we can overwrite the properties
        #echo "Adding write privileges to property-files"
        #for propertyFolder in $(ls $fullFolder/${subfolder}/${TheEnv}/); do

        #  "$SetACLBin -m u::rwx,g::rx,o:r ${DestFolderFinal}/ini/${propertyFolder}/*.properties &&
        #   $SetACLBin -m u::rwx,g::rx,o:0 ${DestFolderFinal}/ini/${propertyFolder}/*-passwd.properties" >> ${ToInstallSubfolder}/toptoa_ssh.log
        #done
        #echo "Start copy of property files"
        CopyWithRCTest "$fullFolder/${subfolder}/${TheEnv}/./" "${TempDeployFolder}/${subfolder}/" "-R"
        ## Removing write properties
        #echo "Removing write privileges to property-files"
        #for propertyFolder in $(ls $fullFolder/${subfolder}/${TheEnv}/); do
        #  "$SetACLBin -m u::rx,g::rx,o:r ${DestFolderFinal}/ini/${propertyFolder}/*.properties &&
        #   $SetACLBin -m u::rx,g::rx,o:0 ${DestFolderFinal}/ini/${propertyFolder}/*-passwd.properties" >> ${ToInstallSubfolder}/toptoa_ssh.log
        #done 
      else
        LogLineWARN "No folder for \"${TheEnv}\" was found under \"${subfolder}\", skipping."
      fi
    fi
  fi
done
LogLineINFO "Finished copying subfolders to the TempDeployFolder-Folder."
local DeployType="NORMAL"
if [ "$BofDeployFolder" = "common" ]; then
  DeployType="OTHX"
fi
if [ "$BofDeployFolder" = "cola" ]; then
  DeployType="OTHX"
fi
DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${BofGroupPrefix5} ${DeployType}
LogLineDEBUG "Cleaning HTD temporary folder ..."
cd /
rm -rf ${TempDeployFolder}

}

DoInstallJavaBatchFiles() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local ToInstallSubfolder=$5
local BofDeployFolder=$6
local BofGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BofDeployFolder}"
local AclFile="${TargetFolder}/acl.txt"
local useronapplsrv="${UnixUserOnApplSrv}"
local TempDeployFolder="/HTD/autodeploy/TI${TicketNr}"

if [[ ! -d ${DestFolderFinal} ]]; then
 LogLineERROR "Het target path ${DestFolderFinal} voor ADC ${TheADC} bestaat niet!"
 exit 16
fi

## prepare the TempDeployFolder
## All files that compe from the ticket, directly or indirectly (via tar)
## will first be installed in this temporary location.
## Then in a second phase, the resulting set of files will be copied
## to the final destination, whereby special attention is paid to
## ownership of files and access rights.

rm -rf ${TempDeployFolder}
mkdir -p ${TempDeployFolder}
if [ ${?} -ne 0 ]; then
  LogLineERROR "De tijdelijke folder ${TempDeployFolder} kon niet aangemaakt worden."
  exit 16
fi 
MakeDefaultSubdirs ${TempDeployFolder}

## first we will expand the tar files there
DeployTarsViaPublicHtml ${ToInstallSubfolder}/${FormattedADC} ${TempDeployFolder}

local DeployType="NORMAL"
if [ "$BofDeployFolder" = "common" ]; then
  DeployType="OTHX"
fi
if [ "$BofDeployFolder" = "cola" ]; then
  DeployType="OTHX"
fi
DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${BofGroupPrefix5} ${DeployType}
LogLineDEBUG "Cleaning HTD temporary folder ..."
cd /
rm -rf ${TempDeployFolder}

}

DoInstallJavaBatchConfigFiles() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local ToInstallSubfolder=$5
local BofDeployFolder=$6
local BofGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BofDeployFolder}"
local AclFile="${TargetFolder}/acl.txt"
local useronapplsrv="${UnixUserOnApplSrv}"
local TempDeployFolder="/HTD/autodeploy/TI${TicketNr}"

if [[ ! -d ${DestFolderFinal} ]]; then
 LogLineERROR "Het target path ${DestFolderFinal} voor ADC ${TheADC} bestaat niet!"
 exit 16
fi

## prepare the TempDeployFolder
## All files that compe from the ticket, directly or indirectly (via tar)
## will first be installed in this temporary location.
## Then in a second phase, the resulting set of files will be copied
## to the final destination, whereby special attention is paid to
## ownership of files and access rights.

rm -rf ${TempDeployFolder}
mkdir -p ${TempDeployFolder}
if [ ${?} -ne 0 ]; then
  LogLineERROR "De tijdelijke folder ${TempDeployFolder} kon niet aangemaakt worden."
  exit 16
fi 
MakeDefaultSubdirs ${TempDeployFolder}

## untar the tar file that was prepared by the predeploy script.
DetermineTAR_ACL
TarFile="${ToInstallSubfolder}/TI${ArgTicketNr}-${TheADC}-config.tar"
LogLineINFO "Extracting TAR-file ${TarFile}"
LogLineDEBUG "Issuing command: ${GTarBinary} -xf ${TarFile} -C ${TempDeployFolder}/ >> ${LogFile}"
"${GTarBinary}" -xf "${TarFile}" -C "${TempDeployFolder}/" >> ${LogFile}
RC=$?
if [ $RC -eq 0 ]; then
  LogLineDEBUG "Succesfully extracted  \"${DestFolder}/public_html/${tarFile}\"."
else
  LogLineERROR "Failed extracting  \"${DestFolder}/public_html/${tarFile}\" with RC=${RC}."
  exit 16
fi


local DeployType="NORMAL"
if [ "$BofDeployFolder" = "common" ]; then
  DeployType="OTHX"
fi
if [ "$BofDeployFolder" = "cola" ]; then
  DeployType="OTHX"
fi
DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${BofGroupPrefix5} ${DeployType}
LogLineDEBUG "Cleaning HTD temporary folder ..."
cd /
rm -rf ${TempDeployFolder}

}

DoInstallJavaBatchPasswordFiles() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local ToInstallSubfolder=$5
local BofDeployFolder=$6
local BofGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BofDeployFolder}"
local AclFile="${TargetFolder}/acl.txt"
local useronapplsrv="${UnixUserOnApplSrv}"
local TempDeployFolder="/HTD/autodeploy/TI${TicketNr}"

if [[ ! -d ${DestFolderFinal} ]]; then
 LogLineERROR "Het target path ${DestFolderFinal} voor ADC ${TheADC} bestaat niet!"
 exit 16
fi

## prepare the TempDeployFolder
## All files that compe from the ticket, directly or indirectly (via tar)
## will first be installed in this temporary location.
## Then in a second phase, the resulting set of files will be copied
## to the final destination, whereby special attention is paid to
## ownership of files and access rights.

rm -rf ${TempDeployFolder}
mkdir -p ${TempDeployFolder}
if [ ${?} -ne 0 ]; then
  LogLineERROR "De tijdelijke folder ${TempDeployFolder} kon niet aangemaakt worden."
  exit 16
fi 
MakeDefaultSubdirs ${TempDeployFolder}

## untar the tar file that was prepared by the predeploy script.
DetermineTAR_ACL
TarFile="${ToInstallSubfolder}/TI${ArgTicketNr}-${TheADC}-psw.tar"
LogLineINFO "Extracting TAR-file ${TarFile}"
LogLineDEBUG "Issuing command: ${GTarBinary} -xf ${TarFile} -C ${TempDeployFolder}/ >> ${LogFile}"
"${GTarBinary}" -xf "${TarFile}" -C "${TempDeployFolder}/" >> ${LogFile}
RC=$?
if [ $RC -eq 0 ]; then
  LogLineDEBUG "Succesfully extracted  \"${DestFolder}/public_html/${tarFile}\"."
else
  LogLineERROR "Failed extracting  \"${DestFolder}/public_html/${tarFile}\" with RC=${RC}."
  exit 16
fi

DoDecryptEncFiles ${TempDeployFolder} ${ToInstallSubfolder}/MasterPSW_openssl
## We no longer need the password file now: delete it
rm -f ${ToInstallSubfolder}/MasterPSW_openssl

DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${BofGroupPrefix5} "PSW"
LogLineDEBUG "Cleaning HTD temporary folder ..."
cd /
rm -rf ${TempDeployFolder}

}

## Argument processing
ArgAction=$1
ArgEnv=$2
ArgFld=$3
ArgADC=$4
ArgTicketNr=$5
ArgToInstallSubfolder=$6
ArgBofDeployFolder=$7
ArgGroupPrefix5=$8
DebugLevel=$9
echo "bofremtoptoainst.sh started with DebugLevel $DebugLevel."

LogFileFolder="/home/toptoa/autodeploy/TI${ArgTicketNr}"
LogFile="${LogFileFolder}/log.txt"

## prepare the log file
rm -rf ${LogFileFolder}
mkdir -p ${LogFileFolder}
if [ ${?} -ne 0 ]; then
  echo "De logfile folder ${LogFileFolder} kon niet aangemaakt worden."
  exit 16
fi 
touch ${LogFile}
chmod g+rwx ${LogFileFolder}
## the above chmod command will allow the calling script to delete
## the log file (and any other files in that folder) after usage

LogLineDEBUG "Script $ScriptName started with these options:"
LogLineDEBUG "ArgAction        = ${ArgAction}"
LogLineDEBUG "ArgEnv           = ${ArgEnv}"
LogLineDEBUG "ArgFld           = ${ArgFld}"
LogLineDEBUG "ArgADC           = ${ArgADC}"
LogLineDEBUG "ArgTicketNr      = ${ArgTicketNr}"
LogLineDEBUG "ArgToInstallSubfolder = ${ArgToInstallSubfolder}"
LogLineDEBUG "ArgBofDeployFolder = ${ArgBofDeployFolder}"
LogLineDEBUG "ArgGroupPrefix5  = ${ArgGroupPrefix5}"
LogLineDEBUG "DebugLevel       = ${DebugLevel}"

if [ "$ArgAction" = "" ]; then
  echo "Missing parameters!"
  exit 16
fi

if [ "$ArgAction" = "BOFDEPLOY" ]; then
  DoInstallBOFFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBofDeployFolder} ${ArgGroupPrefix5}
fi

if [ "$ArgAction" = "JAVABATCHDEPLOY" ]; then
  DoInstallJavaBatchFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBofDeployFolder} ${ArgGroupPrefix5}
fi

if [ "$ArgAction" = "JAVABATCHCONFIGDEPLOY" ]; then
  DoInstallJavaBatchConfigFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBofDeployFolder} ${ArgGroupPrefix5}
fi

if [ "$ArgAction" = "JAVABATCHPASSWORDDEPLOY" ]; then
  DoInstallJavaBatchPasswordFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBofDeployFolder} ${ArgGroupPrefix5}
fi

