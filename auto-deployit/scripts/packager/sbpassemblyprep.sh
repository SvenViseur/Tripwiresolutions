#!/bin/bash

#### sbprmmprep.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script can only work for tickets of the ADC
# "SBP Assembly Configuratie". It reads the template files and generates
# the related environment specific files. It only serves to
# substitute passwords.
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
#       #             #
# Jaden # 01/03/2018  # Skip images-folder for dos2unix-step
#       #             # under jboss-directory
#       #             #   Jira: OBO-3965
# Jaden # 24/04/2018  # Skip additional folders for dos2unix-step
#       #             #   Jira: OBO-3966 OBO-3967
# dexa  # 14/05/2018  # Adapt process_one_file to accept AC5/SI2
#       #             # type tickets which have _xxp_ files
#       #             # instead of _xxx_ files
# dexa  # 23/03/2020  # aanpassingen aan lijst met _xxx_ files
# lekri # 02/06/2021  # SSGT-65: openssl key hashing -> sha256
#       #             #
#################################################################
#

ScriptName="sbpassemblyprep.sh"
ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ScriptPath}/deploy_initial_settings.sh"
source "${ScriptPath}/deploy_global_settings.sh"
source "${ScriptPath}/deploy_global_functions.sh"
source "${ScriptPath}/deploy_replace_tool.sh"
source "${ScriptPath}/deploy_specific_settings.sh"

DebugLevel=3
ArgAppl=$1
ArgTicketNr=$2
ArgEnv=$3

echo "Script" ${ScriptName}  "started."
echo "Options are:"
echo "  APPL = '${ArgAppl}'"
echo "  TICKETNR = '${ArgTicketNr}'"
echo "  ENV = '${ArgEnv}'"

TmpTicketFolder="/data/deploy-it/tmp/sbp/T${ArgTicketNr}"

GetEnvData
##     output variables : $TheBof, $TheOpl (The BOF server and the Oplevering_XXX folder to use)
##                        $ThePswEnv (The password environment: AC5 -> ACC)


## Clean up local traces of previous runs of this same ticket
rm -rf ${TmpTicketFolder}
mkdir -p  ${TmpTicketFolder}
cd ${TmpTicketFolder}

TmpFld=$TmpTicketFolder
TheEnv=$ArgEnv
TheADC=$ArgAppl

## GetDynOplOmg:
## In: ArgTicketNr, TmpFld    Out: TheOpl
GetDynOplOmg

## Get default settings based on the ENV and ADC
GetDeployITSettings
DebugLevel=$DeployIT_Debug_Level
Replace_Tool_Defaults
EchoDeployITSettings
LoggingBaseFolder="${ConfigNfsFolderRepllogOnServer}/target_${ArgEnv}/"
mkdir -p $LoggingBaseFolder

Handover_Download_Local

# Check the contents of the deleted and downloaded files
HandoverDeletedList="${TmpTicketFolder}/TI${ArgTicketNr}-deleted.txt"
HandoverDownloadedList="${TmpTicketFolder}/TI${ArgTicketNr}-downloaded.txt"

# first filter the downloaded.txt file for these files
# deployinfo files
# info files that go with tar.gz files
# previously generated and uploaded environment specific files
FilterStrings="deployinfo
gz.info
.pdf
generated
opleverinstructies"
grep -v -F "${FilterStrings}" ${HandoverDownloadedList} > ${TmpTicketFolder}/handover-downloaded-filtered.txt

# Test 2: ensure downloaded.txt is NOT empty
if [ ! -s ${TmpTicketFolder}/handover-downloaded-filtered.txt ];
then
  echo "ERROR: Ticket contains no downloadable files, so there is nothing to deploy."
  exit 16
fi
# Test 3: ensure downloaded.txt only contains lines for config.PLACEHOLDERS
if [ $(grep -v assembling ${TmpTicketFolder}/handover-downloaded-filtered.txt | wc -l) -ne 0 ];
then
  echo "ERROR: Ticket contains other files than assembling files. This is not supported for SBP Assembly Configuratie type applications."
  exit 16
fi

### Vind de sbp_environment and SBP_3Token value
mkdir "${TmpTicketFolder}/TmpPlh"
cd "${TmpTicketFolder}/TmpPlh"
TmpPlhFile="${TmpTicketFolder}/TmpPlh/File.txt"
cat >${TmpPlhFile} << EOL
SBP_Env3_token="@@SBP_Env3_token#@"
SBP_ENVIRONMENT="@@SBP_ENVIRONMENT#@"
sbp_environment="@@sbp_environment#@"
EOL

