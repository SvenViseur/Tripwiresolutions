#!/bin/bash
#### batchremtoptoainst.sh script
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
# dexa  # May/2020      # 1.0.0   # clone of bofremtoptoainst.sh
# dexa  # May/2020      # 1.0.1   # add parameter ToptoaLogFile
# dexa  # Mar/2021      # 1.0.2   # use sudo for chgrp command
# dexa  # Mar/2021      # 1.0.2   # added Delete functionality for BATCH type
# lekri # 02/06/2021    # 1.0.3   # SSGT-65: openssl key hashing -> sha256
# lekri # 26/10/2021    # 1.0.4   # SSGT-377: force copy of the files.
#       #    /20        #  . .    #
#############################################################################
#
ScriptName="batchremtoptoainst.sh"
ScriptVersion="1.0.3"

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

DoDecryptSingleFile() {
  ## This function decrypts one file using openssl aes256 decryption
  ## using a specified password file.
  ## It then also deletes the encrypted file as it is no longer
  ## needed.
  ## Please note that this function takes the password file from a
  ## global variable and not from a parameter
  local Source=$1
  local Target=$2
  ## ensure we can write the target:
  chmod u+w $Target
  openssl enc -d -in ${Source} -out ${Target} -aes256 -md sha256 -pass file:${ThePSWFile}
  RC=$?
  if [ $RC -eq 0 ]; then
    LogLineDEBUG "Succesfully decrypted  \"${Source}\"."
  else
    LogLineERROR "Failed decryption of file \"${Source}\" with RC=${RC}."
    exit 16
  fi
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
AclGroupPrefix5=$3     ## The first 5 letters of the group to assign copied files to
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
    if [ -e "${TempDeployFolder}/${CurrentFile}.enc" ]; then
      ## we also have an encrypted variant of this file. Skip this one.
      continue
    fi
    # if the target file already exists, make it rw to the owner
    if [ -e "${DestFolderFinal}/${CurrentFile}" ]; then
      chmod u+w "${DestFolderFinal}/${CurrentFile}"
      if [ ${?} -ne 0 ]; then
        LogLineWARN "The owner of file ${DestFolderFinal}/${CurrentFile} seems incorrect, leading to a failed chmod command."
        exit 16
      fi
    fi
    # Copy the file to its target location.
    cp -f "${TempDeployFolder}/${CurrentFile}" "${DestFolderFinal}/${CurrentFile}"
    if [ ${?} -ne 0 ]; then
      LogLineERROR "The copy for file ${DestFolderFinal}/${CurrentFile} failed. Maybe check file or folder rights."
      exit 16
    fi
    # Take specific actions based on the base folder name
    # Because the CurrentFile will always start with a "/", we must get the 2nd part
    basefolder=$(echo "$CurrentFile" | awk -F "/" '{print $2}')
    case $basefolder in
      "public_html")
        TheGrp="${AclGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "bin")
        TheGrp="${AclGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "ini")
        TheGrp="${AclGroupPrefix5}e"
        TheOctMode="554"
        if [[ "$CurrentFile" == *.enc ]]; then
          ## We have an encrypted file. We should decrypt it
          DecryptFile=${CurrentFile/'.enc'/''}
          DoDecryptSingleFile "${DestFolderFinal}/${CurrentFile}" "${DestFolderFinal}/${DecryptFile}"
          rm "${DestFolderFinal}/${CurrentFile}"
          ## continue processing as if we were dealing with the base file itself, not the .enc version
          CurrentFile="${DecryptFile}"
          TheOctMode="550" ## reduce other rights as we are dealing with a password file
        fi
        ;;
      "lib")
        TheGrp="${AclGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "sh")
        TheGrp="${AclGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "sql")
        TheGrp="${AclGroupPrefix5}e"
        TheOctMode="554"
        ;;
      "xsd")
        TheGrp="${AclGroupPrefix5}e"
        TheOctMode="554"
        ;;
      *)
        LogLineERROR "The file $CurrentFile is not located in one of the authorized folders. Deploy failed."
        exit 16
        ;;
    esac
    LogLineDEBUG "issuing command: sudo /usr/bin/chgrp \"$TheGrp\" \"${DestFolderFinal}/${CurrentFile}\" "
    sudo /usr/bin/chgrp "$TheGrp" "${DestFolderFinal}/${CurrentFile}"
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

