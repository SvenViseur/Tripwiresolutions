#!/bin/bash
#### V1_ivldply_deploy.sh script
# This script is called from the ivldply_functions.sh
#
# Command line options:
# option             mand.     value (all values are case sensitive!!!)
# -T<target>          YES      the target application, either "IVL" or "CIVL"
# -E<environment>     YES      the target Environment, either "ACC","SIM","PRD","SIC"
# -D<directory name>  YES      the directory where the zip resides and where log information can be written to
# -F<deploy zip file> YES      the zip file that should be deployed
# -A<type deploy>     YES      the type deploy: OEMM or RT (run-time)
# -N<ticket number>   YES      the TraceIT ticket number
# -V<version>         YES      the version should be the same as the script version
#
# compared with the old auto-deploy:
# Steps defined in the Jenkins Job:
#   sh "/data/deploy-it/scripts/ivlprep.sh ${appl} \${TICKETNR} ${env} \${DEPLOY_TARGET}"
#   sh "/data/deploy-it/scripts/ivlpredeploy.sh ${appl} \${TICKETNR} ${env} \${DEPLOY_TARGET}"
#   sh "/data/deploy-it/scripts/ivlinst.sh ${appl} \${TICKETNR} ${env} \${DEPLOY_TARGET}"
#
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# visv  # Jan/2021      # 1.0.0   # initial version
#############################################################################
ivlrun_dply_main_script_version="V1"