## Prepare for a Replace_Tool call
RT_InFolder=${TmpTicketFolder}/TmpPlh
RT_ScanFilter="*"
RT_OutFolder=${TmpTicketFolder}/TmpPlhRepl
mkdir -p $RT_OutFolder
RT_OutFolderEnc=""
RT_Env=$ArgEnv
RT_ADC="SBP"
RT_Tmp=$TmpTicketFolder
RT_Dos2Unix=1

Replace_Tool

source ${TmpTicketFolder}/TmpPlhRepl/File.txt
TheSbpEnv=${sbp_environment}
LC_SBP_Env3_token=${SBP_Env3_token,,}
echo "SBP omgevingsnaam is: $TheSbpEnv"
echo "LC_SBP_Env3_token is: $LC_SBP_Env3_token"

#### determine where unzip program is located
unzipcmd="unzip"
which unzip
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "WARNING: unzip command not found. trying deploy-it bin folder."
    if [ -e "/data/deploy-it/bin/unzip" ]; then
      unzipcmd="/data/deploy-it/bin/unzip"
    else
      echo "ERROR: unzip command not found. Also not found in deploy-it bin folder."
      exit 16
    fi
  fi

TmpOutputFolder="${TmpTicketFolder}/TmpOutput"

##### Function: process 1 tar.gz file ######
process_one_targz() {
  TheTarGzPath="$1"
  TheTarGzFile="$2"
  OutTarGzPath="$3"
  LogLineDEBUG "Path=$TheTarGzPath; FlatFile=$TheTarGzFile; OutPath=$OutTarGzPath;"
  ### change TheTarGzFile to accept Projectstraat files (xxx should match the $LC_SBP_Env3_token)
  TheTarGzFile=${TheTarGzFile/xxx/$LC_SBP_Env3_token}
  if [ -e "${TheTarGzPath}/${TheTarGzFile}" ]; then
    echo "Processing $TheTarGzFile"
  else
    ## the file to process is not there
    return
  fi
  TmpUntar=${TmpTicketFolder}/tar

  mkdir ${TmpUntar}
  cd ${TmpUntar}
  tar -xzf ${TheTarGzPath}/${TheTarGzFile}
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "tar command to extract the file ${TheTarGzFile} failed."
    exit 16
  fi
  ## remove eventuele lst files
  rm -f *.zip.lst
  ls
  zipfilename=$(ls)
  TmpUnzip=${TmpTicketFolder}/zip
  mkdir ${TmpUnzip}
  $unzipcmd $zipfilename -d ${TmpUnzip}
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "unzip command to extract the file ${zipfilename} failed."
    exit 16
  fi
  ### SBP specific code om bepaalde files NIET te parsen
  ### want ze bevatten @@ strings die GEEN placeholder zijn.
  if [ -d "${TmpUnzip}/AGREM/migration" ]; then
    ### Folder wegzetten ZONDER parsing
    mv "${TmpUnzip}/AGREM/migration" "${TmpTicketFolder}/DoNotReplace_AGREM_migration"
    LogLineDEBUG "mv command performed for folder ${TmpUnzip}/AGREM/migration. RC=$?"
  fi

  ## We also need to exclude the some additional directories
  ## Before we can test if the images-directory exists we need to know the exact name
  ## Jira: http://jira.argenta.be:8080/browse/OBO-3965
  if [ -d "${TmpUnzip}/jboss-eap/standalone/deployments/env-custom.war/images" ]; then
    mv "${TmpUnzip}/jboss-eap/standalone/deployments/env-custom.war/images" "${TmpTicketFolder}/DoNotReplace_JBOSS_Images"
    LogLineDEBUG "mv command performed for folder ${TmpUnzip}/jboss-eap/standalone/deployments/env-custom.war/images. RC=$?"
  fi

  ### ls ${TmpUnzip}
  TmpUnzipOutPub=${TmpTicketFolder}/zipoutPub
  TmpUnzipOutSecret=${TmpTicketFolder}/zipoutSecret
  mkdir ${TmpUnzipOutPub}
  mkdir ${TmpUnzipOutSecret}
  ### Now run a replace run on that resulting folder
  ## Prepare for a Replace_Tool call
  RT_InFolder="${TmpUnzip}"
  RT_ScanFilter="*"
  RT_OutFolder="${TmpUnzipOutPub}"
  mkdir -p $RT_OutFolder
  RT_OutFolderEnc="${TmpUnzipOutSecret}"
  mkdir ${RT_OutFolderEnc}
  RT_Env=$ArgEnv
  RT_ADC="SBP"
  RT_Tmp=$TmpTicketFolder
  RT_Dos2Unix=1
  RT_Vault="${SvnConfigDataFolder}/sbp_${ThePswEnv,,}.psafe3"
  RT_VaultPSW="${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw"
  RT_EncPSW="NOT_USED"
  RT_Enc_SKIP=1
  RT_KeepCHMOD=1
  RT_HiddenFiles=1
  RT_TicketNr=${ArgTicketNr}
  RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

  Replace_Tool

  ### SBP: terugzetten van geskipte folder in beide targets
  if [ -d "${TmpTicketFolder}/DoNotReplace_AGREM_migration" ]; then
    mkdir -p "${RT_OutFolder}/AGREM/migration"
    cp -a "${TmpTicketFolder}/DoNotReplace_AGREM_migration/"* "${RT_OutFolder}/AGREM/migration/"
    RC=$?
      if [ $RC -ne 0 ]; then
        echo "cp command to restore the AGREM migration folder failed."
        exit 16
      fi

    mkdir -p "${RT_OutFolderEnc}/AGREM/migration"
    cp -a "${TmpTicketFolder}/DoNotReplace_AGREM_migration/"* "${RT_OutFolderEnc}/AGREM/migration/"
    RC=$?
      if [ $RC -ne 0 ]; then
        echo "cp command to restore the AGREM migration folder encrypted  failed."
        exit 16
      fi
    rm -rf "${TmpTicketFolder}/DoNotReplace_AGREM_migration"
  fi
  ## SPB: Terugzetten van geskipte image-folder.
  ## Jira: http://jira.argenta.be:8080/browse/OBO-3965
  if [ -d "${TmpTicketFolder}/DoNotReplace_JBOSS_Images" ]; then
    mkdir -p "${RT_OutFolder}/jboss-eap/standalone/deployments/env-custom.war/images"
    cp -a "${TmpTicketFolder}/DoNotReplace_JBOSS_Images/"* "${RT_OutFolder}/jboss-eap/standalone/deployments/env-custom.war/images/"
    RC=$?
      if [ $RC -ne 0 ]; then
        echo "cp command to restore the images folder failed."
        exit 16
      fi
    mkdir -p "${RT_OutFolderEnc}/jboss-eap/standalone/deployments/env-custom.war/images"
    cp -a "${TmpTicketFolder}/DoNotReplace_JBOSS_Images/"* "${RT_OutFolderEnc}/jboss-eap/standalone/deployments/env-custom.war/images/"
    RC=$?
      if [ $RC -ne 0 ]; then
        echo "cp command to restore the images folder encrypted failed."
        exit 16
      fi
    rm -rf "${TmpTicketFolder}/DoNotReplace_JBOSS_Images"
  fi

  TmpRezipPub=${TmpTicketFolder}/rezippub
  mkdir ${TmpRezipPub}
  pubzipfilename="${TmpRezipPub}/${zipfilename}"
  cd ${RT_OutFolder}
  zip $pubzipfilename -r *
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "zip command to build the file ${pubzipfilename} failed."
    exit 16
  fi
  ls -l $pubzipfilename

  TmpRezipSecret=${TmpTicketFolder}/rezipsecret
  mkdir ${TmpRezipSecret}
  secretzipfilename="${TmpRezipSecret}/${zipfilename}"
  cd ${RT_OutFolderEnc}
  zip $secretzipfilename -r *
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "zip command to build the file ${secretzipfilename} failed."
    exit 16
  fi
  ls -l $secretzipfilename

  PubTarGzFile="${TheTarGzFile/_${LC_SBP_Env3_token}_/_${TheSbpEnv}_}"
  cd ${TmpRezipPub}
  tar -czf ${OutTarGzPath}/${PubTarGzFile} ${zipfilename}
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "tar command to create the file ${PubTarGzFile} failed."
    exit 16
  fi

  SecretTarGzFile="${TheTarGzFile/_${LC_SBP_Env3_token}_/_${TheSbpEnv}_}.enc"
  TempTarGzFile="${TmpTicketFolder}/secret.temp.tar.gz"
  cd ${TmpRezipSecret}
  tar -czf ${TempTarGzFile} ${zipfilename}
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "tar command to create the file ${TempTarGzFile} failed."
    exit 16
  fi
  openssl enc -in $TempTarGzFile -out ${OutTarGzPath}/${SecretTarGzFile} -aes256 -md sha256 -pass file:${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "openssl command to encrypt the file ${TempTarGzFile} to ${SecretTarGzFile} failed."
    exit 16
  fi

  ##clean up
  rm ${TempTarGzFile}
  rm -rf ${TmpUntar}
  rm -rf ${TmpUnzip}
  rm -rf ${TmpUnzipOutPub}
  rm -rf ${TmpUnzipOutSecret}
  rm -rf ${TmpRezipSecret}
  rm -rf ${TmpRezipPub}

}

##### Function: process 1 flat file ######
process_one_file() {
  TheTarGzPath="$1"
  TheFlatFile="$2"
  OutTarGzPath="$3"
  ### change TheFlatFile to accept Projectstraat files (xxx should match the $LC_SBP_Env3_token)
  LogLineDEBUG "Path=$TheTarGzPath; FlatFile=$TheFlatFile; OutPath=$OutTarGzPath;"
  TheFlatFile=${TheFlatFile/xxx/$LC_SBP_Env3_token}
  if [ -e "${TheTarGzPath}/${TheFlatFile}" ]; then
    echo "Processing $TheFlatFile"
  else
    ## the file to process is not there
    return
  fi
  TmpToParse=${TmpTicketFolder}/toparse
  mkdir ${TmpToParse}
  cd ${TmpToParse}
  cp "${TheTarGzPath}/${TheFlatFile}" "${TmpToParse}/${TheFlatFile}"
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "cp command of the file ${TheFlatFile} failed."
    exit 16
  fi

  ### ls ${TmpUnzip}
  TmpParsedPub=${TmpTicketFolder}/ParsedPub
  TmpParsedSecret=${TmpTicketFolder}/ParsedSecret
  ### Now run a replace run on that resulting folder
  ## Prepare for a Replace_Tool call
  RT_InFolder="${TmpToParse}"
  RT_ScanFilter="*"
  RT_OutFolder="${TmpParsedPub}"
  mkdir -p ${RT_OutFolder}
  RT_OutFolderEnc="${TmpParsedSecret}"
  mkdir -p ${RT_OutFolderEnc}
  RT_Env=$ArgEnv
  RT_ADC="SBP"
  RT_Tmp=$TmpTicketFolder
  RT_Dos2Unix=1
  RT_Vault="${SvnConfigDataFolder}/sbp_${ThePswEnv,,}.psafe3"
  RT_VaultPSW="${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw"
  RT_EncPSW="NOT_USED"
  RT_Enc_SKIP=1
  RT_KeepCHMOD=1
  RT_HiddenFiles=1
  RT_TicketNr=${ArgTicketNr}
  RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

  Replace_Tool

  PubFlatFile="${TheFlatFile/.${LC_SBP_Env3_token}-/.${TheSbpEnv}-}"
  cp "${RT_OutFolder}/${TheFlatFile}" "${OutTarGzPath}/${PubFlatFile}"
  SecretFlatFile="${TheFlatFile/.${LC_SBP_Env3_token}-/.${TheSbpEnv}-}.enc"
  openssl enc -in ${RT_OutFolderEnc}/${TheFlatFile} -out ${OutTarGzPath}/${SecretFlatFile} -aes256 -md sha256 -pass file:${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "openssl command to encrypt the file ${TheFlatFile} to ${SecretFlatFile} failed."
    exit 16
  fi

  ##clean up
  rm -rf ${TmpToParse}
  rm -rf ${TmpParsedPub}
  rm -rf ${TmpParsedSecret}

}

mkdir "${TmpOutputFolder}"
cd "${TmpTicketFolder}/sbp_assembly_configuratie"

SrcTarGz="${TmpTicketFolder}/sbp_assembly_configuratie"
TgtTarGz="${TmpTicketFolder}/files_out"
mkdir $TgtTarGz
##### Important note about the below list of files!
##### The file names may/must contain xxx where Sopra puts the environment name
##### In Hoofdstraat, this will remain xxx in the input file, and become acc/sim/prd in the output
##### However, in Projectstraat, the input file will not be xxx, but rather xxp (or whatever the
##### SBP team decides using the ConfigIT variable SBP_Env3_token). The output will be the target
##### environment like AC5 or SI2.
process_one_targz "${SrcTarGz}" "assembling.config_xxx_agrem_bas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_agrem_db.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_arm7_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_arm_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_cbs_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_cbs_arm_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_cbs_cw_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_wks7_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_chwks_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_epara_bas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_epara_db.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_epara7_bas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_demng_db.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_demng_bas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_colle_fas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_colle_db.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_targz "${SrcTarGz}" "assembling.config_xxx_colle_bas.zip.PLACEHOLDERS.tar.gz" "$TgtTarGz"
process_one_file "${SrcTarGz}" "assembling.xxx-a-mb-deploy.cfg.PLACEHOLDERS" "$TgtTarGz"

### uploaden naar SVN

Svn_set_options
OplFolder="sbp_assembly_configuratie"
Svn_co

cd sbp_assembly_configuratie
mkdir -p generated
cd generated
mkdir -p $ArgEnv
cd $ArgEnv

# Copy the generated material

cp $TgtTarGz/* .
cd ../..

Svn_add

svn status

# Commit de wijzigingen

Svn_commit

# Handover tool oproepen voor Ripple up

Handover_RippleUp

### Clean up tmp files
if [ ${DeployIT_Keep_Temporary_Files} -ne 1 ]; then
  rm -rf ${TmpTicketFolder}
fi

echo "Script" ${ScriptName}  "ended."

exit

