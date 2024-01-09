#### Slave error and warnings
####
#### Include this library to be able to raise specific error and warning messages
#### to the users. Please ensure all error messages have sufficient explanation
#### here or in the appropriate location.
####
#### Important: this module file may only be sourced from code that runs on
#### target slave machines. For errors on the master, package manager or slave
#### deployIT servers (depm, depp, deps and depps), please use the main error
#### script file deploy_errorwarns.sh
####
#### This source script may be sourced multiple times without problems.
#### Hence, any routine that uses it, should have a source pointer to it.
################################################################################
# Change history
################################################################################
# dexa  # Feb/2020    # 1.0.0    # initial version for IVL related errors
#       #    /20      #          #
################################################################################
ScriptVersion="1.0.0"

#### Error constants and messages

if [ -z "$deploy_slverror_list_loaded" ]; then
declare -r deploy_slverror_list_loaded=1
declare -a deploy_slverror_text

#### Start of DPLERR messages  -- add new messages at the end and increment the counter
#### Extra parameters can be used via these syntax: \$2 then \$3 and so on.

declare -r DPLERRSLV_Undefined=5001
deploy_slverror_text[$DPLERRSLV_Undefined]="Undefined error"
## Generic Slave or Target server related error messages range: 5002-5099
declare -r DPLERRSLV_InvalidRCFound=5002
deploy_slverror_text[$DPLERRSLV_InvalidRCFound]="Een slave proces eindigde op een RC code waarmee geen geldige error code kon gevonden worden."
## Error range reserved for IVL: 5102-5199
declare -r DPLERRSLV_IVL_Base=5100  ## de RC is dan de Error-Base, dus van 2 tot 99.
declare -r DPLERRSLV_IVL_ZipError=5102
deploy_slverror_text[$DPLERRSLV_IVL_ZipError]="IVL deploy had een probleem met de .zip file. Controleer de bestanden."
declare -r DPLERRSLV_IVL_EnvNotStopped=5103
deploy_slverror_text[$DPLERRSLV_IVL_EnvNotStopped]="Deze IVL deploy eist dat alle activiteit op de engine gestopt is, maar er zijn nog processen actief!"
declare -r DPLERRSLV_IVL_DDLError=5104
deploy_slverror_text[$DPLERRSLV_IVL_DDLError]="IVL deploy heeft DDL code uitgevoerd maar dit gebeurde niet correct. Bekijk de SQL output voor details."
declare -r DPLERRSLV_IVL_TopoZipRTError=5105
deploy_slverror_text[$DPLERRSLV_IVL_TopoZipRTError]="IVL deploy heeft een topology zip file uitrol gedaan naar de RT maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_EXECRTError=5106
deploy_slverror_text[$DPLERRSLV_IVL_EXECRTError]="IVL deploy heeft een EXEC_ zip file uitrol gedaan naar de RT maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_LPRTError=5107
deploy_slverror_text[$DPLERRSLV_IVL_LPRTError]="IVL deploy heeft een Load Plan (LP_) file uitrol gedaan naar de RT maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_LinkTopoRTError=5108
deploy_slverror_text[$DPLERRSLV_IVL_LinkTopoRTError]="IVL deploy heeft een link context topology uitrol gedaan naar de RT maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_CheckRelRTError=5109
deploy_slverror_text[$DPLERRSLV_IVL_CheckRelRTError]="IVL deploy een check_release gedaan op de RT maar die gaf een fout. Bekijk de log voor details."
declare -r DPLERRSLV_IVL_TopoZipOEMMError=5110
deploy_slverror_text[$DPLERRSLV_IVL_TopoZipOEMMError]="IVL deploy heeft een topology zip file uitrol gedaan naar de OEMM maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_FULLOEMMError=5111
deploy_slverror_text[$DPLERRSLV_IVL_FULLOEMMError]="IVL deploy heeft een ODI zip file uitrol gedaan naar de OEMM maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_LPOEMMError=5112
deploy_slverror_text[$DPLERRSLV_IVL_LPOEMMError]="IVL deploy heeft een Load Plan (LP_) file uitrol gedaan naar de OEMM maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_LinkTopoOEMMError=5113
deploy_slverror_text[$DPLERRSLV_IVL_LinkTopoOEMMError]="IVL deploy heeft een link context topology uitrol gedaan naar de OEMM maar dit gebeurde niet correct. Bekijk de ODI log voor details."
declare -r DPLERRSLV_IVL_CheckRelOEMMError=5114
deploy_slverror_text[$DPLERRSLV_IVL_CheckRelOEMMError]="IVL deploy een check_release gedaan op de OEMM maar die gaf een fout. Bekijk de log voor details."
declare -r DPLERRSLV_IVL_TestDDL1Error=5115
deploy_slverror_text[$DPLERRSLV_IVL_TestDDL1Error]="IVL deploy voerde een Test DDL run uit, en die faalde bij de eerste uitvoering. Bekijk de SQL log voor details."
## Do not use code 5116: it is reserved for IVL errors that use the generic RC=16 return code
declare -r DPLERRSLV_IVL_TestDDL2Error=5117
deploy_slverror_text[$DPLERRSLV_IVL_TestDDL2Error]="IVL deploy voerde een Test DDL run uit, en die faalde bij de tweede uitvoering. Bekijk de SQL log voor details."
declare -r DPLERRSLV_IVL_CreateRPError=5118
deploy_slverror_text[$DPLERRSLV_IVL_CreateRPError]="IVL deploy startte een Test DDL run en probeerde een Restore Point aan te maken, maar dat faalde, ook na retries. Mogelijks is een of meerdere andere langdurige processen bezig met Test DDLs."
declare -r DPLERRSLV_IVL_DropRPError=5119
deploy_slverror_text[$DPLERRSLV_IVL_DropRPError]="IVL deploy startte een Test DDL run en probeerde een Restore Point te droppen, maar dat faalde. Bekijk de SQL output voor details."
declare -r DPLERRSLV_IVL_FlashRPError=5120
deploy_slverror_text[$DPLERRSLV_IVL_FlashRPError]="IVL deploy startte een Test DDL run die faalde, en probeerde dan een Flashback naar een Restore Point, maar dat faalde. Dat betekent dat de Test DDL omgeving nu KAPOT is! Bekijk de SQL output voor details."
#### End of DPLERR messages
else
  : ## error list is already loaded
