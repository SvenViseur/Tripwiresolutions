#!/bin/bash

#### sbpconfigprep.sh script
# This script is to be run from a Jenkins AutoDeploy job.
#
# This script can only work for tickets of the ADC
# "SBP configuratie". It reads the template files and generates
# the related environment specific files
#
# Command line options:
#     APPL		: The ADC name being deployed
#     TICKETNR		: The ticket number being deployed
#     ENV		: The target environment
#
#################################################################
# Change history
#################################################################
# dexa  # 29/06/2016  # gebruik deploy_replace_tool en
#       #             # global_functions handover_download
# dexa  # 13/09/2016  # gebruik omgevingspecifieke credentials
# dexa  # 22/09/2016  # grep strenger maken voor @@
# dexa  # 19/10/2016  # toev machine-specifieke values voor SI2
# dexa  # 15/11/2016  # gebruik call naar Svn_co om checkout te doen
#       #             # dit is nodig om GetDynOplOmg en TraceIT ACC
#       #             # mogelijk te maken
# dexa  # 11/04/2017  # vervangen van XXX door $SBP_Env3_token op
#       #             # basis van placeholder. Input filename ook
#       #             # op basis van placeholder.
# dexa  # 05/05/2017  # Filter voor toegelaten files breder
# dexa  # 05/05/2017  # Target folder in de tar.gz moet niet
#       #             # AR2${ArgEnv} zijn, maar AR2${SBP_ENVIRONMENT}
# dexa  # 07/07/2017  # ONDERSTEUN-1529: log van replace schrijven
# dexa  # 29/07/2017  # OBO-2432: aanpassen waarden
# dexa  # 14/03/2018  # Aantal BAS instances SIM: 2 -> 6
# dexa  # 31/03/2018  # Aantal BAS instances PRD: 2 -> 6
# dexa  # 18/09/2018  # Toev VAL
# dexa  # 08/11/2018  # Verw. HOST_BAS_LB, toev TSD_CONTAINER_AMQ
# dexa  # 18/02/2019  # Aanp server-spec waarden TSD_CONT...
# dexa  # 01/04/2019  # Toev server-spec MCH_SBP_HA_MODE
# dexa  # 15/04/2019  # MchReplaceString combineert de replace voor
#       #             # public en secret zodat die hetzelfde zijn.
# dexa  # 23/03/2020  # nieuwe servernamen in MCH deel
#       #             # verwijderen AC5/SI2 MCH settings
# lekri # 02/06/2021  # SSGT-65: openssl key hashing -> sha256
#       #             #
#################################################################
#

ScriptName="sbpconfigprep.sh"
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

#SshCommand="/data/deploy-it/scripts/ssh/ssh_srv_toptoa.sh"
#ScpPutCommand="/data/deploy-it/scripts/ssh/scp_srv_toptoa_put.sh"
#ScpGetCommand="/data/deploy-it/scripts/ssh/scp_srv_toptoa_get.sh"

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

export

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

## Determine value of SBP_Template_File and SBP_Env3_token
mkdir "${TmpTicketFolder}/TmpPlh"
cd "${TmpTicketFolder}/TmpPlh"
TmpPlhFile="${TmpTicketFolder}/TmpPlh/File.txt"
cat >${TmpPlhFile} << EOL
SBP_Template_File="@@SBP_Template_File#@"
SBP_Env3_token="@@SBP_Env3_token#@"
SBP_ENVIRONMENT="@@SBP_ENVIRONMENT#@"
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

echo "SBP verwachte template file is: $SBP_Template_File"
echo "SBP verwachte 3 pos token in tar file is: $SBP_Env3_token"
echo "SBP naam van de gegenereerde files is: $SBP_ENVIRONMENT"

cd ${TmpTicketFolder}
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
generated
opleverinstructies
.pdf
config.ACC
config.SIM
config.PRD"
grep -v -F "${FilterStrings}" ${HandoverDownloadedList} > ${TmpTicketFolder}/handover-downloaded-filtered.txt

# Test 2: ensure downloaded.txt is NOT empty
if [ ! -s ${TmpTicketFolder}/handover-downloaded-filtered.txt ];
then
  echo "ERROR: Ticket contains no downloadable files, so there is nothing to deploy."
  exit 16
