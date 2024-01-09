import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication

import oracle.odi.domain.runtime.session.OdiSession
import oracle.odi.domain.runtime.session.finder.IOdiSessionFinder

import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan

import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanScheduleFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanSchedule

import oracle.odi.domain.runtime.session.Status
import oracle.odi.domain.runtime.session.finder.OdiSessionCriteria


import oracle.odi.domain.topology.finder.IOdiPhysicalAgentFinder
import oracle.odi.domain.topology.OdiPhysicalAgent

import oracle.odi.runtime.agent.invocation.SchedulingInfo

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioScheduleFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioSchedule

import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanScheduleFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanSchedule

import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

import oracle.odi.domain.runtime.scheduling.ScheduleStatus
import oracle.odi.runtime.agent.invocation.RemoteRuntimeAgentInvoker

import groovy.sql.Sql

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'civl_deactivate_schedule_db.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
        t longOpt: 'TraceIT', args:1, required: false, 'TraceIT Ticket'
        r longOpt: 'run_id', args:1, required: false, 'Run ID Jenkins Auto-Deploy'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

def traceit="0"
def deployid=0

if (options.t) {
   traceit = options.t
}

if (options.r) {
   deployid = options.r.toInteger()
}

// Global definitions

def Url = System.getenv( 'ODI_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Master_User=System.getenv( 'ODI_MASTER_USER' );
def Master_Pass=System.getenv( 'ODI_MASTER_PWD' );
def WorkRep=System.getenv( 'ODI_WORKREP' );
def Odi_User=System.getenv( 'ODI_USER' );
def Odi_Pass=System.getenv( 'ODI_PWD' );
// TNS_ADMIN settings
def tnsAdminFromEnv = System.getenv('TNS_ADMIN');
if (tnsAdminFromEnv != null && !tnsAdminFromEnv.isEmpty()) {
	System.setProperty('oracle.net.tns_admin', tnsAdminFromEnv);
} else {
	System.setProperty('oracle.net.tns_admin', '/cgk/dba/tnsadmin'); // default op Linux
}


//this.getClass().classLoader.rootLoader.addURL(new File("ojdbc7.jar").toURL())
def db_Url = System.getenv( 'RMC_DB_URL' );
def db_Driver="oracle.jdbc.OracleDriver";
def db_Ora_User=System.getenv( 'RMC_DB_USER' );
def db_Ora_Pass=System.getenv( 'RMC_DB_PASSWORD' );

def sql = Sql.newInstance(db_Url, db_Ora_User, db_Ora_Pass, db_Driver)

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

def nbr_session

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

List status_schedule = new ArrayList()

inactive_stat = ScheduleStatus.INACTIVE

odiserver=Url.split("@")[1]
Date date = new Date()
String datePart = date.format("yyyyMMddHHmmss")

// Store the current information to the database
def sc_scheds = ((IOdiScenarioScheduleFinder)tme.getFinder(OdiScenarioSchedule.class)).findAll()
def lp_scheds = ((IOdiLoadPlanScheduleFinder)tme.getFinder(OdiLoadPlanSchedule.class)).findAll()

// Check if there is any active
active_state = ScheduleStatus.ACTIVE
number_active=0

sc_scheds.each() { schedule ->
   if ( schedule.getStatus() == ScheduleStatus.ACTIVE ) {number_active=number_active+1 }
}
lp_scheds.each() { schedule ->
   if ( schedule.getStatus() == ScheduleStatus.ACTIVE ) {number_active=number_active+1 }
}

if ( number_active == 0 ) {
   println "WARNING: No active schedulers detected !!!"
   System.exit(0)
}

sc_scheds.each() { schedule ->

   paramList = []
   paramList.add( datePart )
   paramList.add( odiserver )
   paramList.add( Master_User )
   paramList.add( WorkRep )
   paramList.add( Odi_User )
   paramList.add( "scenario" )
   paramList.add( schedule.getScenario().getName() )
   paramList.add( schedule.getGlobalId() )
   paramList.add( schedule.getLogicalAgentName() )
   if ( schedule.getStatus() == ScheduleStatus.ACTIVE ) {
      paramList.add( "ACTIVE" )
   } else {
      paramList.add( "INACTIVE" )
   }
   paramList.add( traceit )
   paramList.add( deployid )

   def x=sql.call('{ CALL CIVL_RMC.RMC_LOG_INSTALLATION.P_LOG_SCHEDULE( :p_datepart, :p_server, :p_master_user, :p_workrep, :p_odi_user, :p_type_object, :p_scenario_name, :p_schedule_global_id, :p_logical_agent, :p_status, :p_traceit, :p_deployid) }', paramList)
}

lp_scheds.each() { schedule ->

   paramList = []
   paramList.add( datePart )
   paramList.add( odiserver )
   paramList.add( Master_User )
   paramList.add( WorkRep )
   paramList.add( Odi_User )
   paramList.add( "loadplan" )
   paramList.add( schedule.getLoadPlan().getName() )
   paramList.add( schedule.getGlobalId() )
   paramList.add( schedule.getLogicalAgentName() )
   if ( schedule.getStatus() == ScheduleStatus.ACTIVE ) {
      paramList.add( "ACTIVE" )
   } else {
      paramList.add( "INACTIVE" )
   }
   paramList.add( traceit )
   paramList.add( deployid )

   def x=sql.call('{ CALL CIVL_RMC.RMC_LOG_INSTALLATION.P_LOG_SCHEDULE( :p_datepart, :p_server, :p_master_user, :p_workrep, :p_odi_user, :p_type_object, :p_scenario_name, :p_schedule_global_id, :p_logical_agent, :p_status, :p_traceit, :p_deployid) }', paramList)
}

sql.close()

// Set them all to INACTIVE

sc_scheds.each() { schedule ->
    status_schedule.add( "scenario|"+schedule.getScenario().getName() + "|" + schedule.getLogicalAgentName() + "|" + schedule.getGlobalId() + "|" + schedule.getStatus() )
    schedule.setStatus(inactive_stat)
    tme.persist(schedule)
}

lp_scheds.each() { schedule ->
   status_schedule.add( "loadplan|"+schedule.getLoadPlan().getName() + "|" + schedule.getLogicalAgentName() + "|" + schedule.getGlobalId() + "|" + schedule.getStatus() )
   schedule.setStatus(inactive_stat)
   tme.persist(schedule)
}

tm.commit(trans);

// Update schedule of the physical agents

def physagents = ((IOdiPhysicalAgentFinder)tme.getFinder(OdiPhysicalAgent.class)).findAll()

physagents.each() { physical_agent ->

   println "INFO: Process agent: "+ physical_agent.getName()
   url_agent = physical_agent.getURLString()

   RemoteRuntimeAgentInvoker remoteAgentInvoker= new RemoteRuntimeAgentInvoker(url_agent, Odi_User, Odi_Pass.toCharArray());
   remoteAgentInvoker.invokeUpdateSchedules();

}

System.exit(0);

