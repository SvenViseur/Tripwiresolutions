
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

def cli = new CliBuilder(usage: 'civl_activate_schedule_db.groovy ')
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


def default_traceit="0"

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

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

//this.getClass().classLoader.rootLoader.addURL(new File("ojdbc7.jar").toURL())
def db_Url = System.getenv( 'RMC_DB_URL' );
def db_Driver="oracle.jdbc.OracleDriver";
def db_Ora_User=System.getenv( 'RMC_DB_USER' );
def db_Ora_Pass=System.getenv( 'RMC_DB_PASSWORD' );

System.setProperty("oracle.net.tns_admin",System.getenv("TNS_ADMIN"));
def sql = Sql.newInstance(db_Url, db_Ora_User, db_Ora_Pass, db_Driver)

def nbr_session

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

// get all schedule information
def sc_scheds = ((IOdiScenarioScheduleFinder)tme.getFinder(OdiScenarioSchedule.class)).findAll()
def lp_scheds = ((IOdiLoadPlanScheduleFinder)tme.getFinder(OdiLoadPlanSchedule.class)).findAll()

def system_stopped=false

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
   system_stopped=true
} else
{
   println "WARNING: System already started ..."
   system_stopped=true
//   System.exit(0)
}

def pScheduleList

//odiserver=Url.split("/")[3]
odiserver=Url.split("@")[1]


pScheduleList = []

def sql_command

// get the last schedule information from db
sql_command = "select schedule_type_object, schedule_scenario_name, schedule_logical_agent, schedule_schedule_global_id, schedule_status, traceit from civl_rmc.civl_jenkins_scheduler_info where schedule_server = '"+odiserver+"' and schedule_master_user = '"+Master_User+"' and schedule_workrep = '"+WorkRep+"' and schedule_datepart = (select max(schedule_datepart) from civl_rmc.civl_jenkins_scheduler_info where schedule_server = '"+odiserver+"' and schedule_master_user = '"+Master_User+"' and schedule_workrep = '"+WorkRep+"')"

sql.eachRow(sql_command) { row ->
   pScheduleList.add ( [row.schedule_type_object,row.schedule_scenario_name,row.schedule_logical_agent,row.schedule_schedule_global_id,row.schedule_status,row.traceit] )
}

sql.close()

// See if there is a traceIT id

def last_stop_with_traceit=true
def pLastTraceIT_nbr=0

pScheduleList.each() { schedule ->
   if ( schedule[5] == default_traceit ) {
      last_stop_with_traceit=false
   } else {
      pLastTraceIT_nbr=schedule[5]
   }
}

def continue_start_process=false

// If the system was stopped, check if the system was stopped with or without a TraceIT ticket
if ( system_stopped && traceit != "0" && last_stop_with_traceit ) {
   continue_start_process=true
}

if ( system_stopped && traceit == "0" && !last_stop_with_traceit ) {
   continue_start_process=true
}

println "INFO: system_stopped         : "+system_stopped
println "INFO: traceit parameter      : "+traceit
println "INFO: last_stop_with_traceit : "+last_stop_with_traceit
println "INFO: continue_start_process : "+continue_start_process

if ( !continue_start_process )
{
    println "ERROR: ################################################################################"
    println "ERROR: Systeem kan niet opgestart worden volgens de vastgelegde voorwaarden."
    println "ERROR: Laatste stop via traceit id: (indien 0 = NIET via een TraceIT ticket) "+pLastTraceIT_nbr
    println "ERROR: ################################################################################"
    System.exit(1)
}

// Proceed start the system

def pMapList

pMapList = [:]
pMapList = pScheduleList.inject([:]) { map, val -> map[val[3]] = val[4]; map }

sc_scheds.each() { schedule ->
    g_id = schedule.getGlobalId()
    old_stat = pMapList.find{ it.key == g_id }.value

    if ( old_stat != null ) {

       println "scenario: " + schedule.getScenario().getName() + " ==> " + schedule.getGlobalId() + "  ==> " + schedule.getStatus() + " ==> New Stat:::" + old_stat

       if ( old_stat == 'ACTIVE' ) { new_stat = ScheduleStatus.ACTIVE }
       if ( old_stat == 'INACTIVE' ) { new_stat = ScheduleStatus.INACTIVE }

       schedule.setStatus( new_stat )
       tme.persist(schedule)

    }
}

lp_scheds.each() { schedule ->


    g_id = schedule.getGlobalId()
    old_stat = pMapList.find{ it.key == g_id }.value

    if ( old_stat != null ) {

       println "loadplan: " + schedule.getLoadPlan().getName() + " ==>" + schedule.getGlobalId() + " ==> " + schedule.getStatus() + " ==> New Stat:::" + old_stat

       if ( old_stat == 'ACTIVE' ) { new_stat = ScheduleStatus.ACTIVE }
       if ( old_stat == 'INACTIVE' ) { new_stat = ScheduleStatus.INACTIVE }

       schedule.setStatus( new_stat )
       tme.persist(schedule)
    }

}

tm.commit(trans)

def physagents = ((IOdiPhysicalAgentFinder)tme.getFinder(OdiPhysicalAgent.class)).findAll()

physagents.each() { physical_agent ->
   println "INFO: Proces agent: "+ physical_agent.getName()
   url_agent = physical_agent.getURLString()

   RemoteRuntimeAgentInvoker remoteAgentInvoker= new RemoteRuntimeAgentInvoker(url_agent, Odi_User, Odi_Pass.toCharArray());
   remoteAgentInvoker.invokeUpdateSchedules();
}


System.exit(0);

