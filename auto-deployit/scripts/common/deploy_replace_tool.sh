# Bash functions to call the replace tool on a complete folder
#
# Both the public version (no vault data) and the secret version
# can be generated in 1 run. The default option for the secret
# version is that each file is individually encrypted with an
# openssl call. Alternatively, files can be left as-is and the
# calling program can then encrypt them (see the RT_Enc_SKIP
# option).
#
########################################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # 29/06/2016  # added RT_Enc_SKIP and RT_KeepCHMOD opts
# dexa  # 31/10/2016  # adde nullglob om lege ADCs te parsen voor verify
# dexa  # 05/12/2016  # start using deploy_errorwarns.sh
# dexa  # 06/12/2016  # toev mogelijke output van gebruikte waarden
# dexa  # 15/12/2016  # toev RT_AllErrors en RT_EchoFileNames
#       #             #     en RT_ReturnCode
# dexa  # 06/01/2017  # ONDERSTEUN-1101: toev java tmp optie
# dexa  # 25/04/2017  # ONDERSTEUN-1242: toev timestamp in logging
# dexa  # 16/06/2017  # ONDERSTEUN-1502: process hidden files
# dexa  # 07/12/2017  # padnaam kan " -" bevatten, dus moet alles
#       #             # telkens met quotes gebeuren
# dexa  # 07/12/2017  #  1.0.0  # toevoegen versie info in elk script
# dexa  # 24/02/2020  #  1.1.0  # toevoegen ivl routines
# dexa  # 13/10/2020  #  1.2.0  # toevoegen EncCombiMode for BATCH ADCs
# lekri # 02/06/2021  #  1.2.1  # SSGT-65: openssl key hashing -> sha256
#       #             #         #
#############################################################################
#

source "${ScriptPath}/deploy_errorwarns.sh"
ScriptVersion="1.2.1"

Replace_Tool_Defaults() {
## Input:
##          Requires deploy_global_settings to have run
##          No specific variables
## Output:
##          Sets several $RT_* variables to default values
RT_JarPath="${BinFolder}/train-tools-replace.jar"
RT_Cmdb_csv="${SvnConfigDataFolder}/Placeholders_DeployIt.csv"
LogLineDEBUG "Function Call Replace_Tool_Defaults completed."
RT_Enc_SKIP=0
RT_KeepCHMOD=0
RT_ScanFilter="*"
RT_Dos2Unix=0
RT_LogUsage=""
RT_TicketNr="N/A"
RT_HiddenFiles=0
RT_AllErrors=0
RT_EchoFileNames=0
RT_EncCombiMode=0
}

