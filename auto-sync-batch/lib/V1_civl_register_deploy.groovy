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

def cli = new CliBuilder(usage: 'civl_register_deploy.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'name', args:1, required: true, 'Name of the properties file'
        t longOpt: 'TraceIT', args:1, required: true, 'TraceIT Ticket'
        e longOpt: 'environment', args:1, required: true, 'Environment deploy'
        s longOpt: 'Status', args:1, required: true, 'Status Deploy'
        m longOpt: 'message', args:1, required: false, 'Error ID + message'
        r longOpt: 'run_id', args:1, required: true, 'Run ID Jenkins Auto-Deploy'
        u longOpt: 'url_deploy', args:1, required: true, 'Run URL Jenkins Auto-Deploy'
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

def Url = System.getenv( 'RMC_DB_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Ora_User=System.getenv( 'RMC_DB_USER' );
def Ora_Pass=System.getenv( 'RMC_DB_PASSWORD' );

System.setProperty("oracle.net.tns_admin",System.getenv("TNS_ADMIN"));
def sql = Sql.newInstance(Url, Ora_User, Ora_Pass, Driver)
//"jdbc:oracle:thin:@XXXXXX:XXXX:XXX", "user", "pwd", "oracle.jdbc.driver.OracleDriver")

def File file_properties = new File(options.f);

def pTraceIT=options.t
def pEnv=options.e
def pStatus=options.s

def pMapList

def pMessage
def pRun_id
def pRun_url

pMessage= ""
pRun_id= options.r
pRun_url= options.u

if (options.m) {
   pMessage=options.m
}

List paramList = new ArrayList()

//   pMapList = ( file as List).collect { it.split(/=/) }.inject([:]) { map, val -> map[val[0].toUpperCase()] = val[1]; map }
   tmp_pMapList = ( file_properties as List).collect { it.split(/=/) }
   tmp_pMapList_new = []
   tmp_pMapList.each() { val -> if ( val.size() == 1 ) { tmp_pMapList_new.add([val[0],null]) } else { tmp_pMapList_new.add(val) } }
   pMapList = [:]
   pMapList = tmp_pMapList_new.inject([:]) { map, val -> map[val[0].toUpperCase()] = val[1]; map }

   def return_val=0

   paramList.add( pMapList.find{ it.key == "BLDR_BUILD_ID" }.value)
   paramList.add( pMapList.find{ it.key == "BLDR_TICKETID" }.value )
   paramList.add( pTraceIT )
   paramList.add( pMapList.find{ it.key == "BLDR_OMGEVING" }.value )
   paramList.add( "D" )
   paramList.add( pEnv )
   paramList.add( pStatus )
   paramList.add( pRun_id )
   paramList.add( pRun_url )
   paramList.add( pMessage )

   def x=sql.call('{ CALL CIVL_RMC.RMC_LOG_INSTALLATION.P_LOG_DEPLOY_ODI( :p_build_id, :p_jira_ticket, :p_traceit_ticket_id, :p_project, :p_jenkins_type, :p_env, :p_status, :p_deployid, :p_url_deploy, :p_message) }', paramList)

sql.close()

