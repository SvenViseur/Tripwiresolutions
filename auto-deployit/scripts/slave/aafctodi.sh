#### functions declared for automated actions for the ADCs of type ODI/IVL/EDW
##
##
## This module should be included by the autact program that executes the
## user scripts. In this module, 2 things are located:
##   - functions are defined which can execute all types of actions that
##          are specific to these ADCs.
##   - a registration of each function is done to allow the main program
##          to determine which functions to call
##
## !!! The only temporary folder that may be used in this code is TmpFld !!!
## !!! You cannot use TmpTicketFolder as Automatic Actions exist without !!!
## !!! a ticket also, and then they could collide with other actions     !!!
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Sept/2020    # 1.0.0   # initial version
# dexa  # Sept/2020    # 1.0.1   # check aaErrorCode after call LocateSingleFile
#############################################################################

echo "loading functions from aafctodi.sh"

((aaFctCounter++))
aaFctCode[$aaFctCounter]="ODI_START_SCH"
aaFctCall[$aaFctCounter]="aaFctIvlStartScheduler"

((aaFctCounter++))
aaFctCode[$aaFctCounter]="ODI_STOP_SCH"
aaFctCall[$aaFctCounter]="aaFctIvlStopScheduler"

((aaFctCounter++))
aaFctCode[$aaFctCounter]="ODI_CHECK_SESSIONS"
aaFctCall[$aaFctCounter]="aaFctIvlWaitRunningSessions"

((aaFctCounter++))
aaFctCode[$aaFctCounter]="ODI_RUN"
aaFctCall[$aaFctCounter]="aaFctIvlRunProperties"

aaFctIvlPrepare() {
  local curpwd=$(pwd)
  GetIvlInfo
  echo "OdiTgtServer       = '${OdiTgtServer}'"
  echo "OdiTgtLoggingFolder= '${OdiTgtLoggingFolder}'"
  ## ping the ODI server
  ping -c 2 "${OdiTgtServer}" > /dev/null
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI001" "Server ping failed for server ${OdiTgtServer}"
    return
  fi
  ## ping OK, continue testing
  echo "Ping to server $OdiTgtServer was OK."
  ## Do the replace for the remcfg files
  cd $TmpFld
  mkdir "psw"
  mkdir "psw/in"
  mkdir "psw/out"
  cp "$ScriptPath/ivlremcfgodi.sh" "psw/in/"
  cp "$ScriptPath/ivlremgroovy-ivl-generic.conf" "psw/in/"
  Ivl_replace "${TmpFld}/psw/in" "${TmpFld}/psw/out"
  TargetFolder="/tmp/DeployIT_aa_odi_function_${ArgAppl}"
  TheFld=$TargetFolder
  cd $curpwd
}

aaFctIvlSendAndExecute() {
  $SshCommand $OdiTgtServer "rm -rf ${TargetFolder}"
  $SshCommand $OdiTgtServer "mkdir -p ${TargetFolder}"
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI002" "Could not make a tmp folder for automated actions scripts."
    return
  fi
  $ScpPutCommand ${OdiTgtServer} ${TmpCmdFile} "${TargetFolder}/ivlaafunction.sh"
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI003" "Could not create tmp file for automated action script!"
    return
  fi
  $ScpPutCommand ${OdiTgtServer} "${TmpFld}/psw/out/ivlremcfgodi.sh" "${TargetFolder}/ivlremcfgodi.sh"
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI004" "Could not send ivlremcfgodi.sh to ODI server."
    return
  fi
  $ScpPutCommand ${OdiTgtServer} "${TmpFld}/psw/out/ivlremgroovy-ivl-generic.conf" "${TargetFolder}/groovy-ivl-generic.conf"
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI005" "Could not send groovy-ivl-generic.conf to ODI server."
    return
  fi
  $ScpPutCommand ${OdiTgtServer} "${ScriptPath}/ivl_groovy" "${TargetFolder}/groovy"
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI006" "Could not send groovy scripts to ODI server."
    return
  fi
  $ScpPutCommand ${OdiTgtServer} "${ScriptPath}/ivlremaafunctions.sh" "${TargetFolder}/ivlremaafunctions.sh"
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI007" "Could not create tmp file for automated actions on ODI server (ivlremaafunctions.sh)!"
    return
  fi
  if [ ! "$aaFctIvlDatafile1" = "" ]; then
    $ScpPutCommand ${OdiTgtServer} "${aaFctIvlDatafile1}" "${TargetFolder}/datafile1.txt"
    RC=$?
    if [ $RC -ne 0 ]; then
      aaFctError "AAEODI008" "Could not create Datafile1 for automated actions on ODI server!"
      return
    fi
  fi
  if [ ! "$aaFctIvlDatafile2" = "" ]; then
    $ScpPutCommand ${OdiTgtServer} "${aaFctIvlDatafile2}" "${TargetFolder}/datafile2.txt"
    RC=$?
    if [ $RC -ne 0 ]; then
      aaFctError "AAEODI009" "Could not create Datafile2 for automated actions on ODI server!"
      return
    fi
  fi
  $SshCommand $OdiTgtServer "/bin/bash --login ${TargetFolder}/ivlaafunction.sh"
  RC=$?
  if [ $RC -ne 0 ]; then
    aaFctError "AAEODI010" "Errors occured during execution of the ivlaafunction script on ODI server $OdiTgtServer for ADC $TheADC."
    return
  fi
  $SshCommand $OdiTgtServer "rm -rf ${TargetFolder}"
  ## no testing of return code here
  ## local clean up
  cd $TmpFld
  rm -rf psw
}

