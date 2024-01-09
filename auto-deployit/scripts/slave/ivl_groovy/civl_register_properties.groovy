import groovy.sql.Sql
import oracle.odi.core.service.deployment.*
import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*
import java.text.*

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'civl_register_properties.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'name', args:1, required: true, 'Name of the properties file'
        t longOpt: 'traceit', args:1, required: true, 'TraceIT ticket id (if known, else 0)'
        r longOpt: 'runid', args:1, required: true, 'Run ID mbt auto-deploy'
}

def options = cli.parse(args)

println "INFO: f: "+options.f

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

// TNS_ADMIN settings
def tnsAdminFromEnv = System.getenv('TNS_ADMIN');
if (tnsAdminFromEnv != null && !tnsAdminFromEnv.isEmpty()) {
	System.setProperty('oracle.net.tns_admin', tnsAdminFromEnv);
} else {
	System.setProperty('oracle.net.tns_admin', '/cgk/dba/tnsadmin'); // default op Linux
}

//this.getClass().classLoader.rootLoader.addURL(new File("ojdbc7.jar").toURL())
def Url = System.getenv( 'RMC_DB_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Ora_User=System.getenv( 'RMC_DB_USER' );
def Ora_Pass=System.getenv( 'RMC_DB_PASSWORD' );

def sql = Sql.newInstance(Url, Ora_User, Ora_Pass, Driver)
//"jdbc:oracle:thin:@XXXXXX:XXXX:XXX", "user", "pwd", "oracle.jdbc.driver.OracleDriver")

def File file_properties = new File(options.f);

def pMapList

def pTraceit=options.t
def pRunID=options.r

List paramList = new ArrayList()

if ( file_properties.exists() ) { 

//   pMapList = ( file_properties as List).collect { it.split(/=/) }.inject([:]) { map, val -> valx = val[1]?:""; map[val[0].toUpperCase()] = valx; map }
   tmp_pMapList = ( file_properties as List).collect { it.split(/=/) }
   tmp_pMapList_new = []
   tmp_pMapList.each() { val -> if ( val.size() == 1 ) { tmp_pMapList_new.add([val[0],null]) } else { tmp_pMapList_new.add(val) } }
   pMapList = [:]
   pMapList = tmp_pMapList_new.inject([:]) { map, val -> map[val[0].toUpperCase()] = val[1]; map }

   // EST-2139|loadplan|CIVL_LP_TEST_CASE_JENKINS2_LOADPLAN_DO_NOT_EXECUTE|visv|6015fa48-ee1f-4504-886e-e70be45e67f4|2020-02-07 8:48:00|103

   paramList.add( pMapList.find{ it.key == "BLDR_OMGEVING" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TICKETID" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_URL" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TEAM" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_SUMMARY" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_ASSIGNEE" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_PROJECT" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_SOURCE" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_DDL_LIST" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_ODI_LIST" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_STOP_ENV" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_EPIC" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TIPROJECT" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TIRELEASE" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TIPROJECTID" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_RELEASETYPE" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TIADC" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_AUTOBUILD" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_AUTODEPLOYACC" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TIOMSCHRIJVING" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_TITEAM" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_BUILDREQUEST" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_BUILD_ID" }.value)
   paramList.add( pMapList.find{ it.key == "BLDR_TYPESTORY" }.value )
   paramList.add( pMapList.find{ it.key == "BLDR_COMPONENT" }.value )
   paramList.add( pTraceit )
   paramList.add( pRunID )

   def x=sql.call('{ CALL CIVL_RMC.RMC_LOG_INSTALLATION.P_LOG_BUILD_HEADER( :p_Omgeving, :p_TicketID, :p_URL, :p_Team, :p_Summary, :p_Assignee, :p_Project, :p_Source, :p_DDL_List, :p_ODI_List, :p_Stop_Env, :p_Epic, :p_TIProject, :p_TIRelease, :p_TIProjectID, :p_ReleaseType, :p_TIADC, :p_AutoBuild, :p_AutoDeployACC, :p_TIOmschrijving, :p_TITeam, :p_BuildRequest, :p_build_id, :p_issuetype, :p_component, :p_TRACEIT, :p_deployid) }', paramList)

}

sql.close()


