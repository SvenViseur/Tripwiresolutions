JDBCTest_Defaults() {
## Input:
##          Requires deploy_global_settings to have run
##          No specific varilables
## Output:
##          Sets several $RT_* variables to default values
JCT_JarName="be.argenta.train.tools.jdbc-connection-checker-1.0.1.jar"
JCT_ClassPath="${ConfigNfsFolder}/tools/*"
JCT_CPOracle="modules/com/oracle/main/*"
JCT_TmpFolderBin="/tmp/deploy-it/tools/"
#JCT_JarSource="http://jenkins.argenta.be:8081/jenkins/view/ondersteuning/job/jdbc-connection-checker/be.argenta.train.tools\\\$be.argenta.train.tools.jdbc-connection-checker/lastSuccessfulBuild/artifact/be.argenta.train.tools/be.argenta.train.tools.jdbc-connection-checker/1.0.0/be.argenta.train.tools.jdbc-connection-checker-1.0.0.jar"
JCT_JarSource="http://nexus:8081/nexus/content/repositories/releases/be/argenta/train/tools/be.argenta.train.tools.jdbc-connection-checker/1.0.1/be.argenta.train.tools.jdbc-connection-checker-1.0.1.jar"
#JCT_JavaPrefix="/etc/alternatives/jre_1.8.0/bin/"
JCT_JavaPrefix=""
LogLineDEBUG "Function Call JDBCTest_Defaults completed."
}

JDBCTest_Check() {
## Input:
##    Requires deploy_global_functions to have run for the LogLineXXX functions
##    $JCT_Server         : The server that must be checked
##    $JCT_SudoUser       : The sudo su user to logon to
##    $JCT_DBServer       : The database server to connect to
##    $JCT_DBPort         : The database server port to use
##    $JCT_Database       : The database to connect to on that server
## Output:
##    RC=0  indicates the jdbc connection worked
##    RC=16 indicates a major error.

## Echo input parameters in DEBUG level
LogLineDEBUG "JCT_Server       : $JCT_Server"

## This tool requires 2 jar files, the jdbctestconn.jar and the common-cli.
## Both should be put in the $JCT_TmpFolderBin on the target.
## They can transit via the NfsFolder. The JCT_JarPath and JCT_ClassPath
## assume they are reachable on the target server.
TargetFolder="/tmp"
TmpTicketFolder="/tmp/deploy-it/isrunning/${Userid}"
mkdir -p $TmpTicketFolder

# Two scripts are prepared for execution on each target server:
# Script 1 will issue stop commands
# Script 2 will move current binaries to a backup folder and install the new binaries
TmpCmd1File="${TmpTicketFolder}/JdbcTestConn.sh"
rm $TmpCmd1File
cat >${TmpCmd1File} << EOL
#!/bin/bash
mkdir -p $JCT_TmpFolderBin
cd $JCT_TmpFolderBin
wget $JCT_JarSource
sudo /bin/su - $JCT_SudoUser -c "${JCT_JavaPrefix}java -jar $JCT_TmpFolderBin/$JCT_JarName be.argenta.train.tools.jdbcconncheck.JdbcTestConn -S $JCT_DBServer -P $JCT_DBPort -D $JCT_Database"
EOL
chmod +x ${TmpCmd1File}

$ScpPutCommand $JCT_Server ${TmpCmd1File} ${TargetFolder}/JdbcTestConn.sh
RC=$?
if [ $RC -ne 0 ]; then
  echo "Could not put JdbcTestConn.sh script on target server ${TargetServer}."
  exit 16
fi
$SshCommand $JCT_Server "source ${TargetFolder}/JdbcTestConn.sh"
RC=$?
if [ $RC -ne 0 ]; then
  echo "SSH call to run JdbcTestConn.sh on target server ${TargetServer} failed (RC=$RC)."
  exit 16
fi

$SshCommand $JCT_Server "rm ${TargetFolder}/JdbcTestConn.sh"
$SshCommand $JCT_Server "rm ${JCT_TmpFolderBin}/$JCT_JarName"

LogLineINFO "JDBC Test connection tool has ended."

}
