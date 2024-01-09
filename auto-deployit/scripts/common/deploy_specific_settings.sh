#################################################################
# Set van functies om omgevingspecifieke settings op te halen   #
# ten behoeve van DeployIT zelf. De waarden moeten in principe  #
# uit ConfigIT komen of uit een gelijkwaardige configuratiefile #
# Elke setting die zo beheerd wordt, moet ook via een Log lijn  #
# beschikbaar gesteld worden, zodat we snel kunnen weten wat de #
# actuele settings zijn van DeployIT.                           #
# BELANGRIJK!!! Deze configuratie mag GEEN CREDENTIALS bevatten #
# want alle waarden komen uit leesbare files en worden ook      #
# beschikbaar getsteld voor diagnose redenen.                   #
# credentials moeten via de configdata/credentials files        #
# bekomen worden.                                               #
# Nota over het gebruik van ON_DEPLOYITACC                      #
# Soms moet een setting niet enkel afhangen van de target       #
# omgeving waarnaar gedeployed wordt, maar ook van de           #
# DeployIT omgeving vanwaaruit de deploy gebeurt.               #
# Dan worden settings gebruikt in de vorm van:                  #
# DEPLOYIT_ON_DEPLOYIT<DeplEnv>_<setting>                       #
# Deze setting bestaat dus voor elke DeployIT omgeving apart    #
# en heeft een waarde voor elke target omgeving.                #
# Dit laat bv. toe om op DeployIT ACC een hoger debug level     #
# te gebruiken dan DeployIT SIM of PRD.                         #
# Let wel op! Na toevoeging van bovenstaande variabelen         #
# Moet ook de code uitgebreid worden waarbij de correcte        #
# _ON_DEPLOYIT set gekozen wordt in functie van de huidige      #
# DeployIT engine.                                              #
# De DeployIT engine wordt bepaald via de variabelen van de     #
# vorm DEPLOYIT_SERVER_<hostname>_ENV die als waarden moeten    #
# hebben DEPLOYITXXX.                                           #
#################################################################
# Change history
#################################################################
# dexa # sept/2016   # Toev dynamic file voor hostname type
# dexa # jul/2018    # overzetten van het bestand
#      #             # configdata/bash_deployit_settings.sh naar
#      #             # een inline versie binnenin dit script zelf
#      #             # Het oude bestand wordt dus niet meer
#      #             # gebruikt.
#      #             #
#      #             #
#################################################################


