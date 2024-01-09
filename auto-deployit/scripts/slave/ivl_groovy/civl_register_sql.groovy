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

def cli = new CliBuilder(usage: 'civl_register_sql.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        fd longOpt: 'name_sql_detail', args:1, required: true, 'Name of the sql detail file'
        t longOpt: 'traceit', args:1, required: true, 'TraceIT ticket id (if known, else 0)'
        r longOpt: 'runid', args:1, required: true, 'Run ID mbt auto-deploy'
}

def options = cli.parse(args)

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

def File file_detail = new File(options.fd);
def pMapList
def pTraceIT=options.t
def pRunID=options.r

List paramList = new ArrayList()

if ( file_detail.exists() ) {
   pMapList = ( file_detail as List).collect { it.split('\\|') }

   pMapList.each() { item ->

   paramList = []
   paramList.add( item[1] )
   paramList.add( item[0] )
   paramList.add( pTraceIT )
   paramList.add( item[2] )
   paramList.add( item[3] )
   paramList.add( item[4] )
   paramList.add( item[5] )
   paramList.add( pRunID )

   def x=sql.call('{ CALL CIVL_RMC.RMC_LOG_INSTALLATION.P_LOG_BUILD_SQL_DETAIL( :p_build_id, :p_jira_ticket, :p_traceit_ticket_id, :p_project, :p_sqlfilename, :p_sqltype, :p_sqlobject, :p_deployid) }', paramList)

   }
}
sql.close()