fi
# Test 3: ensure downloaded.txt only contains lines for the expected $SBP_Template_File
if [ $(grep -v $SBP_Template_File ${TmpTicketFolder}/handover-downloaded-filtered.txt | wc -l) -ne 0 ];
then
  echo "ERROR: Ticket contains other files than ${SBP_Template_File}. This is not supported for sbp type applications."
  exit 16
fi

##### SBP specific processing: untar the file #######

TmpUntar=${TmpTicketFolder}/tar

mkdir ${TmpUntar}
cd ${TmpUntar}
tar -xzf ${TmpTicketFolder}/sbp_configuratie/$SBP_Template_File

### Test existence of AR2XXX folder (with XXX specified by $SBP_Env3_token)

if [ ! -d ${TmpUntar}/AR2$SBP_Env3_token ]; then
  echo "Tar file does not contain the expected AR2$SBP_Env3_token folder. Maybe check the value of the SBP_Env3_token placeholder for this environment."
  exit 16
fi

### Make the subfolders for the 4 sections, BAS, FAS, SF and V2

mkdir ${TmpUntar}/BAS
cd ${TmpUntar}/BAS
tar -xf ${TmpUntar}/AR2${SBP_Env3_token}/${SBP_Env3_token}_BAS.tar
mkdir ${TmpUntar}/FAS
cd ${TmpUntar}/FAS
tar -xf ${TmpUntar}/AR2${SBP_Env3_token}/${SBP_Env3_token}_FAS.tar
mkdir ${TmpUntar}/SF
cd ${TmpUntar}/SF
tar -xf ${TmpUntar}/AR2${SBP_Env3_token}/${SBP_Env3_token}_SF.tar
mkdir ${TmpUntar}/V2
cd ${TmpUntar}/V2
tar -xf ${TmpUntar}/AR2${SBP_Env3_token}/${SBP_Env3_token}_V2.tar

### Remove the AR2XXX folder (we have the tar.gz anyway)
rm -rf ${TmpUntar}/AR2${SBP_Env3_token}

## Add a script file to the file set, to ensure replacing occurs for it
cat >${TmpUntar}/mv_script.sh << EOL
mv BAS/aliases-${SBP_Env3_token,,}.conf BAS/aliases-@@sbp_environment#@.conf
mv V2/${SBP_Env3_token,,} V2/@@sbp_environment#@
mv V2/glo/x_asslogs V2/glo/@@sbp_enviro#@_asslogs
mv V2/glo/x_profile-ksh V2/glo/@@sbp_enviro#@_profile-ksh
mv V2/glo/x_tftseconfig V2/glo/@@sbp_enviro#@_tftseconfig
EOL

############### Call the replace tool #############
Replace_Tool_Defaults

RT_InFolder=${TmpUntar}
RT_ScanFilter="*"
RT_OutFolder=${TmpTicketFolder}/ReplacedPub
mkdir ${RT_OutFolder}
RT_OutFolderEnc=${TmpTicketFolder}/ReplacedSecret
mkdir ${RT_OutFolderEnc}
RT_Env=${ArgEnv}
RT_ADC="SBP"
## Merk op dat ArgEnv naar lowercase wordt gezet voor de
## psafe3 file name.
RT_Vault="${SvnConfigDataFolder}/sbp_${ThePswEnv,,}.psafe3"
RT_VaultPSW="${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw"
RT_EncPSW="NOT_USED"
RT_Tmp=${TmpTicketFolder}/Tmp
mkdir ${RT_Tmp}
RT_Enc_SKIP=1
RT_KeepCHMOD=1
RT_TicketNr=${ArgTicketNr}
RT_LogUsage=${LoggingBaseFolder}/TI${ArgTicketNr}.log

Replace_Tool

cd ${RT_OutFolder}

dos2unix -o mv_script.sh
source mv_script.sh
rm mv_script.sh

cd ${RT_OutFolderEnc}

dos2unix -o mv_script.sh
source mv_script.sh
rm mv_script.sh

#### Test op overblijvende markers die duiden op placeholders

echo "grep om resterende @@ markers te vinden"
grep -r "@@" * | grep -v "@@=MCH"

export