GetDeployITSettings() {
## Determine the settings that DeployIT should use
## Requirements : deploy_replace_tool.sh must be preloaded
## Input:
##      $TmpFld : A temporary folder that may be used
##      $TheEnv : The environment for which to use the settings
##      $TheADC : The ADC for which to use the settings

LogLineDEBUG2 "Call to GetDeployITSettings() with attributes:"
LogLineDEBUG2 "TmpFld=$TmpFld"
LogLineDEBUG2 "TheEnv=$TheEnv"
LogLineDEBUG2 "TmpADC=$TheADC"

Replace_Tool_Defaults

RT_InFolder="$TmpFld/in"
RT_ScanFilter="*"
RT_OutFolder="$TmpFld/out"
RT_OutFolderEnc=""
RT_Env=$TheEnv
RT_ADC=$TheADC
RT_Tmp=$TmpFld/tmp
RT_Cmdb_csv=${ConfigDataFolder}/DEPLOYIT.csv

rm -rf $RT_InFolder
mkdir -p $RT_InFolder
rm -rf $RT_OutFolder
mkdir -p $RT_OutFolder
rm -rf $RT_Tmp
mkdir -p $RT_Tmp

# make the temp file with the settings list
cat > $RT_InFolder/bash_deployit_settings.sh << EOL

DeployIT_Debug_Level=@@DEPLOYIT_DEBUG_LEVEL#@
DeployIT_Use_Draaiboek_stops=@@DEPLOYIT_USE_DRAAIBOEK_STOPS#@
DeployIT_Check_Ticket_Status=@@DEPLOYIT_CHECK_TICKET_STATUS#@
DeployIT_JBoss_Autostart_Container=@@DEPLOYIT_JBOSS_AUTOSTART_CONTAINER#@
DeployIT_Keep_Temporary_Files=@@DEPLOYIT_KEEP_TEMPORARY_FILES#@
DeployIT_Can_Update_Tickets=@@DEPLOYIT_CAN_UPDATE_TICKETS#@
DeployIT_Can_Ssh_To_Appl_Servers=@@DEPLOYIT_CAN_SSH_TO_APPL_SERVERS#@

## DEPLOYIT_STAP constants
DEPLOYIT_STAP_REPL_PUB=@@DEPLOYIT_STAP_REPL_PUB#@
DEPLOYIT_STAP_UPD_TICKET=@@DEPLOYIT_STAP_UPD_TICKET#@
DEPLOYIT_STAP_PREDEPLOY=@@DEPLOYIT_STAP_PREDEPLOY#@
DEPLOYIT_STAP_ACTIVATE=@@DEPLOYIT_STAP_ACTIVATE#@
DEPLOYIT_STAP_RESTART=@@DEPLOYIT_STAP_RESTART#@
DEPLOYIT_STAP_EVAL_TICKET=@@DEPLOYIT_STAP_EVAL_TICKET#@
## DEPLOYIT_STAP DEFAULT en LIMIT values
DEPLOYIT_ON_DEPLOYITACC_STAP_DOEL_DEFAULT=@@DEPLOYIT_ON_DEPLOYITACC_STAP_DOEL_DEFAULT#@
DEPLOYIT_ON_DEPLOYITSIM_STAP_DOEL_DEFAULT=@@DEPLOYIT_ON_DEPLOYITSIM_STAP_DOEL_DEFAULT#@
DEPLOYIT_ON_DEPLOYITPRD_STAP_DOEL_DEFAULT=@@DEPLOYIT_ON_DEPLOYITPRD_STAP_DOEL_DEFAULT#@
DEPLOYIT_ON_DEPLOYITACC_STAP_DOEL_LIMIT=@@DEPLOYIT_ON_DEPLOYITACC_STAP_DOEL_LIMIT#@
DEPLOYIT_ON_DEPLOYITSIM_STAP_DOEL_LIMIT=@@DEPLOYIT_ON_DEPLOYITSIM_STAP_DOEL_LIMIT#@
DEPLOYIT_ON_DEPLOYITPRD_STAP_DOEL_LIMIT=@@DEPLOYIT_ON_DEPLOYITPRD_STAP_DOEL_LIMIT#@

## deploy-it mount point folder names voor JBoss
DEPLOYIT_ON_DEPLOYITACC_MOUNT_POINT_SLAVE=@@DEPLOYIT_ON_DEPLOYITACC_MOUNT_POINT_SLAVE#@
DEPLOYIT_ON_DEPLOYITACC_MOUNT_POINT_TARGET=@@DEPLOYIT_ON_DEPLOYITACC_MOUNT_POINT_TARGET#@
DEPLOYIT_ON_DEPLOYITSIM_MOUNT_POINT_SLAVE=@@DEPLOYIT_ON_DEPLOYITSIM_MOUNT_POINT_SLAVE#@
DEPLOYIT_ON_DEPLOYITSIM_MOUNT_POINT_TARGET=@@DEPLOYIT_ON_DEPLOYITSIM_MOUNT_POINT_TARGET#@
DEPLOYIT_ON_DEPLOYITPRD_MOUNT_POINT_SLAVE=@@DEPLOYIT_ON_DEPLOYITPRD_MOUNT_POINT_SLAVE#@
DEPLOYIT_ON_DEPLOYITPRD_MOUNT_POINT_TARGET=@@DEPLOYIT_ON_DEPLOYITPRD_MOUNT_POINT_TARGET#@

## mount points waar de replace logging mag weggeschreven worden
DEPLOYIT_ON_DEPLOYITACC_MOUNT_POINT_REPLLOG=@@DEPLOYIT_ON_DEPLOYITACC_MOUNT_POINT_REPLLOG#@
DEPLOYIT_ON_DEPLOYITSIM_MOUNT_POINT_REPLLOG=@@DEPLOYIT_ON_DEPLOYITSIM_MOUNT_POINT_REPLLOG#@
DEPLOYIT_ON_DEPLOYITPRD_MOUNT_POINT_REPLLOG=@@DEPLOYIT_ON_DEPLOYITPRD_MOUNT_POINT_REPLLOG#@

## scriptura_templates locaties per omgeving
DEPLOYIT_SCRIPTURA_TARGET_BASE=@@DEPLOYIT_SCRIPTURA_TARGET_BASE#@
DEPLOYIT_SCRIPTURA_TARGET_NODES=@@DEPLOYIT_SCRIPTURA_TARGET_NODES#@

## iws_packages locatie per omgeving
DEPLOYIT_IWS_MOUNT_POINT=@@DEPLOYIT_IWS_MOUNT_POINT#@

## BOF group suffix per omgeving
DEPLOYIT_BOF_GROUP_SUFFIX=@@DEPLOYIT_BOF_GROUP_SUFFIX#@
EOL

# prepare script to send to target server(s)
TmpCmdFile="${RT_InFolder}/dynamicsettings.sh"
rm -f $TmpCmdFile
cat >${TmpCmdFile} << EOL
#!/bin/bash
DEPLOYIT_DYN_ENV=@@DEPLOYIT_SERVER_${HOSTNAME}_ENV#@
EOL

Replace_Tool

if [ ! -e $RT_OutFolder/bash_deployit_settings.sh ]; then
  echo "Replace tool kan DeployIT settings file (static) niet correct verwerken!"
  exit 16
fi
echo "settings code:"
cat $RT_OutFolder/bash_deployit_settings.sh
echo "end of settings code"
source $RT_OutFolder/bash_deployit_settings.sh
if [ ! -e $RT_OutFolder/dynamicsettings.sh ]; then
  echo "Replace tool kan DeployIT settings file (dynamic) niet correct verwerken!"
  exit 16
fi
source $RT_OutFolder/dynamicsettings.sh

##Gebruik dynamic settings
## eval for Stap_Doel
LogLineDEBUG "DEPLOYIT_DYN_ENV=$DEPLOYIT_DYN_ENV"
eval DeployIT_Stap_Doel_Default=\$DEPLOYIT_ON_${DEPLOYIT_DYN_ENV}_STAP_DOEL_DEFAULT
eval DeployIT_Stap_Doel_Limit=\$DEPLOYIT_ON_${DEPLOYIT_DYN_ENV}_STAP_DOEL_LIMIT
## eval for mount points
eval ConfigNfsFolderOnServer=\$DEPLOYIT_ON_${DEPLOYIT_DYN_ENV}_MOUNT_POINT_SLAVE
eval ConfigNfsFolderOnClient=\$DEPLOYIT_ON_${DEPLOYIT_DYN_ENV}_MOUNT_POINT_TARGET
eval ConfigNfsFolderRepllogOnServer=\$DEPLOYIT_ON_${DEPLOYIT_DYN_ENV}_MOUNT_POINT_REPLLOG

## Override obsolete settings
##  $DeployIT_Can_Ssh_To_Appl_Servers werd vervangen door Stap_Doel code
DeployIT_Can_Ssh_To_Appl_Servers=1

## Opkuisen tijdelijke files
rm -f $RT_InFolder/bash_deployit_settings.sh
rm -f $RT_InFolder/dynamicsettings.sh
rmdir $RT_InFolder
rm -f $RT_OutFolder/bash_deployit_settings.sh
rm -f $RT_OutFolder/dynamicsettings.sh
rmdir $RT_OutFolder
rmdir $RT_Tmp

}

