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

def cli = new CliBuilder(usage: 'civl_register_odi.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        fh longOpt: 'name_odi_header', args:1, required: true, 'Name of the odi header file'
        fd longOpt: 'name_odi_detail', args:1, required: true, 'Name of the odi detail file'
        t longOpt: 'traceit', args:1, required: true, 'TraceIT ticket id (if known, else 0)'
        r longOpt: 'runid', args:1, required: true, 'Run ID mbt auto-deploy'
}

def options = cli.parse(args)

println "INFO: fh: "+options.fh
println "INFO: fd: "+options.fd

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

def File file_header = new File(options.fh);
def File file_detail = new File(options.fd);
def pMapList
def pTraceIT=options.t

List paramList = new ArrayList()

def pRunID=options.r

if ( file_header.exists() ) {
   pMapList = ( file_header as List).collect { it.split('\\|') }

   pMapList.each() { item ->
   
   // EST-2139|loadplan|CIVL_LP_TEST_CASE_JENKINS2_LOADPLAN_DO_NOT_EXECUTE|visv|6015fa48-ee1f-4504-886e-e70be45e67f4|2020-02-07 8:48:00|103

   paramList = []
   paramList.add( item[6] )
   paramList.add( item[0] )
   paramList.add( pTraceIT )
   paramList.add( item[1] )
   paramList.add( item[2] )
   paramList.add( item[3] )
   paramList.add( item[4] )
   paramList.add( item[5] )
   paramList.add( item[7] )
   paramList.add( pRunID )

   def x=sql.call('{ CALL CIVL_RMC.RMC_LOG_INSTALLATION.P_LOG_BUILD_ODI_HEADER( :p_build_id, :p_jira_ticket, :p_traceit_ticket_id, :p_type, :p_name, :p_update_by, :p_global_id, :p_last_update, :p_deployname, :p_deployid) }', paramList)

   }
}

if ( file_detail.exists() ) {
   pMapList = ( file_detail as List).collect { it.split('\\|') }

   pMapList.each() { item ->
   // EST-2139|scenario|CIVL_S_TEST_CASE_JENKINS2_CIVL_M_9001_GG_HEART_BEAT|mapping|TEST_CASE_JENKINS2_CIVL_M_9001_GG_HEART_BEAT|visv|e1d1c2d6-0980-46c4-b72f-c03c2fd676ee|2020-02-07 8:39:00|102

   paramList = []
   paramList.add( item[8] )
   paramList.add( item[0] )
   paramList.add( pTraceIT )
   paramList.add( item[1] )
   paramList.add( item[2] )
   paramList.add( item[3] )
   paramList.add( item[4] )
   paramList.add( item[5] )
   paramList.add( item[6] )
   paramList.add( item[7] )
   paramList.add( item[9] )
   paramList.add( pRunID )


   def x=sql.call('{ CALL CIVL_RMC.RMC_LOG_INSTALLATION.P_LOG_BUILD_ODI_DETAIL( :p_build_id, :p_jira_ticket, :p_traceit_ticket_id, :p_type, :p_name, :p_source_type, :p_source_name, :p_source_update_by, :p_source_global_id, :p_source_last_update, :p_deployname, :p_deployid) }', paramList)

   }
}
sql.close()

