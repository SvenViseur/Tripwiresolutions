#!/bin/bash


export JAVA_HOME=/c/privatews/resources/java/java/jdk-8u192-windows-x64
export ORACLE_HOME=/c/privatews/resources/odi/ODI122130

export JRE_HOME=$JAVA_HOME/jre

export PATH=$JAVA_HOME/bin:$ORACLE_HOME/OPatch:$PATH

java -version

echo "ORACLE_HOME is set to : ["$ORACLE_HOME"]"

echo "starting inventory:"

opatch lsinventory

# attach inventory
#echo "Attaching inventory"

#cd $ORACLE_HOME/oui/bin
#./attachHome.sh

#Apply patch
echo "applying patch"

ls /e/odi/122130/OPatch -ltr

#cd /c/temp/29205229

# Additional setting:
ulimit -n 3100

#opatch apply