Replace_Tool() {
## Input:
##    Requires deploy_global_functions to have run for the LogLineXXX functions
##    $RT_InFolder        : Folder to scan for files to be replaced
##    $RT_ScanFilter      : Filename Filter to limit which files to replace
##    $RT_OutFolder       : The output location where files will be written to
##    $RT_OutFolderEnc    : The output location with encrypted files
##                            If this value is empty, then no encrypted files
##                            will be generated.
##    $RT_Env             : The Environment for which to generate
##    $RT_ADC             : The ADC for which to generate
##    $RT_Vault           : The psafe3 vault file to use for passwords
##    $RT_VaultPSW        : The psafe3 vault master password
##    $RT_EncPSW          : The openssl encryption master password
##    $RT_Tmp             : A temporary folder where files may be written
##    The below input parameters can be set to default values using the
##        Replace_Tool_Defaults() function
##    $RT_JarPath         : The path where to run the replace tool from
##    $RT_Cmdb_csv        : The CSV file with placeholder values to use
##    $RT_Enc_SKIP        : (default=0) 1 means the encryption step is skipped
##                          This means the resulting folder must be protected
##                          later on by other means by the calling application
##    $RT_KeepCHMOD       : (default=0) 1 means the chmod settings of the files
##                          are preserved. This is done using a chmod with the
##                          --reference option. Applies to both the output folders
##    $RT_DosToUnix       : (default=0) 1 means that a dostounix is to be done
##    $RT_LogUsage        : (default="") file name where to write the usage logging
##    $RT_TicketNr        : (default="N/A") ticket number to write to logging entries
##    $RT_HiddenFiles     : (default=0) Process also hidden files (starting with ".")
##    $RT_AllErrors       : (default=0) In case of errors, continue to show all errors
##    $RT_EchoFileNames   : (default=0) Show each file name in STDOUT before processing
##    $RT_EncCombiMode    : (default=0) Allows to replace both public and encrypted
##                          in one target folder. Files that don't contain passwords
##                          are available in plain format. Files that do have vault
##                          derived data will be present twice, in their base filename
##                          with blanks and in an .enc filename with real psw & encrypted
## Output:
##    All files in the $RT_InFolder are processed. If not selected by the ScanFilter,
##       the file is simply copied to the related $RT_OutFolder. If it matches the
##       ScanFilter constraints, the replace tool is applied on it.
##    $RT_ReturnCode indicates specific problems during replace tool
##             0   = All OK
##             1   = Errors on vault lookup
##             2   = Errors on placeholder lookup
##    RC=16 indicates a major error or a replace error while RT_AllErrors=0

## Echo input parameters in DEBUG level
LogLineDEBUG "RT_InFolder       : $RT_InFolder"
LogLineDEBUG "RT_ScanFilter     : $RT_ScanFilter"
LogLineDEBUG "RT_OutFolder      : $RT_OutFolder"
LogLineDEBUG "RT_OutFolderEnc   : $RT_OutFolderEnc"
LogLineDEBUG "RT_Env            : $RT_Env"
LogLineDEBUG "RT_ADC            : $RT_ADC"
LogLineDEBUG "RT_Vault          : $RT_Vault"
LogLineDEBUG "RT_VaultPSW       : $RT_VaultPSW"
LogLineDEBUG "RT_EncPSW         : $RT_EncPSW"
LogLineDEBUG "RT_AltEncPSW      : $RT_AltEncPSW"
LogLineDEBUG "RT_Tmp            : $RT_Tmp"
LogLineDEBUG "RT_JarPath        : $RT_JarPath"
LogLineDEBUG "RT_Cmdb_csv       : $RT_Cmdb_csv"
LogLineDEBUG "RT_Enc_SKIP       : $RT_Enc_SKIP"
LogLineDEBUG "RT_KeepCHMOD      : $RT_KeepCHMOD"
LogLineDEBUG "RT_Dos2Unix       : $RT_Dos2Unix"
LogLineDEBUG "RT_LogUsage       : $RT_LogUsage"
LogLineDEBUG "RT_TicketNr       : $RT_TicketNr"
LogLineDEBUG "RT_HiddenFiles    : $RT_HiddenFiles"
LogLineDEBUG "RT_AllErrors      : $RT_AllErrors"
LogLineDEBUG "RT_EchoFileNames  : $RT_EchoFileNames"
LogLineDEBUG "RT_EncCombiMode   : $RT_EncCombiMode"

CsvToPropOpts="--input-file $RT_Cmdb_csv --omgeving $RT_Env --applicatie $RT_ADC"
CsvToPropEntry="be.argenta.train.tools.csv.CsvToProperties"

PropReplLog=""
CsvToPropLog=""
if [ -n "$RT_LogUsage" ]; then
  touch $RT_LogUsage
  echo "touch = "$?
  CsvToPropLog="--adc-file $RT_Tmp/cmdblog.tmp"
  PropReplLog="--adc-file $RT_Tmp/cmdblog.tmp --usage-file $RT_LogUsage --usage-prefix-file $RT_Tmp/logprepend.tmp"
  local ArgTicketNr=$RT_TicketNr
  local ArgEnv=$RT_Env
  local TmpFld=$RT_Tmp
  if [ "$ArgTicketNr" != "N/A" ]; then
    Handover_GetTicketInfo
  else
    TicketADCTRC="N/A"
    TicketReleaseID="N/A"
  fi
  TimeStamp=$(date +"%Y-%m-%d_%H-%M-%S")
  echo "$ArgTicketNr|$TicketID|$ArgEnv|$TicketADCTRC|$TicketReleaseNR|$TicketReleaseID|$TimeStamp|" > "$RT_Tmp/logprepend.tmp"
fi

RT_ReturnCode=0

LogLineDEBUG2 "Replace tool call 1: java -Djava.io.tmpDir=$RT_Tmp -cp $RT_JarPath $CsvToPropEntry $CsvToPropOpts $CsvToPropLog --output-file $RT_Tmp/cmdb.tmp"
java -Djava.io.tmpDir=$RT_Tmp -cp $RT_JarPath $CsvToPropEntry $CsvToPropOpts $CsvToPropLog --output-file $RT_Tmp/cmdb.tmp
RC=$?
if [ $RC -ne 0 ]; then
  deploy_error $DPLERR_ReplCsvToProp
else
  LogLineDEBUG "Replace Tool deel 1 is OK."
fi

PropReplOpts="--property-file $RT_Tmp/cmdb.tmp --ascii"
PropReplEntry="be.argenta.train.tools.replace.PropertyReplace"
## PaswReplOptsPublic="--blanks --ascii"
## PaswReplOptsSecret="--ascii --pw-vault-file $RT_Vault --pw-vault-password $RT_VaultPSW --omgeving $RT_Env"
PaswReplOptsPublic="--property-file $RT_Tmp/cmdb.tmp --blanks --ascii"
PaswReplOptsSecret="--property-file $RT_Tmp/cmdb.tmp --ascii --pw-vault-file $RT_Vault --pw-vault-password $RT_VaultPSW --omgeving $RT_Env"
PaswReplEntry="be.argenta.train.tools.replace.PasswordReplace"
OpenSSLOpts="-aes256 -md sha256 -pass file:${RT_EncPSW}"
if ! [ -z "$RT_AltEncPSW" ]; then
	LogLineDEBUG "Using alternate encoding password from $RT_AltEncPSW."
	AltOpenSSLOpts="-aes256 -md sha256 -pass file:${RT_AltEncPSW}"
fi
SavedShOpts=$(shopt -p globstar nullglob dotglob)
shopt -s nullglob
shopt -s globstar
if [ $RT_HiddenFiles -eq 1 ]; then
  shopt -s dotglob
fi
## for filename in $(find ${infld}); do
for filename in ${RT_InFolder}/**/* ; do
  LogLineDEBUG2 "Raw filename is $filename"
  ## strpfn is the Stripped Filename without the RT_InFolder path
  ## This allows to easily construct the related output filename
  ## By concatenating RT_OutFolder with strpfn.
  strpfn=${filename#"${RT_InFolder}/"}
  if [ -d "$RT_InFolder/$strpfn" ]; then
    LogLineDEBUG "subfolder $strpfn aanmaken in $RT_OutFolder."
    mkdir "${RT_OutFolder}/$strpfn"
    if [ "$RT_OutFolderEnc" = "" ]; then
      LogLineDEBUG "Geen subfolder aanmaken voor encrypted output."
    else
      mkdir "${RT_OutFolderEnc}/$strpfn"
    fi
  else
    curfilein="$RT_InFolder/$strpfn"
    curfileout="$RT_OutFolder/$strpfn"
    curfileoutenc="$RT_OutFolderEnc/$strpfn.enc"
	curfileoutaltenc="$RT_OutFolderEnc/$strpfn.enc2"
    curfileoutencNotEncrypted="$RT_OutFolderEnc/$strpfn"

    LogLineDEBUG "Processing deel 2 for file $strpfn ..."
    LogLineDEBUG2 "Replace tool call 2: java -Djava.io.tmpDir=$RT_Tmp -cp $RT_JarPath $PaswReplEntry $PaswReplOptsPublic $PropReplLog --input-file $curfilein --output-file $curfileout"
    java -Djava.io.tmpDir=$RT_Tmp -cp $RT_JarPath $PaswReplEntry $PaswReplOptsPublic $PropReplLog --input-file "$curfilein" --output-file "$curfileout"
    RC=$?
    if [ $RC -ne 0 ]; then
      if [ $RT_AllErrors -eq 0 ]; then
        deploy_error $DPLERR_ReplPaswBlank
      else
        echo "Warning: Errors tijdens deel 2."
        if [ $RT_ReturnCode -lt 1 ]; then
          RT_ReturnCode=1
        fi
      fi
    else
      LogLineDEBUG "Replace Tool deel 2 voor deze file is OK."
    fi # $RC -ne 0
    if [ $RT_Dos2Unix -eq 1 ]; then
      dos2unix -o "${curfileout}"
      RC=$?
      if [ $RC -ne 0 ]; then
        echo "Replace Tool dos2unix is niet goed beeindigd."
        exit 16
      fi
    fi # $RT_Dos2Unix -eq 1
    if [ $RT_KeepCHMOD -eq 1 ]; then
      LogLineDEBUG "Performing chmod on output file"
      chmod --reference "$curfilein" "$curfileout"
      RC=$?
      if [ $RC -ne 0 ]; then
        echo "Replace Tool chmod is niet goed beeindigd."
        exit 16
      fi
    fi # $RT_KeepCHMOD -eq 1
    if [ "$RT_OutFolderEnc" = "" ] && [ "$RT_EncCombiMode" = "0" ]; then
      LogLineDEBUG "Processing deel 3 skipped."
    else
      LogLineDEBUG "Processing deel 3 for file $strpfn ..."
      LogLineDEBUG2 "Replace tool call 3: java -Djava.io.tmpDir=$RT_Tmp -cp $RT_JarPath $PaswReplEntry $PaswReplOptsSecret $PropReplLog --input-file $curfilein --output-file $RT_Tmp/file_out3"
      java -Djava.io.tmpDir=$RT_Tmp -cp $RT_JarPath $PaswReplEntry $PaswReplOptsSecret $PropReplLog --input-file "$curfilein" --output-file $RT_Tmp/file_out3
      RC=$?
      if [ $RC -ne 0 ]; then
        if [ $RT_AllErrors -eq 0 ]; then
          deploy_error $DPLERR_ReplPaswVault
        else
          echo "Warning: Errors tijdens deel 3."
          if [ $RT_ReturnCode -lt 1 ]; then
            RT_ReturnCode=1
          fi
        fi
      else
        LogLineDEBUG "Replace Tool deel 3 voor deze file is OK."
      fi # $RC -ne 0
      if [ "$RT_EncCombiMode" = "1" ]; then
        ## compare output of replace 2 (no psw) with replace 3 (with psw)
        diff "${curfileout}" "$RT_Tmp/file_out3" > /dev/null
        if [ $? -eq 0 ]; then
          LogLineDEBUG "Replace deel 3 gaf identieke file als deel 2 en EncCombiMode=1. Niet bijhouden."
          curfileoutenc="/dev/null"
        else
          ## override the target location to the default out folder
          curfileoutenc="$RT_OutFolder/$strpfn.enc"
        fi
      fi # $RT_EncCombiMode = 1
      if [ $RT_Enc_SKIP -eq 1 ]; then
        LogLineDEBUG "Encryption step skipped"
        cp $RT_Tmp/file_out3 "${curfileoutencNotEncrypted}"
        if [ $RT_Dos2Unix -eq 1 ]; then
          dos2unix -o "${curfileoutencNotEncrypted}"
          RC=$?
          if [ $RC -ne 0 ]; then
            deploy_error $DPLERR_ReplDos2Unix
          fi
        fi
        if [ $RT_KeepCHMOD -eq 1 ]; then
          LogLineDEBUG "Performing chmod on output file"
          chmod --reference "$curfilein" "$curfileoutencNotEncrypted"
          RC=$?
          if [ $RC -ne 0 ]; then
            deploy_error $DPLERR_ReplChmod
          fi
        fi
      else
        openssl enc -in $RT_Tmp/file_out3 -out "${curfileoutenc}" $OpenSSLOpts
        RC=$?
        if [ $RC -ne 0 ]; then
          deploy_error $DPLERR_ReplOpenSSLEnc
        else
          LogLineDEBUG "Replace Tool deel 4 voor deze file is OK."
        fi
        if [ $RT_Dos2Unix -eq 1 ] && [ "${curfileoutenc}" != "/dev/null" ]; then
          dos2unix -o "${curfileoutenc}"
          RC=$?
          if [ $RC -ne 0 ]; then
            deploy_error $DPLERR_ReplDos2Unix
          fi
        fi
        if [ $RT_KeepCHMOD -eq 1 ] && [ "${curfileoutenc}" != "/dev/null" ]; then
          LogLineDEBUG "Performing chmod on output file"
          chmod --reference "$curfilein" "$curfileoutenc"
          RC=$?
          if [ $RC -ne 0 ]; then
            deploy_error $DPLERR_ReplChmod
          fi
        fi
		if ! [ -z "$RT_AltEncPSW" ]; then
			openssl enc -in $RT_Tmp/file_out3 -out "${curfileoutaltenc}" $AltOpenSSLOpts
			RC=$?
			if [ $RC -ne 0 ]; then
				deploy_error $DPLERR_ReplOpenSSLEnc
			else
				LogLineDEBUG "Replace Tool deel 4.1 voor deze file is OK."
			fi
			if [ $RT_Dos2Unix -eq 1 ] && [ "${curfileoutenc}" != "/dev/null" ]; then
				dos2unix -o "${curfileoutaltenc}"
				RC=$?
				if [ $RC -ne 0 ]; then
					deploy_error $DPLERR_ReplDos2Unix
				fi
			fi
			if [ $RT_KeepCHMOD -eq 1 ] && [ "${curfileoutenc}" != "/dev/null" ]; then
				LogLineDEBUG "Performing chmod on output file"
				chmod --reference "$curfilein" "$curfileoutaltenc"
				RC=$?
				if [ $RC -ne 0 ]; then
					deploy_error $DPLERR_ReplChmod
				fi
			fi
		fi
      fi # $RT_Enc_SKIP -eq 1
      ## remove unencrypted confidential file
      rm $RT_Tmp/file_out3
    fi # "$RT_OutFolderEnc" = "" && "$RT_EncCombiMode" = "0"
  fi # if [ -d "$RT_InFolder/$strpfn" ]; then
done
## restart shopt settings
eval "$SavedShOpts"
## remove tmp file cmdb
rm $RT_Tmp/cmdb.tmp
if [ -n "$RT_LogUsage" ]; then
  rm $RT_Tmp/cmdblog.tmp
  rm $RT_Tmp/logprepend.tmp
fi

LogLineINFO "Replace tool: Alle input files werden behandeld."

}


#########################################################################
## global functions for IVL deploy that use the replace tool           ##
#########################################################################

GetIvlInfo() {
LogLineDEBUG2 "Call to GetIvlInfo() with attributes:"
LogLineDEBUG2 "TmpFld=$TmpFld"
LogLineDEBUG2 "TheEnv=$TheEnv"
LogLineDEBUG2 "TheADC=$TheADC"

Replace_Tool_Defaults

RT_InFolder="$TmpFld/in"
RT_ScanFilter="*"
RT_OutFolder="$TmpFld/out"
RT_OutFolderEnc=""
RT_Env=$TheEnv
RT_ADC=$TheADC
RT_Tmp=$TmpFld/tmp

rm -rf $RT_InFolder
mkdir -p $RT_InFolder
rm -rf $RT_OutFolder
mkdir -p $RT_OutFolder
rm -rf $RT_Tmp
mkdir -p $RT_Tmp

# make the temp file with the settings list
cat > $RT_InFolder/ivl_deploy_settings.sh << EOL
## BOF ADC Deploy Paths
OdiTgtServer=@@DEPLOYIT_IVL_TARGET_SERVER#@
OdiTgtLoggingFolder=@@DEPLOYIT_IVL_LOGGING_FOLDER#@
EOL

Replace_Tool

if [ ! -e $RT_OutFolder/ivl_deploy_settings.sh ]; then
  echo "Replace tool kan IVL settings file (static) niet correct verwerken!"
  exit 16
fi
LogLineDEBUG2 "IVL settings code:"
if [ $DebugLevel -gt 4 ]; then
  cat $RT_OutFolder/ivl_deploy_settings.sh
fi
LogLineDEBUG2 "end of IVL settings code"

source $RT_OutFolder/ivl_deploy_settings.sh

LogLineINFO "OdiTgtServer       = '${OdiTgtServer}'"
LogLineINFO "OdiTgtLoggingFolder= '${OdiTgtLoggingFolder}'"

## Opkuisen tijdelijke files
rm -f $RT_InFolder/ivl_deploy_settings.sh
rmdir $RT_InFolder
rm -f $RT_OutFolder/ivl_deploy_settings.sh
rmdir $RT_OutFolder
rmdir $RT_Tmp
}

Ivl_replace() {
local IFolder=$1
local OFolder=$2
LogLineDEBUG2 "Call to Ivl_replace() with attributes:"
LogLineDEBUG2 "TmpFld=$TmpFld"
LogLineDEBUG2 "TheEnv=$TheEnv"
LogLineDEBUG2 "ThePswEnv=$ThePswEnv"
LogLineDEBUG2 "TheADC=$TheADC"
LogLineDEBUG2 "IFolder=$IFolder"
LogLineDEBUG2 "OFolder=$OFolder"

Replace_Tool_Defaults

RT_InFolder="$IFolder"
RT_ScanFilter="*"
RT_OutFolder="$OFolder"
RT_OutFolderEnc="$OFolder"
RT_Env=$TheEnv
RT_ADC=$TheADC
RT_Tmp=$TmpFld/tmp
RT_Enc_SKIP=1
## Merk op dat ArgEnv naar lowercase wordt gezet voor de
## psafe3 file name.
RT_Vault="${SvnConfigDataFolder}/ivl_${ThePswEnv,,}.psafe3"
RT_VaultPSW="${ConfigDataFolder}/credentials/vault.${ThePswEnv,,}.psw"
RT_EncPSW="NOT_USED"

rm -rf $RT_Tmp
mkdir -p $RT_Tmp

Replace_Tool

## reduce chmod rechten op de output files
chmod 600 $OFolder/*

## Opkuisen tijdelijke files
rm -rf $RT_Tmp
}