DoDeletesFromEnv() {
local TicketNr=$1
local TempDeployFolder=$2    ## The HTD folder
local DestFolderFinal=$3     ## The Env based target location
local DeleteOKCount=0
local DeleteNotFoundCount=0
local DeleteNOKCount=0

## We will parse the -deleted.txt file to get a list of files to remove
local TheDeletedFileList="/HTD/autodeploy/tmp/TI${TicketNr}/TI${TicketNr}-deleted.txt"

## check if the file exists
if [ -f "$TheDeletedFileList" ]; then
  LogLineDEBUG "The DeletedFileList exists."
else
  LogLineWARN "The deleted.txt file for this ticket, $TheDeletedFileList could not be found!! No deletes done."
  return
fi

if [ -s "$TheDeletedFileList" ]; then
  LogLineDEBUG "The DeletedFileList is not empty."
else
  LogLineINFO "File $TheDeletedFileList is empty. No deletes done."
  return
fi

local line=""
local fileOnLine=""
local RC=0
LogLineINFO "Parsing non-empty deleted.txt file: $TheDeletedFileList"
local oIFS=$IFS
IFS=""
while read -r line; do
  fileOnLine=${line:3}
  relFilename=${fileOnLine#*"/"}
  LogLineDEBUG "Deleting file ${DestFolderFinal}/${relFilename}"
  if [ -f "${DestFolderFinal}/${relFilename}" ]; then
    rm -f "${DestFolderFinal}/${relFilename}"
    RC=$?
    if [ $RC -ne 0 ]; then
      LogLineWARN "Failed to delete file ${DestFolderFinal}/${relFilename}. RC was $RC."
      ((DeleteNOKCount+=1))
    else
      LogLineDEBUG "File ${DestFolderFinal}/${relFilename} is deleted."
      ((DeleteOKCount+=1))
    fi
  else
    LogLineDEBUG "File ${DestFolderFinal}/${relFilename} is was not found. No delete done."
    ((DeleteNotFoundCount+=1))
  fi
done < ${TheDeletedFileList}
IFS=$oIFS
if [ $DeleteNOKCount -ne 0 ]; then
  LogLineERROR "$DeleteNotFoundCount files were not found, $DeleteOKCount files were successfully deleted, but $DeleteNOKCount files could not be deleted!"
  exit 16
else
  LogLineINFO "$DeleteNotFoundCount files were not found and $DeleteOKCount files were successfully deleted."
fi

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

DoInstallBatchFiles() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local ToInstallSubfolder=$5
local BatchDeployFolder=$6
local AclGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BatchDeployFolder}"
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
      if [[ $(find $fullFolder/${subfolder} -maxdepth 1 -type f) ]]; then
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
if [ "$BatchDeployFolder" = "common" ]; then
  DeployType="OTHX"
fi
if [ "$BatchDeployFolder" = "cola" ]; then
  DeployType="OTHX"
fi
DoDeletesFromEnv $TicketNr ${TempDeployFolder} ${DestFolderFinal}
DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${AclGroupPrefix5} ${DeployType}
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
local BatchDeployFolder=$6
local AclGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BatchDeployFolder}"
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
if [ "$BatchDeployFolder" = "common" ]; then
  DeployType="OTHX"
fi
if [ "$BatchDeployFolder" = "cola" ]; then
  DeployType="OTHX"
fi
DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${AclfGroupPrefix5} ${DeployType}
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
local BatchDeployFolder=$6
local AclGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BatchDeployFolder}"
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
if [ "$BatchDeployFolder" = "common" ]; then
  DeployType="OTHX"
fi
if [ "$BatchDeployFolder" = "cola" ]; then
  DeployType="OTHX"
fi
DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${AclGroupPrefix5} ${DeployType}
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
local BatchDeployFolder=$6
local AclGroupPrefix5=$7

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BatchDeployFolder}"
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

DoInstallFromHTDtoEnv ${TempDeployFolder} ${DestFolderFinal} ${AclGroupPrefix5} "PSW"
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
ArgBatchDeployFolder=$7
ArgAclGroupPrefix5=$8
DebugLevel=$9
ArgToptoaLogFile=${10}
echo "batchremtoptoainst.sh started with DebugLevel $DebugLevel."

LogFile="${ArgToptoaLogFile}"

LogLineDEBUG "Script $ScriptName started with these options:"
LogLineDEBUG "ArgAction        = ${ArgAction}"
LogLineDEBUG "ArgEnv           = ${ArgEnv}"
LogLineDEBUG "ArgFld           = ${ArgFld}"
LogLineDEBUG "ArgADC           = ${ArgADC}"
LogLineDEBUG "ArgTicketNr      = ${ArgTicketNr}"
LogLineDEBUG "ArgToInstallSubfolder = ${ArgToInstallSubfolder}"
LogLineDEBUG "ArgBatchDeployFolder = ${ArgBatchDeployFolder}"
LogLineDEBUG "ArgAclGroupPrefix5  = ${ArgAclGroupPrefix5}"
LogLineDEBUG "DebugLevel       = ${DebugLevel}"

if [ "$ArgAction" = "" ]; then
  echo "Missing parameters!"
  exit 16
fi

if [ "$ArgAction" = "BATCHDEPLOY" ]; then
  ThePSWFile="${ArgToInstallSubfolder}/MasterPSW_openssl"
  DoInstallBatchFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBatchDeployFolder} ${ArgAclGroupPrefix5}
fi

if [ "$ArgAction" = "JAVABATCHDEPLOY" ]; then
  DoInstallJavaBatchFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBatchDeployFolder} ${ArgAclGroupPrefix5}
fi

if [ "$ArgAction" = "JAVABATCHCONFIGDEPLOY" ]; then
  DoInstallJavaBatchConfigFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBatchDeployFolder} ${ArgAclGroupPrefix5}
fi

if [ "$ArgAction" = "JAVABATCHPASSWORDDEPLOY" ]; then
  DoInstallJavaBatchPasswordFiles ${ArgEnv} ${ArgFld} ${ArgADC} ${ArgTicketNr} ${ArgToInstallSubfolder} ${ArgBatchDeployFolder} ${ArgAclGroupPrefix5}
fi

