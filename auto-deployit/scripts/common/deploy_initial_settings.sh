#############################################################
## deploy_initial_settings.sh
##
## Dit script dient enkel om een aantal initiele settings
## in te stellen zodat de autodeploy infrastructuur kan
## werken.
##
## Er zijn twee redenen om een variabele hier een waarde
## te geven:
##   - indien de waarde nodig is VOORDAT de DEPLOYIT
##     settings uit de configuratiefiles gelezen kunnen
##     worden. (bv: de locatie van de jar files want
##     die bepaalt waar de replace tool staat, en die
##     is nodig om de DEPLOYIT settings te lezen)
##   - Om een waarde te initialiseren die later uit de
##     de DEPLOYIT settings zal overschreven worden, maar
##     die intussen al nodig is (bv. DebugLevel)
##
##############################################################

## Algemene settings die al nodig zijn voordat DEPLOYIT
## settings gelezen worden.
DefaultDebugLevel=3
DebugLevel=5
SvnConfigDataFolder="/data/deploy-it/svn_configdata"
ConfigDataFolder="/data/deploy-it/configdata"
BinFolder="/data/deploy-it/bin"


## Initiele settings voor DEPLOYIT
## For scripts, Use the deploy_specific_settings.sh script to adapt
## them to the desired settings.
## To adapt the values, use the placeholders file(s) that will serve
## the relevant values for the environment and ADC.
DeployIT_Debug_Level=3
DeployIT_Use_Draaiboek_stops=0
DeployIT_Check_Ticket_Status=0
DeployIT_JBoss_Autostart_Container=0


## Initiele settings voor Handover en SVN
## Deze wijzen naar PRD servers. Voor tests met SVN/Traceit ACC moet
## functie Set_TraceITACC() aangeroepen worden.
DeployIT_SVN_server="scm"
DeployIT_Handover_HOT_ENV="prd"
DeployIT_Handover_Credentials="handover-tool_settings.conf"


