#### Include this library to be able to raise specific error and warning messages
#### to the users. Please ensure all error messages have sufficient explanation
#### here or in the appropriate location.

#### This source script may be sourced multiple times without problems.
#### Hence, any routine that uses it, should have a source pointer to it.
#################################################################
# Change history
#################################################################
# dexa  # Feb/2019    # 1.0.0 # toev ScriptVersion lijn
# dexa  # Feb/2020    # 2.0.0 # add info about 5000 range for slave errors
#################################################################
ScriptVersion="2.0.0"

#### Error constants and messages

if [ -z "$deploy_error_list_loaded" ]; then
declare -r deploy_error_list_loaded=1
declare -a deploy_error_text

#### Start of DPLERR messages  -- add new messages at the end and increment the counter
#### Extra parameters can be used via these syntax: \$2 then \$3 and so on.

declare -r DPLERR_Undefined=1001
deploy_error_text[$DPLERR_Undefined]="Undefined error"
declare -r DPLERR_ReplCsvToProp=1002
deploy_error_text[$DPLERR_ReplCsvToProp]="Replace Tool deel 1 (CsvToProperties), is niet goed beeindigd."
declare -r DPLERR_ReplPropRepl=1003
deploy_error_text[$DPLERR_ReplPropRepl]="Replace Tool deel 2 (PropertyReplace) is niet goed beeindigd."
declare -r DPLERR_ReplPaswBlank=1004
deploy_error_text[$DPLERR_ReplPaswBlank]="Replace Tool deel 3 (PasswordReplace -B) is niet goed beeindigd."
declare -r DPLERR_ReplPaswVault=1005
deploy_error_text[$DPLERR_ReplPaswVault]="Replace Tool deel 4 (PasswordReplace vault) is niet goed beeindigd."
declare -r DPLERR_MissingArgEnv=1006
deploy_error_text[$DPLERR_MissingArgEnv]="Invalid input parameters in function: ArgEnv is missing."
declare -r DPLERR_FileNotFound=1007
deploy_error_text[$DPLERR_FileNotFound]="File not found: \$2."
declare -r DPLERR_GetEnvDataMissingBof=1008
deploy_error_text[$DPLERR_GetEnvDataMissingBof]="Invalid file in function GetEnvData for file \$2 with missing bof data on line \$3"
declare -r DPLERR_GetEnvDataMissingOpl=1009
deploy_error_text[$DPLERR_GetEnvDataMissingOpl]="Invalid file in function GetEnvData for file \$2 with missing opl data on line \$3"
declare -r DPLERR_GetEnvDataMissingUsr=1010
deploy_error_text[$DPLERR_GetEnvDataMissingUsr]="Invalid file in function GetEnvData for file \$2 with missing useronapplsrv data on line \$3"
declare -r DPLERR_GetEnvDataMissingEnv=1011
deploy_error_text[$DPLERR_GetEnvDataMissingEnv]="Function GetEnvData could not find information in file \$2 for environment \$3"
declare -r DPLERR_TraceITACCInvalidEnv=1012
deploy_error_text[$DPLERR_TraceITACCInvalidEnv]="Aanvraag om op TraceIT ACC te werken mag NIET op deze AutoDeploy omgeving!!!"
declare -r DPLERR_MissingArgAppl=1013
deploy_error_text[$DPLERR_MissingArgAppl]="Invalid input parameters in function: ArgAppl is missing."
declare -r DPLERR_GetCntInfoMissingFld=1014
deploy_error_text[$DPLERR_GetCntInfoMissingFld]="Invalid file in function GetCntInfo for file \$2 with missing folder data on line \$3"
declare -r DPLERR_GetCntInfoMissingAppl=1015
deploy_error_text[$DPLERR_GetCntInfoMissingAppl]="Function GetCntInfo could not find information in file \$2 for application \$3"
declare -r DPLERR_JenkinsBuildNrMissing=1016
deploy_error_text[$DPLERR_JenkinsBuildNrMissing]="This script requires a Jenkins Build number, but none was provided."
declare -r DPLERR_SvnError=1017
deploy_error_text[$DPLERR_SvnError]="An Svn action was attempted but it failed."
declare -r DPLERR_TicketInfoMissing=1018
deploy_error_text[$DPLERR_TicketInfoMissing]="The ticket info for this ticket was incomplete. Missing info is: \$2"
declare -r DPLERR_TicketInfoWrongTicket=1019
deploy_error_text[$DPLERR_TicketInfoWrongTicket]="The ticket info for this ticket was incorrect, as it returned info for another ticket. Asked: '\$2' Received: '\$3'"
declare -r DPLERR_HandoverDownloadService=1020
deploy_error_text[$DPLERR_HandoverDownloadService]="The handover tool function DownloadService has failed."
declare -r DPLERR_HandoverGetSourceSvnRepo=1021
deploy_error_text[$DPLERR_HandoverGetSourceSvnRepo]="The handover tool function GetSourceSvnRepo has failed."
declare -r DPLERR_HandoverGeneratedStagingService=1022
deploy_error_text[$DPLERR_HandoverGeneratedStagingService]="The handover tool function GeneratedStagingService has failed."
declare -r DPLERR_SvnCheckout=1023
deploy_error_text[$DPLERR_SvnCheckout]="The svn function call 'co' (checkout) has failed. Return code was \$2."
declare -r DPLERR_SvnCommit=1024
deploy_error_text[$DPLERR_SvnCommit]="The svn function call 'commit' has failed. Reason was \$2."
declare -r DPLERR_ServerCount0=1025
deploy_error_text[$DPLERR_ServerCount0]="The target server list for this request is empty."
declare -r DPLERR_ScpPutFailed=1026
deploy_error_text[$DPLERR_ScpPutFailed]="An scp PUT request has failed for file '\$2' onto target server \$3."
declare -r DPLERR_SshExecFailed=1027
deploy_error_text[$DPLERR_SshExecFailed]="An ssh request to execute script '\$2' on target server \$3 has failed with return code \$4."
declare -r DPLERR_StopContainerFailed=1028
deploy_error_text[$DPLERR_StopContainerFailed]="An ssh request to target server \$2 to stop container \$3 has failed with return code \$4."
declare -r DPLERR_StartContainerFailed=1029
deploy_error_text[$DPLERR_StartContainerFailed]="An ssh request to target server \$2 to start container \$3 has failed with return code \$4."
declare -r DPLERR_ReplDos2Unix=1030
deploy_error_text[$DPLERR_ReplDos2Unix]="Replace Tool stap dos2unix is niet goed beeindigd."
declare -r DPLERR_ReplChmod=1031
deploy_error_text[$DPLERR_ReplChmod]="Replace Tool stap chmod is niet goed beeindigd."
declare -r DPLERR_ReplOpenSSLEnc=1032
deploy_error_text[$DPLERR_ReplOpenSSLEnc]="Replace Tool stap openssl encryption is niet goed beeindigd."
declare -r DPLERR_HandoverDeleteNotOK=1033
deploy_error_text[$DPLERR_HandoverDeleteNotOK]="Handover maakte een deleted.txt file, maar daarin komt lijn nr \$2 voor die NIET met 'OK' begint."
declare -r DPLERR_HandoverDeleteFNameSpace=1034
deploy_error_text[$DPLERR_HandoverDeleteFNameSpace]="Handover maakte een deleted.txt file, maar daarin komt lijn nr \$2 voor met een filename waarin een spatie staat. Dit wordt NIET ondersteund."
declare -r DPLERR_RelMapMissingRelName=1035
deploy_error_text[$DPLERR_RelMapMissingRelName]="De Release mapping file (\$2) heeft lijn nr \$3 waarin geen Release naam waarde staat."
declare -r DPLERR_RelMapMissingRelFolder=1036
deploy_error_text[$DPLERR_RelMapMissingRelFolder]="De Release mapping file (\$2) heeft lijn nr \$3 waarin geen Release folder waarde staat."
declare -r DPLERR_RelMapReleaseNotFound=1037
deploy_error_text[$DPLERR_RelMapReleaseNotFound]="De Release mapping file (\$2) heeft geen lijn die overeenkomt met de gezochte release \$3."
declare -r DPLERR_BulkActionReleaseFolderMissing=1038
deploy_error_text[$DPLERR_BulkActionReleaseFolderMissing]="De specifieke Release folder (\$3) voor omgeving \$2 kon niet gevonden worden."
declare -r DPLERR_BulkActionsMissingBlokfiles=1039
deploy_error_text[$DPLERR_BulkActionsMissingBlokfiles]="De specifieke Release folder zou een subfolder moeten bevatten met de blokfiles. Deze subfolder (\$2) kon niet gevonden worden of er ontbreken blokfiles."
declare -r DPLERR_BulkActionsSyntaxBlokfiles=1040
deploy_error_text[$DPLERR_BulkActionsSyntaxBlokfiles]="Er is een syntaxfout gevonden in blokfile \$2 op lijn \$3."
declare -r DPLERR_BulkActionsDupTicketinBlokfiles=1041
deploy_error_text[$DPLERR_BulkActionsDupTicketinBlokfiles]="Er is ticketnummer (\$2) dat meerdere keren voorkomt in verschillende blokfiles: blok \$3 en blok \$4."
declare -r DPLERR_HandoverConfirmationService=1042
deploy_error_text[$DPLERR_HandoverConfirmationService]="The handover tool function ConfirmationService has failed."
declare -r DPLERR_ScripturaCopyFailed=1043
deploy_error_text[$DPLERR_ScripturaCopyFailed]="De copy operatie voor een Scriptura deploy was niet succesvol. Bronfolder=\$2. Doelfolder=\$3."
declare -r DPLERR_IWSCopyFailed=1044
deploy_error_text[$DPLERR_IWSCopyFailed]="De copy operatie voor een IWS deploy was niet succesvol. Bronfolder=\$2. Doelfolder=\$3."
declare -r DPLERR_MultipleJbossImages=1045
deploy_error_text[$DPLERR_MultipleJbossImages]="Er staan meerdere jboss-versies geinstalleerd in de TmpUnzip-Folder."
declare -r DPLERR_FailedSavingJbossImages=1046
deploy_error_text[$DPLERR_FailedSavingJbossImages]="Het assembly script is gefaald bij het verplaatsen van de jboss folder naar TmpTicketFolder."
declare -r DPLERR_IWSApplyFailed=1047
deploy_error_text[$DPLERR_IWSApplyFailed]="De apply operatie voor een IWS deploy was niet succesvol. Bekijk de output van de apply actie voor meer info."
declare -r DPLERR_IWSApplyTimeout=1048
deploy_error_text[$DPLERR_IWSApplyTimeout]="De apply operatie voor een IWS deploy gaf een timeout. Bekijk de gedeeltelijke output (indien beschikbaar) of contacteer IWS experts (Argenta/Cegeka) voor verdere analyse."
declare -r DPLERR_UntarMissingParam=1049
deploy_error_text[$DPLERR_UntarMissingParam]="Ontbrekende input parameters voor untar-stap."
declare -r DPLERR_UntarInvalidTarFile=1050
deploy_error_text[$DPLERR_UntarInvalidTarFile]="De opgegeven TAR-file=\$2 is niet bestaande of niet leesbaar."
declare -r DPLERR_UntarInvalidDestDir=1051
deploy_error_text[$DPLERR_UntarInvalidDestDir]="De opgegeven destinatie-folder=\$2 is niet bestaande of schrijfbaar."
declare -r DPLERR_UntarFailedWithOverwrite=1052
deploy_error_text[$DPLERR_UntarFailedWithOverwrite]="De untar-operatie voor file=\$2 naar folder=\$3 met overschrijf-optie is gefaald"
declare -r DPLERR_UntarFailedWithoutOverwrite=1053
deploy_error_text[$DPLERR_UntarFailedWithoutOverwrite]="De untar-operatie voor file=\$2 naar folder=\$3 zonder overschrijf-optie is gefaald"
declare -r DPLERR_UntarClearDestinationDir=1054
deploy_error_text[$DPLERR_UntarClearDestinationDir]="Het opkuisen van de destinatie-folder=\$2 is gefaald, terwijl dit wel werd verwacht."
declare -r DPLERR_SavePermissionsMissingParam=1055
deploy_error_text[$DPLERR_SavePermissionsMissingParam]="Ontbrekende input parameter(s) voor savePermissions."
declare -r DPLERR_SavePermissionsInvalidDir=1056
deploy_error_text[$DPLERR_SavePermissionsInvalidDir]="De opgegeven inputfolder=\$2 is niet bestaande of niet leesbaar."
declare -r DPLERR_SavePermissionsInvalidFile=1057
deploy_error_text[$DPLERR_SavePermissionsInvalidFile]="De opgegeven outputfile=\$2 is niet bestaande of niet schrijfbaar."
declare -r DPLERR_SavePermissionsFailed=1058
deploy_error_text[$DPLERR_SavePermissionsFailed]="Het opslagen van de permissie's van folder=\$2 naar file=\$3 is gefaald."
declare -r DPLERR_SetPermissionsMissingParam=1059
deploy_error_text[$DPL_SetPermissionsMissingParam]="Ontbrekende input parameter(s) voor setPermissions."
declare -r DPLERR_SetPermissionsInvalidUser=1060
deploy_error_text[$DPLERR_SetPermissionsInvalidUser]="De opgegeven username=\$2 is niet gekend."
declare -r DPLERR_SetPermissionsInvalidDir=1061
deploy_error_text[$DPLERR_SetPermissionsInvalidDir]="De opgegeven inputfolder=\$2 is niet bestaande of niet leesbaar."
declare -r DPLERR_SetPermissionsFailed=1062
deploy_error_text[$DPLERR_SetPermissionsFailed]="Het wijzigen van de permissies voor file=\$2 voor user=\$3 is gefaald."
declare -r DPLERR_ResetPermissionsMissingParam=1063
deploy_error_text[$DPLERR_ResetPermissionsMissingParam]="Ontbrekende input parameter(s) voor setPermissions."
declare -r DPLERR_ResetPermissionsInvalidDir=1064
deploy_error_text[$DPLERR_ResetPermissionsInvalidDir]="De opgegeven folder=\$2 is niet bestaande of schrijfbaar."
declare -r DPLERR_ResetPermissionsInvalidACL=1065
deploy_error_text[$DPLERR_ResetPermissionsInvalidACL]="De opgegeven ACLFile=\$2 is niet bestaande of niet leesbaar."
declare -r DPLERR_ResetPermissionsFailed=1066
deploy_error_text[$DPLERR_ResetPermissionsFailed]="Het terugzetten van de permissies voor file=\$2 op basis van acl-file=\$3 is gefaald."
declare -r DPLERR_SetPermissionsNewFilesMissingParam=1067
deploy_error_Text[$DPLERR_SetPermissionsNewFilesMissingParam]="Ontbrekende input parameter(s) voor setPermissionsNewFiles."
declare -r DPLERR_SetPermissionsNewFilesInvalidDir=1068
deploy_error_Text[$DPLERR_SetPermissionsNewFilesInvalidDir]="De opgegeven folder=\$2 is niet bestaande of schrijfbaar."
declare -r DPLERR_SetPermissionsNewFilesInvalidList=1069
deploy_error_Text[$DPLERR_SetPermissionsNewFilesInvalidList]="De opgegeven filelist=\$2 is niet bestaande of leesbaar."
declare -r DPLERR_SetPermissionsNewFilesFailed=1070
deploy_error_Text[$DPLERR_SetPermissionsNewFilesFailed]="Het wijzigen van de permissies voor nieuwe file=\$2 volgens de parent-folder is gefaald."
declare -r DPLERR_BackupInvalidDir=1071
deploy_error_Text[$DPLERR_BackupInvalidDir]="De opgegeven filelist=\$2 is niet bestaande of leesbaar."
declare -r DPLERR_BackupFailed=1072
deploy_error_Text[$DPLERR_BackupFailed]="Het nemen van de backup voor ADC=\${2} naar share=\${3} is gefaald"
declare -r DPLERR_RollbackMissingParam=1073
deploy_error_text[$DPLERR_RollbackMissingParam]="Ontbrekende input parameter(s) voor Rollback"
declare -r DPLERR_RollbackInvalidTar=1074
deploy_error_text[$DPLERR_RollbackInvalidTar]="De opgegeven tarfile=\$2 is niet bestaande of niet leesbaar."
declare -r DPLERR_RollbackInvalidDest=1075
deploy_error_text[$DPLERR_RollbackInvalidDest]="De opgegeven destinatie=\$2 is niet bestaande of niet schrijfbaar."
declare -r DPLERR_RollbackFailed=1076
deploy_error_text[$DPLERR_RollbackFailed]="De rollback-stap voor ADC=\${2} van tar=\${3} is gefaald"
declare -r DPLERR_BofPathInvalid=1077
deploy_error_text[$DPLERR_BofPathInvalid]="De deploy-folder \"\${2}\" voor ADC=\${3} bestaat niet."
declare -r DPLERR_TarMissingParam=1078
deploy_error_text[$DPLERR_TarMissingParam]="Ontbrekende input parameters voor tar-stap."
declare -r DPLERR_InvalidTarFolder=1079
deploy_error_text[$DPLERR_InvalidTarFolder]="Geen geldig bron-bestand voor TAR \"\$1\"."
declare -r DPLERR_InvalidDestDir=1080
deploy_error_text[$DPLERR_InvalidDestDir]="Doel-folder  \"\${2}\" is niet geldig of beschrijfbaar."
declare -r DPLERR_tarFailedWithCompress=1081
deploy_error_text[$DPLERR_tarFailedWithCompress]="Aanmaak TAR-bestand \"\${2}\" in folder \"\${3}\" is mislukt."
declare -r DPLERR_ServerCountGt1=1082
deploy_error_text[$DPLERR_ServerCountGt1]="The target server list for this request contains more than 1 target. This is not allowed for this type of ADC."
#### Important: the range starting with DPLERR5000 is reserved for SLAVE originated errors
#### The DPLERR5000- range is specified in the file deploy_slverrorwarns.sh
#### End of DPLERR messages
else
  : ## error list is already loaded
fi

deploy_error() {
local errorcode=$1
local stacktrace=$(caller 0)

re='^[0-9]+$'
if ! [[ $errorcode =~ $re ]] ; then
   echo "error: The parameter for deploy_error was not a valid DPLERR code."
   exit 16
fi

if [ -z "${deploy_error_text[$errorcode]}" ]; then
    echo "An unspecified error code was found: '$errorcode'"
    echo "Stack trace of the error: $stacktrace"
    exit 16
else
    ##eval is nodig om extra parameters in de error message te resolven
    eval 'errorlijn="'${deploy_error_text[$errorcode]}'"'
    echo "Error DPLERR"$errorcode": "${errorlijn}
    echo "Stack trace of the error: $stacktrace"
    exit 16
fi

}

