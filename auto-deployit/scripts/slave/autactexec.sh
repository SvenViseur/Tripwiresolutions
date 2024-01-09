#!/bin/bash

#### autactexec.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Jun/2020      # 1.0.0   # initial version
# dexa  # Jul/2020      # 1.1.0   # fetch ticket files if processing a ticket
# dexa  # Jul/2020      # 1.1.0   # TmpFld depends on TicketNr=0 or >0
# dexa  # Jul/2020      # 1.1.0   #   to allow multiple autact to run parallel
# dexa  # Jul/2020      # 1.1.1   # Error handling
# dexa  # Jul/2020      # 1.2.0   # Add TraceIT push ticket + PostAAFileHandling
# dexa  # Aug/2020      # 1.2.1   # Remove source of ivl_functions
# dexa  # Aug/2020      # 1.2.2   # If aa function call returns an aaError,
# dexa  # Aug/2020      # 1.2.2   #   then we should return and not exit
# dexa  # Aug/2020      # 1.2.3   # Extend aaErrorCode use to errors in AA file itself
# lekri # Jun/2021      # 1.2.4   # SSGT-105: op alle omgevingen de status updaten
#############################################################################
#

OrigFolder="$(pwd)"

ScriptName="autactexec.sh"
ScriptAAMajorVersion=1  ## this is used to check against .aa file versions
ScriptVersion="1.2.3"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"
source "${ScriptPath}/deploy_errorwarns.sh"
source "${ScriptPath}/deploy_slverrorwarns.sh"

DebugLevel=3
ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3
ArgExtraOpts=$4

echo "Script ${ScriptName} started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"
echo "  EXTRA OPTIONS = '${ArgExtraOpts}'"

## Call GetEnvData
GetEnvData

SshCommand="SSH_to_appl_srv"
ScpPutCommand="SCP_to_appl_srv"
SSHTargetUser=$UnixUserOnApplSrv

TheEnv=$ArgEnv
TheADC=$ArgAppl
TheTicketNr=$ArgTicketNr

ActionType="aa-exec"
## Determine a TmpFld based on the type of call:
## If TicketNr=0 then make a Tmp folder based on ADC
## If TicketNr>0 then make a Tmp folder based on ticket
if [ "$TheTicketNr" = "0" ]; then
  ## we are executing a non-ticket automatic action.
  MaakTmpApplEnvFolder
  cd ${TmpApplEnvFolder}
  TmpFld=$TmpApplEnvFolder
else
  ## We are executing a real ticket.
  MaakTmpTicketFolder
  cd ${TmpTicketFolder}
  TmpFld=$TmpTicketFolder
fi
## Erase the other Tmp folder variables
TmpTicketFolder="/Do_not_use_the_TmpTicketFolder_variable"
TmpApplEnvFolder="/Do_not_use_the_TmpApplEnvFolder_variable"

GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level
EchoDeployITSettings

Parse_ExtraOptsSvnTraceIT "$ArgExtraOpts"

### initialize some defaults
CurrSection="UNDEF"
AA_VRS=1
AA_REPL="NO"
AA_REPL_PSW="NO"
AA_TRACEIT_PUSH_TICKET="NO"
vaultPref="NONE"
LineCounter=0
## declare arrays for the ADC specific functions and a test entry
aaFctCounter=0
## The below lines can also serve as a template for a function.
((aaFctCounter++))
aaFctCode[$aaFctCounter]="DUMMY_TEST1"
aaFctCall[$aaFctCounter]="aaFctDummyTest1"

aaFctDummyTest1() {
  echo "This is Dummy Test 1 function."
}
### End of sample function and array entries

### Error management
aaErrorCode="0"
aaErrorMsg="OK"
aaFctError() {
aaErrorCode=$1
aaErrorMsg=$2
}

### Depending on the ADC, load a specific set of aaFct modules
### Each of these will register one or more functions in the aaFct arrays

if [ "$ArgAppl" = "CIVL_AA" ]; then
  source "${ScriptPath}/aafctodi.sh"
  vaultPref="NONE"
fi
if [ "$ArgAppl" = "IVL_AA" ]; then
  source "${ScriptPath}/aafctodi.sh"
  vaultPref="NONE"
fi