## Machine-specifieke processing voor SBP

MakeMchTar() {
MchSetName=$1
MchBaseName=$2
MchHostFas=$3
MchHostBas=$4
MchHostBes=$5
MchHostBesIP=$6
MchHostBesLB=$7
MchHostBasLB=$8
MchTsdCntAmq1Min=$9
MchTsdCntAmq2Min=${10}
MchSbpHaMode=${11}
mkdir -p ${TmpTicketFolder}/Mch/${MchSetName}
## hieronder staat de replace string die gebruikt zal worden, zowel voor de Public
## als voor de secret version.
MchReplaceString="s/@=MCH_HOST_FAS=@/${MchHostFas}/g; s/@=MCH_HOST_BAS=@/${MchHostBas}/g; "
MchReplaceString+="s/@=MCH_HOST_BES=@/${MchHostBes}/g; s/@=MCH_HOST_BES_IPADDRESS=@/${MchHostBesIP}/g; "
MchReplaceString+="s/@=MCH_HOST_BES_LB=@/${MchHostBesLB}/g; s/@=MCH_HOST_BAS_LB=@/${MchHostBasLB}/g;"
MchReplaceString+="s/@=MCH_TSD_CONTAINER_AMQ1_MIN=@/${MchTsdCntAmq1Min}/g; s/@=MCH_TSD_CONTAINER_AMQ2_MIN=@/${MchTsdCntAmq2Min}/g; "
MchReplaceString+="s/@=MCH_SBP_HA_MODE=@/${MchSbpHaMode}/g"

## Process Public version
 cp -a ${RT_OutFolder} ${TmpTicketFolder}/Mch/${MchSetName}/Pub
cd ${TmpTicketFolder}/Mch/${MchSetName}/Pub
sed -i "${MchReplaceString}" $(find * -type f)
#### Test op overblijvende markers die duiden op machine-specifieke settings
echo "grep om resterende @=MCH markers te vinden"
grep -r "@=MCH" *
## Aanmaak tar
mkdir tar
cd $MchBaseName
tar -cf ../tar/${SBP_ENVIRONMENT}_${MchSetName}.tar *
cd ..

## Process Secret version
cp -a ${RT_OutFolderEnc} ${TmpTicketFolder}/Mch/${MchSetName}/Scrt
cd ${TmpTicketFolder}/Mch/${MchSetName}/Scrt
sed -i "${MchReplaceString}" $(find * -type f)
## Aanmaak tar
mkdir tar
cd $MchBaseName
tar -cf ../tar/${SBP_ENVIRONMENT}_${MchSetName}.tar *
cd ..
}