SetLogFile()
{

LOG_FILE="${ivllog}/IVLDPLY_dply_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

SetLocalLogFile()
{

main_log_file_copy=$LOG_FILE

#Override the log settings for the specific directory
LOG_FILE="${ivldply_directory}/IVLDPLY_$(date +"%Y%m%d_%H%M%S").log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

DoCopyLogFile()
{

cat ${LOG_FILE} >> ${main_log_file_copy}

}

Initialise()
{
    SUBROUTINE=$0

    # General Settings and procedures
    . $colash/ShProcedures.sh;
    . $colash/Oracle.sh;
}

LoadIniFiles()
{
  source ${ivlini}/${ivldply_code_version}_ivl_dply.properties
  source ${ivlini}/${ivldply_code_version}_ivl_dply_credentials.properties
}

## The values used in the below functions are loaded via a call to the
## LoadIniFiles function. That loads 2 properties files. The contents of
## those files is built during the deploy using placeholders and ConfigIT.
getRTSettings() {
export ODI_URL="$OdiRTUrl"
export ODI_USER="$OdiRTDeployUser"
export ODI_PWD="$OdiRTDeployPsw"
export ODI_MASTER_USER="$OdiRTMasterUser"
export ODI_MASTER_PWD="$OdiRTMasterPsw"
export ODI_WORKREP="WORKREP"
}

getOEMMSettings() {
export ODI_URL="$OdiOEMMUrl"
export ODI_USER="$OdiOEMMDeployUser"
export ODI_PWD="$OdiOEMMDeployPsw"
export ODI_MASTER_USER="$OdiOEMMMasterUser"
export ODI_MASTER_PWD="$OdiOEMMMasterPsw"
export ODI_WORKREP="WORKREP"
}

ClearEngineSettings() {
export ODI_URL="None selected"
export ODI_USER="No_User"
export ODI_PWD="No_Password"
export ODI_MASTER_USER="No_User"
export ODI_MASTER_PWD="No_Password"
export ODI_WORKREP="No_Repo"
}

DoIvlOneOdiOEMM() {
local OdiFolder=$1
local OdiSet=$2
local TheFld=$3
local DebugLevel=$4

Log "DoIvlOneOdi functie gestart voor folder ${OdiFolder}"
export ODI_USER="No_User"
## load the credentials
  #declare -x GROOVY_CONF="${ivlini}/${ivldply_code_version}_ivldply-groovy-${ArgTarget}.cfg"
  export GROOVY_CONF="${ivlini}/${ivloem_odi_version}"
##  export GROOVY_CONF="${ivlini}/${ivldply_code_version}_ivldply-groovy-${ArgTarget}.cfg"

if [ $DebugLevel -gt 3 ]; then
  Log "Alle verdere ODI groovy stappen voor deze ${OdiSet} deploy gebruiken deze settings:"
  Log "GROOVY_CONF   : $GROOVY_CONF with contents:"
  cat $GROOVY_CONF >> $LOG_FILE
  Log "End of $GROOVY_CONF contents"
fi

  getOEMMSettings

if [ $ODI_USER = "No_User" ]; then
  Log "De load of OEMM credentials failed. Check the credentials properties file."
  exit 16
fi

  ## Stap 1: uitrol dataserver op OEMM enging
  cd $OdiFolder
  ## test if DATASERVER_ to deploy
  local DataServerZip="DATASERVER_${OdiSet}.zip"
  Log "Search for : "${DataServerZip}
  if [ -e "${DataServerZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy options voor de uitrol van TOPOLOGY set naar de OEMM engine."
      Log "Groovy options      : $groovy_opts"
      Log "Groovy script       : /$platform/ivl/lib/civl_importDataserver.groovy"
      Log "DataServer zip file : ${DataServerZip}"
      Log "ODI_URL             : $ODI_URL"
    fi
    Log "#####################################"
    Log "### Start applyDataServer on OEMM ###"
    Log "#####################################"

    mkdir -p ${TheFld}/tmp/DATASERVER
    unzip ${DataServerZip} -d ${TheFld}/tmp/DATASERVER

    for dataserver_file in  ${TheFld}/tmp/DATASERVER/*.xml
    do
       dataserver_name=$(cat ${dataserver_file} | grep ConName | cut -d "[" -f2-4 | cut -d "[" -f2 | cut -d "]" -f1)
       Log "Proces Dataserver for : -f ${dataserver_file} -n ${dataserver_name}"
       ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_importDataserver.groovy -f ${dataserver_file} -n ${dataserver_name} >> $LOG_FILE 2>&1
       if [ $? -ne 0 ]; then
         # Stap 2: The deploy failed. Retry it with first the removeObjectsFromRepo script
         Log "End applyDataServer on OEMM"
         Log "De dataserver archive ${dataserver_name} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
         exit 16
       fi
    done
    if [ $? -ne 0 ]; then
      # Stap 2: The deploy failed. Retry it with first the removeObjectsFromRepo script
      Log "End applyDataServer on OEMM"
      Log "De dataserver archive ${DataServerZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      exit 16
    fi
    Log "End applyDataServer on OEMM"
  else
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy naar OEMM: geen DATASERVER ZIP bestand gevonden."
    fi
  fi ##test -e DataServerZip

  ## Stap 2: uitrol topology op OEMM engine
  cd $OdiFolder
  ## test if TOPOLOGY_ to deploy
  local TopoZip="TOPOLOGY_${OdiSet}.zip"
  if [ -e "${TopoZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy options voor de uitrol van TOPOLOGY set naar de OEMM engine."
      Log "Groovy options: $groovy_opts"
      Log "Groovy script : /$platform/ivl/lib/civl_applyTopology.groovy"
      Log "Topo zip file : ${TopoZip}"
      Log "ODI_URL       : $ODI_URL"
    fi
    Log "#####################################"
    Log "### Start applyTopology on OEMM   ###"
    Log "#####################################"
    ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_applyTopology.groovy -f ${TopoZip} >> $LOG_FILE  2>&1
    if [ $? -ne 0 ]; then
      # Stap 2: The deploy failed. Retry it with first the removeObjectsFromRepo script
      Log "End applyTopology on OEMM"
      Log "De topology archive ${TopoZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      exit 16
    fi
    Log "End applyTopology on OEMM"
  else
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy naar OEMM: geen TOPOLOGY ZIP bestand gevonden."
    fi
  fi ##test -e TopoZip

  ## Stap 3: DeployArchive van de EXEC naar de OEMM engine
  cd $OdiFolder
  ## test if base zip exists to deploy
  local OdiZip="${OdiSet}.zip"
  if [ -e "${OdiZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy options voor de uitrol van FULL set naar de OEMM engine."
      Log "Groovy options: $groovy_opts"
      Log "Groovy script : /$platform/ivl/lib/${ivldply_code_version}_civl_applyDeployArchive.groovy"
      Log "ODI zip file  : ${OdiZip}"
      Log "ODI_URL       : $ODI_URL"
      Log "Parameters    : -f ${OdiZip} -p ${OdiProject} "
    fi
    Log "###########################################"
    Log "### Start removeObjectsFromRepo on OEMM ###"
    Log "###########################################"

    ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_removeObjectsFromRepo.groovy -f ${OdiZip} -p ${OdiProject} >> $LOG_FILE 2>&1
    Log "End removeObjectsFromRepo on OEMM"
    Log "Start applyDeployArchive on OEMM"

    ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_applyDeployArchive.groovy -f ${OdiZip} >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
      # stap 6: It still fails. Report the error
      Log "End applyDeployArchive on OEMM"
      Log "De archive ${OdiZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      exit 16
    fi
    Log "End applyDeployArchive on OEMM"
  else
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy naar OEMM: geen FULL zip bestand gevonden."
    fi
  fi ##test -e OdiZip on base zip
  ##stap 7: LoadPlans opladen op OEMM
  local OdiZip="LP_${OdiSet}.zip"
  if [ -e "${OdiZip}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy options voor de uitrol van LOAD PLAN set naar de OEMM engine."
      Log "Groovy options: $groovy_opts"
      Log "Groovy script : /$platform/ivl/lib/${ivldply_code_version}_civl_importLoadplans.groovy"
      Log "ODI zip file  : ${OdiZip}"
      Log "ODI_URL       : $ODI_URL"
    fi
    mkdir -p ${TheFld}/tmp/LOADPLANS
    unzip ${OdiZip} -d ${TheFld}/tmp/LOADPLANS
    if [ $DebugLevel -gt 3 ]; then
      Log "Contents of the zip file:"
      ls -l ${TheFld}/tmp/LOADPLANS >> $LOG_FILE
    fi
    Log "#####################################"
    Log "### Start importLoadplans on OEMM ###"
    Log "#####################################"
    ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_importLoadplans.groovy -d ${TheFld}/tmp/LOADPLANS >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
      # Stap 8: LP load fails. Report the error
      Log "End importLoadplans on OEMM"
      Log "De Loadplan archive ${OdiZip} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      exit 16
    fi
    Log "End importLoadplans on OEMM"
    ## clean up the LOADPLANS folder
    rm -rf ${TheFld}/tmp/LOADPLANS
  else
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy naar OEMM: geen LP_ bestand gevonden."
    fi
  fi ##test -e OdiZip on LP
  ## Stap 9: Link topology
  cd $OdiFolder
  ## test if .topology to deploy
  local TopoFile="${OdiSet}.topology"
  if [ -e "${TopoFile}" ]; then
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy options voor de uitrol van TOPOLOGY set naar de OEMM engine."
      Log "Groovy options: $groovy_opts"
      Log "Groovy script : /$platform/ivl/lib/${ivldply_code_version}_civl_link_context_topology.groovy"
      Log "Topo file     : ${TopoFile}"
      Log "ODI_URL       : $ODI_URL"
    fi
    Log "###########################################"
    Log "### Start link_context_topology on OEMM ###"
    Log "###########################################"
    ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_link_context_topology.groovy -f ${TopoFile} >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
      # Stap 10: The TopoFile failed.
      Log "End link_context_topology on OEMM"
      Log "De topology ${TopoFile} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
      exit 16
    fi
    Log "End link_context_topology on OEMM"
  else
    if [ $DebugLevel -gt 3 ]; then
      Log "ODI deploy naar OEMM: geen .topology bestand gevonden."
    fi
  fi ##test -e TopoZip
  ## Stap 11: Check_Release
  cd $OdiFolder
  local OdiInfo="${OdiSet}.odiinfo"
  if [ ! -e "${OdiInfo}" ]; then
    Log "De odiinfo ${OdiInfo} kon niet geladen worden in de OEMM omgeving. Deploy is gefaald."
    exit 16
  fi
  if [ $DebugLevel -gt 3 ]; then
    Log "ODI deploy options voor de controle op de OEMM engine."
    Log "Groovy options: $groovy_opts"
    Log "Groovy script : /$platform/ivl/lib/${ivldply_code_version}_civl_check_release.groovy"
    Log "OdiInfo file  : ${OdiInfo}"
    Log "ODI_URL       : $ODI_URL"
  fi
  Log "###################################"
  Log "### Start check_release on OEMM ###"
  Log "###################################"
  ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_check_release.groovy -f ${OdiInfo} >> $LOG_FILE 2>&1
  if [ $? -ne 0 ]; then
    # Stap 12: The Check_Release failed.
    Log "End check_release on OEMM"
    Log "De check_release op basis van de ${OdiInfo} is gefaald in de OEMM omgeving. Deploy is gefaald."
    exit 16
  fi
  Log "End check_release on OEMM"
  ##Stap 13: movescenarios
  Log "#####################################"
  Log "### Start movingscenarios on OEMM ###"
  Log "#####################################"
  ${ivldply_groovy_path}/groovy $groovy_opts /$platform/ivl/lib/${ivldply_code_version}_civl_movingscenarios.groovy -p ${OdiProject} >> $LOG_FILE 2>&1
  Log "End movingscenarios on OEMM"
  ## We don't care if the above failed or not.

  Log "#######################"
  Log "### END OEMM DEPLOY ###"
  Log "#######################"

}

DoOEMMDeploy()
{
  SUBROUTINE=$0
  source ${ivlsh}/${ivldply_code_version}_ivldply_functions.sh

  Log "OEMM Deploy is started"
  Log "Target=${ArgTarget}"
  Log "Environment=${ArgEnvironment}"
  Log "Directory=${ArgDirectory}"
  Log "ZIP FileName=${ArgFileName}"
  Log "Type of Deploy=${ArgTypeDeploy}"
  Log "TraceIT ticket=${ArgTraceITticket}"
  Log "Script Version=${ArgVersion}"
  Log "ini folder=${ivlini}"
  ivldply_initialize

  ## Stap 0: unzip the zip file
  TmpFolder="/${platform}/ivl/tmp/${ArgTypeDeploy}_${ArgTarget}_${ArgEnvironment}_${ArgTraceITticket}"
  Log "temp folder=${TmpFolder}"
  rm -rf $TmpFolder
  mkdir $TmpFolder
  if [ $? -ne 0 ]; then
    Log "Could not create temp folder!"
    exit 16
  fi
  mkdir ${TmpFolder}/unzipped
  cd ${TmpFolder}/unzipped
  unzip $ArgDirectory/$ArgFileName
  if [ $? -ne 0 ]; then
    Log "ERROR: De unzip operatie verliep niet goed. Mogelijks is de zip file beschadigd."
    exit 16
  fi

  ZipFolder=${TmpFolder}
  OdiProject=${ArgTarget}
  DebugLevel=5
  if [ -f "parameters/ODI_execution_order.txt" ]; then
    ## Parse the execution order line by line
    while read -r line; do
      odifolder="odi/${line}"
      Log "preparing for ODI process of folder $odifolder." >> $LogFile
      DoIvlOneOdiOEMM ${ZipFolder}/unzipped/${odifolder} $line $TmpFolder $DebugLevel
      cd ${ZipFolder}/unzipped
    done < "parameters/ODI_execution_order.txt"
  else
    if [ $DebugLevel -gt 3 ]; then
      echo "file ODI_execution_order.txt ontbreekt, dus GEEN ODI uitvoering."
      echo "file ODI_execution_order.txt ontbreekt, dus GEEN ODI uitvoering." >> $LogFile
    fi
  fi

  ## clean up TmpFolder
  rm -rf $TmpFolder


}

DoRTDeploy()
{
  SUBROUTINE=$0
  source ${ivlsh}/${ivldply_code_version}_ivldply_functions.sh

  ivldply_initialize
  Log "RT Deploy is started"

}

SetLogFile

LogIWSInfo

Initialise

ArgTarget="X"
ArgEnvironment="X"
ArgDirectory="X"
ArgFileName="X"
ArgTypeDeploy="X"
ArgTraceITticket="X"
ArgVersion="X"

## process command line options

while getopts :hT:E:D:F:A:N:V: option; do
  case $option
    in
    h) print_help;;
    T) ArgTarget=${OPTARG};;
    E) ArgEnvironment=${OPTARG};;
    D) ArgDirectory=${OPTARG};;
    F) ArgFileName=${OPTARG};;
    A) ArgTypeDeploy=${OPTARG};;
    N) ArgTraceITticket=${OPTARG};;
    V) ArgVersion=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done

ivldply_code_version="${ArgVersion}"

Log "checking target"
# Check ArgTarget value
if [ "${ArgTarget}" = "X" ]; then
  Log "Missing -T parameter. Use -h for help." 
  exit 1
  #Failure "bad options."
fi
if [ ! "${ArgTarget}" = "CIVL" ] && [ ! "${ArgTarget}" = "IVL" ]; then
  Log "Invalid value for -T parameter. Only CIVL or IVL are allowed. Use -h for help."
  exit 1
  #Failure "bad options."
fi

# Check ArgEnvironment value
if [ "${ArgEnvironment}" = "X" ]; then
  Log "Missing -E parameter. Use -h for help."
  exit 1
  #Failure "bad options."
fi
if [ ! "${ArgEnvironment}" = "ACC" ] && [ ! "${ArgEnvironment}" = "SIM" ] && [ ! "${ArgEnvironment}" = "PRD" ] && [ ! "${ArgEnvironment}" = "SIC" ]; then
  Log "Invalid value for -E parameter. Only ACC, SIM, PRD or SIC are allowed. Use -h for help."
  exit 1
  #Failure "bad options."
fi

# Check ArgDirectory value
if [ "${ArgDirectory}" = "X" ]; then
  Log "Missing -D parameter. Use -h for help."
  exit 1
  #Failure "bad options."
fi
if [ ! -d ${ArgDirectory} ]; then
  Log "Invalid value for -D parameter. Directory does not exist"
  exit 1
  #Failure "bad options."
fi

# can we write in the directory for log purposes?
touch ${ArgDirectory}/write_access_ok.log
RC=$?
if [ $RC -ne 0 ]; then
    Log "Directory access issue: Can not write in directory. (${ArgDirectory})"
    exit $RC
else
    rm -f ${ArgDirectory}/write_access_ok.log
fi

# Check File Name
if [ "${ArgFileName}" = "X" ]; then
    Log "Missing -F parameter. Use -h for help."
    exit 1
    #Failure "bad options."
fi
if [ ! -f ${ArgDirectory}/${ArgFileName} ]; then
    Log "File parameter: file does not exist. (${ArgDirectory}/${ArgFileName})"
    exit 1
fi

# Check type deploy
if [ "${ArgTypeDeploy}" = "X" ]; then
    Log "Missing -A parameter. Use -h for help."
    exit 1
    #Failure "bad options."
fi
if [ ! "${ArgTypeDeploy}" = "OEMM" ] && [ ! "${ArgTypeDeploy}" = "RT" ]; then
    Log "Invalid value for -T parameter. Eiter OEMM or RT can be used"
    exit 1
    #Failure "bad options."
fi

# Check the ticket number
if [ "${ArgTraceITticket}" = "X" ]; then
    Log "Missing -N parameter. Use -h for help."
    exit 1
    #Failure "bad options."
fi

ivldply_target="${ArgTarget}"
ivldply_env="${ArgEnvironment}"

ivloem_target="${ArgTarget}"
ivloem_env="${ArgEnvironment}"
# Load the values used in the code according the information given as parameter
LoadIniFiles

# Check if ivloem is active on this environment
if [ "${ivldply_active}" = "NO" ]; then
    Log "IVL OEMM for ${ivldply_target}/${ivldply_env} is inactive according to the properties files. Nothing to do."
    exit 0
fi

Log "Started with the deploy"

ivldply_directory="${ArgDirectory}"

# Set the log file to the directory itself
# Name: IVLDPLY_<datetime>_<run time specific info>.log
SetLocalLogFile

if [ "${ArgTypeDeploy}" == "OEMM" ]; then
    DoOEMMDeploy
fi

if [ "${ArgTypeDeploy}" == "RT" ]; then
    DoRTDeploy
fi

# copy new the local log file also to the main logfile as well
DoCopyLogFile

exit 0