SwitchToSteps() {
## At this point, all settings should have been set and we can prepare for
## the execution of the steps
local OrigDataFolder=$DataFolder
LogLineDEBUG "PrepForSteps-1"
if [ "$AA_REPL" = "YES" ]; then
  ## We need to run the replace tool on all the files in $OrigFolder
  Replace_Tool_Defaults

  DataFolder="${TmpFld}/ReplData"
  RT_InFolder="$OrigFolder"
  RT_ScanFilter="*"
  RT_OutFolder="$DataFolder"
  RT_OutFolderEnc=""
  RT_Env=$TheEnv
  RT_ADC=$TheADC
  RT_Tmp=$TmpFld/tmp
  RT_Enc_SKIP=0
  ## Merk op dat ArgEnv naar lowercase wordt gezet voor de
  ## psafe3 file name.
  #RT_Vault="${SvnConfigDataFolder}/ivl_${ThePswEnv,,}.psafe3"
  #RT_VaultPSW="${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw"
  #RT_EncPSW="NOT_USED"
  rm -rf $RT_Tmp
  mkdir -p $RT_Tmp
  rm -rf $DataFolder
  mkdir -p $DataFolder
  Replace_Tool

  ## reduce chmod rechten op de output files
  chmod 600 $DataFolder/*

  ## Opkuisen tijdelijke files
  rm -rf $RT_Tmp
else
  DataFolder="$OrigDataFolder"
fi

LogLineDEBUG "PrepForSteps-2"
echo "We have in this setup access to $aaFctCounter functions."

LogLineDEBUG "PrepForSteps-3"
echo "Check for AA version compatibility"
if [ $AA_VRS -gt $ScriptAAMajorVersion ]; then
  ## We may have a problem here!
  ## the file being processed expects a higher version than our current
  ## code can provide. This may not work!!!
  echo "*** WARNING!! WARNING!! WARNING!! WARNING!! WARNING!! ***"
  echo "*** Using incorrect version of the $ScriptName script."
  echo "*** Asked in .aa file: $AA_VRS. Offered by this script: $ScriptAAMajorVersion"
  echo "*** The script will continue, but results may be unpredictable."
  echo "*** WARNING!! WARNING!! WARNING!! WARNING!! WARNING!! ***"
fi
LogLineDEBUG "PrepForSteps-4"
if [ "$AA_TRACEIT_PUSH_TICKET" = "YES" ]; then
  ## Try to move the ticket to IN UITVOERING
  LogLineDEBUG "Het TraceIT ticket wordt IN UITVOERING gezet ..."
  ArgStatus="${ArgEnv}_IN_UITVOERING"
  ArgErrMsg="${ArgEnv}_In_Uitvoering NIET gelukt!"
  TraceIT_UpdStatus
fi
}

PostAAFileHandling() {
## At the end of the whole AA file, this code gets executed
## The value of the aaErrorCode variable indicates whether there was an
## error during the processing of the AA file.

LogLineDEBUG "PostAAFileHandling-1"
if [ "$AA_TRACEIT_PUSH_TICKET" = "YES" ]; then
  ## Try to move the ticket to UITGEVOERD or UITGEVOERD MET FOUTEN
  if [ "$aaErrorCode" = "0" ]; then
    LogLineDEBUG "Het TraceIT ticket wordt UITGEVOERD gezet ..."
    ArgStatus="${ArgEnv}_UITGEVOERD"
    ArgErrMsg="${ArgEnv}_Uitgevoerd NIET gelukt!"
  else
    LogLineDEBUG "Het TraceIT ticket wordt UITGEVOERD MET FOUTEN gezet ..."
    ArgStatus="${ArgEnv}_UITGEVOERD_MET_FOUTEN"
    ArgErrMsg="${ArgEnv}_Uitgevoerd_met_fouten NIET gelukt!"
  fi
  TraceIT_UpdStatus
fi

}

ProcessOneLine() {
i=$1
((LineCounter=i+1))
CurLine=$2
local i=0
echo "Behandeling lijn $LineCounter: $CurLine"
## Skip blank lines
if [ "$CurLine" = "" ]; then
  return
fi
## if we are in error mode, we skip the processing
if [ ! "$aaErrorCode" = "0" ]; then
  return
fi
## find section blocks
if [ "${CurLine:0:1}" = "[" ]; then
  if [ "$CurLine" = "[STEPS]" ]; then
    CurrSection="STEPS"
    echo "Overschakelen naar sectie $CurrSection"
    SwitchToSteps
    return
  fi
  if [ "$CurLine" = "[SETTINGS]" ]; then
    CurrSection="SETTINGS"
    echo "Overschakelen naar sectie $CurrSection"
    return
  fi
  echo "Syntaxfout op lijn ${LineCounter}: Sectie-aanduiding niet herkend."
  aaFctError "AAEAAF001" "Syntaxfout op lijn ${LineCounter}: Sectie-aanduiding niet herkend."
  return
fi
## non-section line
if [ "$CurrSection" = "UNDEF" ]; then
  aaFctError "AAEAAF002" "Syntaxfout op lijn ${LineCounter}: data lijn gevonden die niet onder een sectie hoofding staat."
  return
fi
if [ "$CurrSection" = "SETTINGS" ]; then
  ## Process a SETTINGS line
  ## test if the line begins with AA_
  if [ ! "${CurLine:0:3}" = "AA_" ]; then
    aaFctError "AAEAAF003" "Syntaxfout op lijn ${LineCounter}: settings lijn gevonden die niet begint met AA_"
    return
  fi
  local varName="${CurLine%%'='*}"
  local varValue="${CurLine#*'='}"
  #echo "varName:$varName"
  #echo "varValue:$varValue"
  ## test if the line begins with AA_
  if [ "${varValue}" = "" ]; then
    aaFctError "AAEAAF004" "Syntaxfout op lijn ${LineCounter}: settings lijn gevonden die niet geen waarde bevat voor een variabele."
    return
  fi
  if [[ "${varValue}" == *";"* ]]; then
    aaFctError "AAEAAF005" "Syntaxfout op lijn ${LineCounter}: settings lijn gevonden die een waarde bevat waarin ';' voorkomt. Dat mag niet."
    return
  fi
  if [[ "${varValue}" == *" "* ]]; then
    aaFctError "AAEAAF006" "Syntaxfout op lijn ${LineCounter}: settings lijn gevonden die een spatie bevat. Dat mag niet."
    return
  fi
  if [ -z ${!varName+x} ]; then
    echo "Waarschuwing!!!! Op lijn ${LineCounter} staat een settings van een variabele die NIET GEKEND is."
  fi
  ## perform the assignment
  eval "${varName}=${varValue}"
  RC=$?
  if [ ${RC} -ne 0 ]; then
    aaFctError "AAEAAF008" "Settingsfout op lijn ${LineCounter}: De toewijzing kon niet gebeuren. Controleer de syntax."
    return
  fi

  return
fi
if [ "$CurrSection" = "STEPS" ]; then
  ## Process a STEPS line
  ## if we are in error mode, we skip the processing
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  ## the first keyword is the function to call
  lwords=( $CurLine )
  CmdToCall=${lwords[0]}
  aaFctParam1=${lwords[1]}
  aaFctParam2=${lwords[2]}
  echo "looking for the command $CmdToCall"
  FctToCall="UNDEF"
  for (( i=1 ; i<=$(( $aaFctCounter )); i++))
    do
      if [ "$CmdToCall" = "${aaFctCode[$i]}" ]; then
        FctToCall="${aaFctCall[$i]}"
        FctParamCnt="${aaFctPCnt[$i]}"
      fi
    done
  if [ "$FctToCall" = "UNDEF" ]; then
    aaFctError "AAEAAF007" "Uitvoeringsfout op lijn ${LineCounter}: er wordt een functie opgeroepen (${CmdToCall}) die binnen deze ADC niet gekend is."
    return
  fi
  echo "Uitvoering van functie $FctToCall zal gevraagd worden ..."
  eval "$FctToCall"
  if [ "$aaErrorCode" = "0" ]; then
    echo "Uitvoering van functie $FctToCall is goed afgelopen."
    return
  else
    echo "Uitvoering van functie $FctToCall is gefaald."
    echo "De error code is: $aaErrorCode"
    echo "De error msg is : $aaErrorMsg"
    echo "Uitvoering van de .aa file wordt onderbroken."
    return
  fi
fi

}

ProcessAAFile() {
echo "Beginnen met behandelen van bestand: $1"
readarray -t AALines < $1
AALineCount=${#AALines[@]}
echo "AALineCount : $AALineCount"
local i=0
for (( i=0; i<$AALineCount; i++ )); do
  line=${AALines[$i]}
  ProcessOneLine $i "$line"
done
PostAAFileHandling

}


LocateSingleFile() {
## This function allows to search for a specific file within the starting folder ($DataFolder)
## It searches first in the root, then checks presence of a template folder and then the
## generated/<env> folder is checked. This allows files from the replace process to be
## found.
## Input:    $1                  : the filename filter to use (eg. *.aa or TI123456.properties)
##
## Output    $TheSingleFile      : the resulting filename in a fully qualified format.
local NameFilter=$1
local countF=0
cd $DataFolder
local FullPath=$DataFolder
countF=$(find . -maxdepth 1 -type f -name "$NameFilter" | wc -l)
if [ $countF -gt 1 ]; then
  aaFctError "AAELSF006" "Automatische Actie vindt meer dan 1 $NameFilter file. Dat is niet toegelaten."
  return
fi
if [ $countF -eq 1 ]; then
  LocalFile=$(find . -maxdepth 1  -type f -name "$NameFilter")
  TheSingleFile="$FullPath/$LocalFile"
  return
fi
## no $NameFilder file in the current folder. Check the template folder
ls -d template
RC=$?
if [ $RC -ne 0 ]; then
  aaFctError "AAELSF001" "Automatische Actie vindt geen $NameFilter file en er is geen template folder."
  return
fi
## there is a template folder. Check to find the generated/<env> folder
ls -d generated
RC=$?
if [ $RC -ne 0 ]; then
  aaFctError "AAELSF002" "Automatische Actie vindt geen $NameFilter file, er is een template folder maar geen generated folder."
  return
fi
FullPath="${DataFolder}/generated"
cd $FullPath
ls -d $ArgEnv
RC=$?
if [ $RC -ne 0 ]; then
  aaFctError "AAELSF003" "Automatische Actie vindt geen $NameFilter file, er is een template en generated folder maar geen generated/$ArgEnv folder."
  return
fi
FullPath="${DataFolder}/generated/${ArgEnv}"
cd $FullPath
countF=$(find . -maxdepth 1 -type f -name "$NameFilter" | wc -l)
if [ $countF -gt 1 ]; then
  aaFctError "AAELSF004" "Automatische Actie vindt meer dan 1 $NameFilter file in de generated/$ArgEnv folder. Dat is niet toegelaten."
  return
fi
if [ $countF -eq 1 ]; then
  LocalFile=$(find . -maxdepth 1  -type f -name "$NameFilter")
  TheSingleFile="$FullPath/$LocalFile"
  return
fi
aaFctError "AAELSF005" "Automatische Actie vindt geen $NameFilter file, ook niet in de generated/$ArgEnv folder."
return
}

LocateAAFile() {
  LocateSingleFile "*.aa"
  TheAAFile=$TheSingleFile
}

## main processing
if [ "$TheTicketNr" = "0" ]; then
  ## we are executing a non-ticket automatic action. Hence, the input files
  ## must be in the local folder named "$OrigFolder".
  DataFolder=$OrigFolder
else
  ## We are executing a real ticket. We must fetch the files from the ticket
  ## before we execute them.
  cd ${TmpFld}
  ## Download ticket materiaal
  Handover_Download_Local
  # Check the contents of the deleted and downloaded files
  HandoverDeletedList="${TmpFld}/TI${ArgTicketNr}-deleted.txt"
  HandoverDownloadedList="${TmpFld}/TI${ArgTicketNr}-downloaded.txt"
  line1=$(cat ${HandoverDownloadedList} ${HandoverDeletedList} | head -n 1)
  echo "line1 = " ${line1}
  ## expected format: OK      <adc-folder>/...
  ## remove the "OK" + tab section
  line1=${line1:3}
  echo "line1 (stripped) = " ${line1}
  firstpart=${line1%%"/"*}
  restpart=${line1:${#firstpart}+1}
  secondpart=${restpart%%"/"*}
  LogLineDEBUG "first folder part is: ${firstpart}"
  LogLineDEBUG "second folder part is: ${secondpart}"
  # Save the ADC with capitals.
  DerivedADC=${firstpart^^}
  ## Compare the requested ADC with the one derived from the HODL file
  if [ "$ArgAppl" = "$DerivedADC" ]; then
    LogLineINFO "De ADC van het ticket komt overeen met de ADC van deze Jenkins job."
  else
    echo "ERROR: Dit ticket bevat files die, op basis van hun locatie, niet tot deze ADC behoren. Deploy kan niet verdergaan."
    echo "Deploy voor ADC=${ArgAppl}. Files in ticket zouden zijn voor ADC=${DerivedADC}."
    exit 16
  fi
  ## Set the DataFolder
  DataFolder="${TmpFld}/${firstpart}"
  cd $DataFolder
fi
LocateAAFile
if [ "$aaErrorCode" = "0" ]; then
  echo "Automatische actie bestand gevonden: $TheAAFile"
  ProcessAAFile $TheAAFile
else
  PostAAFileHandling
fi
if [ ! "$aaErrorCode" = "0" ]; then
  echo "Er was een probleem met de uitvoering van deze Automatische Actie."
  echo "Error code: $aaErrorCode"
  echo "Error msg : $aaErrorMsg"
  exit 16
else
  echo "Behandeling van de AA file is foutloos gebeurd."
fi

echo "Script ${ScriptName} ended."
