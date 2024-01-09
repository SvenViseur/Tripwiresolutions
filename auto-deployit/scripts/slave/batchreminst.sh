#
#### batchreminst.sh script
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
# dexa  # May/2020      # 1.0.0   # clone of bofreminst, reduced
#       #    /20        #  . .    #
#############################################################################
#
ScriptName="batchreminst.sh"
ScriptVersion="1.0.0"

DoInstallViaToptoa() {
# Variables which are taken from the parent-scripts.
# Options to be given:
local TheEnv=$1
local TheFld=$2
local TheADC=$3
local TicketNr=$4
local ToInstallSubfolder=$5
local BatchDeployFolder=$6
local AclGroupPrefix5=$7
local DebugLevel=$8
local ToptoaAction=$9

local TargetFolder=$ToInstallSubfolder
local ToInstallFld="${TheADC}"
local ACLFolder="${TargetFolder}/ACL"
local DestFolder="${TheEnv}"
local FormattedADC="${TheADC,,}"
local DestFolderFinal="/${DestFolder^^}/${BatchDeployFolder}"
local AclFile="${TargetFolder}/acl.txt"
local ToptoaLogFile="${TargetFolder}/toptoa_log.txt"

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
  echo "BatchDeployFolder     = ${BatchDeployFolder}"
  echo "AclGroupPrefix5       = ${AclGroupPrefix5}"
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

## remove any previous toptoa log file
rm -f ${ToptoaLogFile}
## prepare the toptoa log file
touch ${ToptoaLogFile}
## make sure toptoa has read, write and execute rights on the script as well
## as on the data files that come from the ticket
## the write access is needed for the cleanup afterwards, which toptoa will do!
chgrp -R users ${ToInstallSubfolder}/*
chmod -R g+rx ${ToInstallSubfolder}/*
## make the log file writeable for toptoa
chmod -R g+w ${ToptoaLogFile}

## call script with toptoa from
if [ $DebugLevel -gt 3 ]; then
  echo "Issuing command: sudo /bin/su - toptoa -c \"${ToInstallSubfolder}/batchremtoptoainst.sh ${ToptoaAction} ${TheEnv} ${TheFld} ${TheADC} ${TicketNr} ${ToInstallSubfolder} ${BatchDeployFolder} ${AclGroupPrefix5} ${DebugLevel} ${ToptoaLogFile} \""
fi
sudo /bin/su - toptoa -c "${ToInstallSubfolder}/batchremtoptoainst.sh $ToptoaAction ${TheEnv} ${TheFld} ${TheADC} ${TicketNr} ${ToInstallSubfolder} ${BatchDeployFolder} ${AclGroupPrefix5} ${DebugLevel} ${ToptoaLogFile}"
if [ $? -eq 0 ]; then
  echo "Uitvoering van toptoa sessie is goed gebeurd."
else
  echo "Failed execution of toptoa session. Please consult the below log for details:"
  cat "${ToptoaLogFile}"
  exit 16
fi

## fetch the log file that was issued during this session
echo "log file produced by toptoa session:"
cat "${ToptoaLogFile}"
echo "End of toptoa session log."
## delete the log, as we now have it in the Jenkins output.
rm "${ToptoaLogFile}"
}