MakeTarGz() {

  mkdir ${TmpTicketFolder}/targzpub
  cd ${TmpTicketFolder}/targzpub
  mkdir tar
  mkdir tar/AR2${SBP_ENVIRONMENT}
  cp ../Mch/*/Pub/tar/*.tar tar/AR2${SBP_ENVIRONMENT}/
  cd tar
  tar -czf ../config.${ArgEnv}.Public.tar.gz *
  echo "Publieke versie van output tar.gz file gemaakt."

  mkdir ${TmpTicketFolder}/targzscrt
  cd ${TmpTicketFolder}/targzscrt
  mkdir tar
  mkdir tar/AR2${SBP_ENVIRONMENT}
  cp ../Mch/*/Scrt/tar/*.tar tar/AR2${SBP_ENVIRONMENT}/
  cd tar
  tar -czf ../config.${ArgEnv}.Secret.tar.gz *
  cd ..
  openssl enc -in config.${ArgEnv}.Secret.tar.gz -out config.${ArgEnv}.Secret.tar.gz.enc -aes256 -md sha256 -pass file:${ConfigDataFolder}/credentials/openssl.${ThePswEnv,,}.psw
  echo "Geheime versie van output tar.gz file gemaakt."

}

if [ "$ArgEnv" == "ACC" ]; then
  MakeMchTar "BAS" "BAS" "sv-arg-fas-a1" "sv-arg-bas-a1" "sv-arg-bes-a1" "10.188.8.83" "sv-arg-bes-a1" "bas.accargenta.be" "0" "0" "M"
  MakeMchTar "FAS" "FAS" "sv-arg-fas-a1" "sv-arg-bas-a1" "sv-arg-bes-a1" "10.188.8.83" "sv-arg-bes-a1" "bas.accargenta.be" "0" "0" "M"
  MakeMchTar "SF"  "SF"  "sv-arg-fas-a1" "sv-arg-bas-a1" "sv-arg-bes-a1" "10.188.8.83" "sv-arg-bes-a1" "bas.accargenta.be" "0" "0" "M"
  MakeMchTar "V2"  "V2"  "sv-arg-fas-a1" "sv-arg-bas-a1" "sv-arg-bes-a1" "10.188.8.83" "sv-arg-bes-a1" "bas.accargenta.be" "0" "0" "M"
  MakeTarGz
fi

if [ "$ArgEnv" == "SIM" ]; then
  MakeMchTar "BAS"  "BAS" "sv-arg-fas-s1" "sv-arg-bas-s1" "sv-arg-bes-s1" "10.185.8.47" "bes123-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS2" "BAS" "sv-arg-fas-s1" "sv-arg-bas-s2" "sv-arg-bes-s1" "10.185.8.47" "bes132-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS3" "BAS" "sv-arg-fas-s1" "sv-arg-bas-s3" "sv-arg-bes-s1" "10.185.8.47" "bes213-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS4" "BAS" "sv-arg-fas-s1" "sv-arg-bas-s4" "sv-arg-bes-s1" "10.185.8.47" "bes231-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS5" "BAS" "sv-arg-fas-s1" "sv-arg-bas-s5" "sv-arg-bes-s1" "10.185.8.47" "bes312-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS6" "BAS" "sv-arg-fas-s1" "sv-arg-bas-s6" "sv-arg-bes-s1" "10.185.8.47" "bes321-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "FAS"  "FAS" "sv-arg-fas-s1" "sv-arg-bas-s1" "sv-arg-bes-s1" "10.185.8.47" "bes123-sim.corporate.argenta.be" "bas1.simargenta.be" "0" "0" "M"
  MakeMchTar "FAS2" "FAS" "sv-arg-fas-s2" "sv-arg-bas-s1" "sv-arg-bes-s1" "10.185.8.47" "bes213-sim.corporate.argenta.be" "bas2.simargenta.be" "0" "0" "M"
  MakeMchTar "SF"   "SF"  "sv-arg-fas-s1" "sv-arg-bas-s1" "sv-arg-bes-s1" "10.185.8.47" "bes123-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "V2"   "V2"  "sv-arg-fas-s1" "sv-arg-bas-s1" "sv-arg-bes-s1" "10.185.8.47" "bes123-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "M"
  MakeMchTar "V22"  "V2"  "sv-arg-fas-s1" "sv-arg-bas-s1" "sv-arg-bes-s2" "10.185.8.18" "bes123-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "S"
  MakeMchTar "V23"  "V2"  "sv-arg-fas-s1" "sv-arg-bas-s1" "sv-arg-bes-s3" "10.185.8.19" "bes123-sim.corporate.argenta.be" "bas.simargenta.be" "0" "0" "S"
  MakeTarGz
fi

if [ "$ArgEnv" == "VAL" ]; then
  MakeMchTar "BAS"  "BAS" "sv-arg-fas-v1" "sv-arg-bas-v1" "sv-arg-bes-v1" "10.185.8.163" "bes123-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS2" "BAS" "sv-arg-fas-v1" "sv-arg-bas-v2" "sv-arg-bes-v1" "10.185.8.163" "bes132-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS3" "BAS" "sv-arg-fas-v1" "sv-arg-bas-v3" "sv-arg-bes-v1" "10.185.8.163" "bes213-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS4" "BAS" "sv-arg-fas-v1" "sv-arg-bas-v4" "sv-arg-bes-v1" "10.185.8.163" "bes231-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS5" "BAS" "sv-arg-fas-v1" "sv-arg-bas-v5" "sv-arg-bes-v1" "10.185.8.163" "bes312-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "BAS6" "BAS" "sv-arg-fas-v1" "sv-arg-bas-v6" "sv-arg-bes-v1" "10.185.8.163" "bes321-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "FAS"  "FAS" "sv-arg-fas-v1" "sv-arg-bas-v1" "sv-arg-bes-v1" "10.185.8.163" "bes123-val.corporate.argenta.be" "bas1-val.simargenta.be" "0" "0" "M"
  MakeMchTar "FAS2" "FAS" "sv-arg-fas-v2" "sv-arg-bas-v1" "sv-arg-bes-v1" "10.185.8.163" "bes213-val.corporate.argenta.be" "bas2-val.simargenta.be" "0" "0" "M"
  MakeMchTar "SF"   "SF"  "sv-arg-fas-v1" "sv-arg-bas-v1" "sv-arg-bes-v1" "10.185.8.163" "bes123-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "V2"   "V2"  "sv-arg-fas-v1" "sv-arg-bas-v1" "sv-arg-bes-v1" "10.185.8.163" "bes123-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "M"
  MakeMchTar "V22"  "V2"  "sv-arg-fas-v1" "sv-arg-bas-v1" "sv-arg-bes-v3" "10.185.8.162" "bes123-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "S"
  MakeMchTar "V23"  "V2"  "sv-arg-fas-v1" "sv-arg-bas-v1" "sv-arg-bes-v4" "10.185.8.168" "bes123-val.corporate.argenta.be" "bas-val.simargenta.be" "0" "0" "S"
  MakeTarGz
fi

if [ "$ArgEnv" == "PRD" ]; then
  MakeMchTar "BAS"  "BAS" "sv-arg-fas-p1" "sv-arg-bas-p1" "sv-arg-bes-p1" "10.181.8.36" "bes123.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "BAS2" "BAS" "sv-arg-fas-p1" "sv-arg-bas-p2" "sv-arg-bes-p1" "10.181.8.36" "bes132.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "BAS3" "BAS" "sv-arg-fas-p1" "sv-arg-bas-p3" "sv-arg-bes-p1" "10.181.8.36" "bes213.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "BAS4" "BAS" "sv-arg-fas-p1" "sv-arg-bas-p4" "sv-arg-bes-p1" "10.181.8.36" "bes231.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "BAS5" "BAS" "sv-arg-fas-p1" "sv-arg-bas-p5" "sv-arg-bes-p1" "10.181.8.36" "bes312.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "BAS6" "BAS" "sv-arg-fas-p1" "sv-arg-bas-p6" "sv-arg-bes-p1" "10.181.8.36" "bes321.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "FAS"  "FAS" "sv-arg-fas-p1" "sv-arg-bas-p1" "sv-arg-bes-p1" "10.181.8.36" "bes123.corporate.argenta.be" "bas1.argenta.be" "0" "0" "M"
  MakeMchTar "FAS2" "FAS" "sv-arg-fas-p2" "sv-arg-bas-p1" "sv-arg-bes-p1" "10.181.8.36" "bes213.corporate.argenta.be" "bas2.argenta.be" "0" "0" "M"
  MakeMchTar "SF"   "SF"  "sv-arg-fas-p1" "sv-arg-bas-p1" "sv-arg-bes-p1" "10.181.8.36" "bes123.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "V2"   "V2"  "sv-arg-fas-p1" "sv-arg-bas-p1" "sv-arg-bes-p1" "10.181.8.36" "bes123.corporate.argenta.be" "bas.argenta.be" "0" "0" "M"
  MakeMchTar "V22"  "V2"  "sv-arg-fas-p1" "sv-arg-bas-p1" "sv-arg-bes-p2" "10.181.8.37" "bes123.corporate.argenta.be" "bas.argenta.be" "0" "0" "S"
  MakeMchTar "V23"  "V2"  "sv-arg-fas-P1" "sv-arg-bas-p1" "sv-arg-bes-p5" "10.181.8.40" "bes123.corporate.argenta.be" "bas.argenta.be" "0" "0" "S"
  MakeTarGz
fi

# Check out de source directory

Svn_set_options
OplFolder="sbp_configuratie"
Svn_co

cd sbp_configuratie
mkdir -p generated
cd generated

# Replace the Public and Private files

  cp ../../../targzpub/config.${ArgEnv}.Public.tar.gz .
  cp ../../../targzscrt/config.${ArgEnv}.Secret.tar.gz.enc .

cd ..

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
