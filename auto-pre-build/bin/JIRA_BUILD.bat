@echo off
set /p id="Enter ID: "

echo "ID => " %id%

set OLD_PATH=%PATH%

set PATH=%PATH%;%CD%;%CD%\groovy\bin
set MAINPATH=%CD%
cd "%MAINPATH%"
cd work_dir
mkdir "%id%"
cd "%id%"

SETLOCAL ENABLEDELAYEDEXPANSION

set tempfile=%id%.tmp2
set propfile=%id%.properties

set p=%propfile%

cls
echo " -------------------------------------------"
echo " --> get data from JIRA for id %id% <-- "

REM Get Ticket Info from JIRA

wsl curl -s -k -u  systemteamesperanto@argenta.be:V1x07D7oyGPEvkIMfIefA0BA -H "Content-Type: application/json" -X GET "https://digiwave.atlassian.net/rest/api/2/search/?jql=%%20issuetype%%20in%%20%%28Story%%2CBug%%2CEnabler%%2CMaintenance%%2CTask%%2CSub-task%%2CProblem%%2CTest%%20Defect%%29%%20AND%%20key%%20%%3D%%20%%22"%id%"%%22&startAt=0&maxResults=1" > %tempfile%

echo " --> execute groovy json conversion <--"
call groovy.bat "%MAINPATH%\JIRA_BUILD.groovy" -f %tempfile% -o %propfile% -t issue -b Y

del "%tempfile%"

set PATH=%OLD_PATH%

cd "%MAINPATH%"

echo " --> Ticket info "%id%" is ready in "%MAINPATH%\work_dir\%id%" directory."
pause

goto :endProcs

:endProcs