EchoDeployITSettings() {

StapDoelToString $DeployIT_Stap_Doel_Default
DeployIT_Stap_Doel_Default_Tekst=$Deploy_Doel_Tekst

StapDoelToString $DeployIT_Stap_Doel_Limit
DeployIT_Stap_Doel_Limit_Tekst=$Deploy_Doel_Tekst

LogLineINFO "DeployIT settings overview:"
LogLineINFO "    Omgeving                           = $TheEnv"
LogLineINFO "    Appl Deploy Component              = $TheADC"
LogLineINFO "    DeployIT_Debug_Level               = $DeployIT_Debug_Level"
LogLineINFO "    DeployIT_Use_Draaiboek_stops       = $DeployIT_Use_Draaiboek_stops"
LogLineINFO "    DeployIT_Check_Ticket_Status       = $DeployIT_Check_Ticket_Status"
LogLineINFO "    DeployIT_JBoss_Autostart_Container = $DeployIT_JBoss_Autostart_Container"
LogLineINFO "    DeployIT_Keep_Temporary_Files      = $DeployIT_Keep_Temporary_Files"
LogLineINFO "    DeployIT_Can_Update_Tickets        = $DeployIT_Can_Update_Tickets"
LogLineINFO "    DeployIT_Can_Ssh_To_Appl_Servers   = $DeployIT_Can_Ssh_To_Appl_Servers"
LogLineINFO "    DeployIT_System_Env                = $DeployIT_System_Env"
LogLineINFO "    DeployIT_Stap_Doel_Default         = $DeployIT_Stap_Doel_Default_Tekst ($DeployIT_Stap_Doel_Default)"
LogLineINFO "    DeployIT_Stap_Doel_Limit           = $DeployIT_Stap_Doel_Limit_Tekst ($DeployIT_Stap_Doel_Limit)"
LogLineINFO "    ConfigNfsFolderOnServer            = $ConfigNfsFolderOnServer"
LogLineINFO "    ConfigNfsFolderOnClient            = $ConfigNfsFolderOnClient"
LogLineINFO "    DEPLOYIT_SCRIPTURA_TARGET_BASE     = $DEPLOYIT_SCRIPTURA_TARGET_BASE"
LogLineINFO "    DEPLOYIT_SCRIPTURA_TARGET_NODES    = $DEPLOYIT_SCRIPTURA_TARGET_NODES"
LogLineINFO "    DEPLOYIT_IWS_MOUNT_POINT           = $DEPLOYIT_IWS_MOUNT_POINT"
LogLineINFO "    DEPLOYIT_BOF_GROUP_SUFFIX          = $DEPLOYIT_BOF_GROUP_SUFFIX"
LogLineINFO "Einde van DeployIT settings."
}