fi

slv_exit() {
## This function will issue a slave exit call, resulting in a return to the
## master process with an explicit return code. Using the $DPLERR_BASE variable,
## the actual DPLERRSLV code can be reduced to an acceptable return code (1..125)
## which the caller can then reconstruct to the correct DPLERRSLV code.
local errorcode=$1
local stacktrace=$(caller 0)
echo "debug info: slv_exit called from: $stacktrace"
if [ -z "$DPLERR_BASE" ]; then
  echo "ERROR: slv_exit was called but variable DPLERR_BASE was not set!"
  exit 1
fi
local localRC=$((errorcode-DPLERR_BASE))
if [ $localRC -lt 2 ]; then
  echo "ERROR: slv_exit was called but the errorcode is out of range (${localRC})!"
  exit 1
fi
if [ $localRC -gt 125 ]; then
  echo "ERROR: slv_exit was called but the errorcode is out of range (${localRC})!"
  exit 1
fi
## we are now sure we have a valid RC
exit $localRC
}

deploy_slvRC() {
## A call was made to a slave functionality, and that used the slv_exit function
## above. Hence, an ErrorCode was converted to the RC. Now, we convert it back
## and issue the appropriate error message.
local localRC=$1
local stacktrace=$(caller 0)
if [ -z "$DPLERR_BASE" ]; then
  echo "ERROR: deploy_slvRC was called but variable DPLERR_BASE was not set!"
  exit 1
fi
local errorcode=$((DPLERR_BASE+localRC))
if [ -z "${deploy_slverror_text[$errorcode]}" ]; then
    echo "A slave process came back with an error return code, but that could not be"
    echo "matched with a valid DEPLOYIT error code."
    echo "DPLERR_BASE        : $DPLERR_BASE"
    echo "Received RC        : $localRC"
    echo "Derived error code : '$errorcode'"
    slvdeploy_error $DPLERRSLV_InvalidRCFound
else
    ##eval is nodig om extra parameters in de error message te resolven
    eval 'errorlijn="'${deploy_slverror_text[$errorcode]}'"'
    echo "Error DPLERR"$errorcode": "${errorlijn}
    echo "Stack trace of the call that failed: $stacktrace"
    exit 16
fi
}

slvdeploy_error() {
local errorcode=$1
local stacktrace=$(caller 0)

re='^[0-9]+$'
if ! [[ $errorcode =~ $re ]] ; then
   echo "error: The parameter for deploy_error was not a valid DPLERR code."
   exit 16
fi

if [ -z "${deploy_slverror_text[$errorcode]}" ]; then
    echo "An unspecified error code was found: '$errorcode'"
    echo "Stack trace of the error: $stacktrace"
    exit 16
else
    ##eval is nodig om extra parameters in de error message te resolven
    eval 'errorlijn="'${deploy_slverror_text[$errorcode]}'"'
    echo "Error DPLERR"$errorcode": "${errorlijn}
    echo "Stack trace of the error: $stacktrace"
    exit 16
fi
}