aaFctIvlStartScheduler() {
  echo "IVL Start Scheduler gevraagd!"
  aaFctIvlPrepare
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  TmpCmdFile="${TmpFld}/ivlaafunction.sh"
  rm -f $TmpCmdFile
  cat > ${TmpCmdFile} << EOL
#!/bin/bash
TheEnv=${TheEnv}
TheFld=${TheFld}
TheADC=${TheADC}
TheTicketNr=${TheTicketNr}
LoggingFolder=${OdiTgtLoggingFolder}
BaseFolder=${TargetFolder}
JenkinsBuildNr="${BUILD_NUMBER}"
JenkinsBuildURL="${BUILD_URL}"
DebugLevel="${DebugLevel}"

source \${BaseFolder}/ivlremaafunctions.sh

DoStartScheduler \${TheEnv} \${TheFld} \${TheADC} \${TheTicketNr} \$JenkinsBuildNr \$JenkinsBuildURL \$DebugLevel

EOL
  chmod +x ${TmpCmdFile}
  aaFctIvlExtraFile=""
  aaFctIvlSendAndExecute
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  rm -f ${TmpCmdFile}
  echo "IVL Start Scheduler gedaan!"
}

aaFctIvlStopScheduler() {
  echo "IVL Stop Scheduler gevraagd!"
  aaFctIvlPrepare
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  TmpCmdFile="${TmpFld}/ivlaafunction.sh"
  rm -f $TmpCmdFile
  cat > ${TmpCmdFile} << EOL
#!/bin/bash
TheEnv=${TheEnv}
TheFld=${TheFld}
TheADC=${TheADC}
TheTicketNr=${TheTicketNr}
LoggingFolder=${OdiTgtLoggingFolder}
BaseFolder=${TargetFolder}
JenkinsBuildNr="${BUILD_NUMBER}"
JenkinsBuildURL="${BUILD_URL}"
DebugLevel="${DebugLevel}"

source \${BaseFolder}/ivlremaafunctions.sh

DoStopScheduler \${TheEnv} \${TheFld} \${TheADC} \${TheTicketNr} \$JenkinsBuildNr \$JenkinsBuildURL \$DebugLevel

EOL
  chmod +x ${TmpCmdFile}
  aaFctIvlExtraFile=""
  aaFctIvlSendAndExecute
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  rm -f ${TmpCmdFile}
  echo "IVL Stop Scheduler gedaan!"
}

aaFctIvlWaitRunningSessions() {
  echo "IVL Wait running sessions gevraagd!"
  aaFctIvlPrepare
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  TmpCmdFile="${TmpFld}/ivlaafunction.sh"
  rm -f $TmpCmdFile
  cat > ${TmpCmdFile} << EOL
#!/bin/bash
TheEnv=${TheEnv}
TheFld=${TheFld}
TheADC=${TheADC}
TheTicketNr=${TheTicketNr}
LoggingFolder=${OdiTgtLoggingFolder}
BaseFolder=${TargetFolder}
JenkinsBuildNr="${BUILD_NUMBER}"
JenkinsBuildURL="${BUILD_URL}"
DebugLevel="${DebugLevel}"

source \${BaseFolder}/ivlremaafunctions.sh

DoWaitRunningSessions \${TheEnv} \${TheFld} \${TheADC} \${TheTicketNr} \$JenkinsBuildNr \$JenkinsBuildURL \$DebugLevel

EOL
  chmod +x ${TmpCmdFile}
  aaFctIvlExtraFile=""
  aaFctIvlSendAndExecute
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  rm -f ${TmpCmdFile}
  echo "IVL Wait Running sessions gedaan!"
}

aaFctIvlRunProperties() {
  echo "IVL Run properties file gevraagd!"
  aaFctIvlPrepare
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi

  LocateSingleFile $aaFctParam1
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  TheScenActions=$TheSingleFile
  LocateSingleFile $aaFctParam2
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  TheTicketInfo=$TheSingleFile
  echo "The parameter files are:"
  echo "  scenactions: $TheScenActions"
  echo "  ticketinfo : $TheTicketInfo"

  TmpCmdFile="${TmpFld}/ivlaafunction.sh"
  rm -f $TmpCmdFile
  cat > ${TmpCmdFile} << EOL
#!/bin/bash
TheEnv=${TheEnv}
TheFld=${TheFld}
TheADC=${TheADC}
TheTicketNr=${TheTicketNr}
LoggingFolder=${OdiTgtLoggingFolder}
BaseFolder=${TargetFolder}
JenkinsBuildNr="${BUILD_NUMBER}"
JenkinsBuildURL="${BUILD_URL}"
DebugLevel="${DebugLevel}"

ScenActions="\${BaseFolder}/datafile1.txt"
TicketInfo="\${BaseFolder}/datafile2.txt"

source \${BaseFolder}/ivlremaafunctions.sh

## Please note that the properties file is sent as
## TheExtraFile.data in the BaseFolder.
## The parameter that is passed is only for logging purposes
DoRunProperties \${TheEnv} \${TheFld} \${TheADC} \${TheTicketNr} \$ScenActions \$TicketInfo \$JenkinsBuildNr \$JenkinsBuildURL \$DebugLevel

EOL
  chmod +x ${TmpCmdFile}
  aaFctIvlDatafile1="$TheScenActions"
  aaFctIvlDatafile2="$TheTicketInfo"
  aaFctIvlSendAndExecute
  if [ ! "$aaErrorCode" = "0" ]; then
    return
  fi
  rm -f ${TmpCmdFile}
  echo "IVL Run Properties file gedaan!"

}

