
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
import oracle.odi.domain.runtime.scheduling.ScheduleStatus


try {

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

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

def nbr_session

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()
def SessRT = ((IOdiSessionFinder)tme.getFinder(OdiSession.class)).countByStatus(Status.RUNNING)

def SessCrit = new OdiSessionCriteria()

List aStats = new ArrayList()

aStats.add Status.RUNNING
aStats.add Status.QUEUED
aStats.add Status.WAITING

nbr_session_running=0
nbr_scheduler_active=0

aStats.each {

  SessCrit.setStatuses( it )
  
  def SessRT2 = ((IOdiSessionFinder)tme.getFinder(OdiSession.class)).findByCriteria(SessCrit , 0 )
  //  nbr_session=nbr_session+SessRT2.size()

  SessRT2.each {
    if (it.getAgentName() != "OracleDIAgentRELACC") {
        nbr_session_running=nbr_session_running+1
        print "INFO: .... Session running: "
        print it.getInternalId()
        print " --- "
        print it.getName().padRight(80," ")
        print " --- "
        print it.getAgentName().padRight(20," ")
        print " --- "
        print it.getStatus()
        print " --- "
        if ( it.getParentSessionId() != null ) {
           println "Parent: "+it.getParentSessionId()
        } else {
           println "Main process"
        }
        }
     }
}

def sc_scheds = ((IOdiScenarioScheduleFinder)tme.getFinder(OdiScenarioSchedule.class)).findAll()
sc_scheds.each() { schedule ->

   stat_sc=schedule.getStatus()

   if ( stat_sc == ScheduleStatus.ACTIVE ) {
       println "INFO: .... Scenario schedule actief ==> " + schedule.getScenario().getName() + " on Agent: " + schedule.getLogicalAgentName() + "(" + schedule.getGlobalId() + ") --> " + schedule.getStatus()
       nbr_scheduler_active=nbr_scheduler_active+1
    }
}

def lp_scheds = ((IOdiLoadPlanScheduleFinder)tme.getFinder(OdiLoadPlanSchedule.class)).findAll()
lp_scheds.each() { schedule ->

    stat_sc=schedule.getStatus()

    if ( stat_sc == ScheduleStatus.ACTIVE ) {
       println "INFO: .... Loadplan schedule actief ==> " + schedule.getLoadPlan().getName() + " on Agent: " + schedule.getLogicalAgentName() + "(" + schedule.getGlobalId() + ") --> " + schedule.getStatus()
       nbr_scheduler_active=nbr_scheduler_active+1
    }
}

if ( nbr_session_running > 0 ||  nbr_scheduler_active > 0 ) {
   println "INFO: .... Running sessions : "+nbr_session_running
   println "INFO: .... Schedulers actief: "+nbr_scheduler_active
   System.exit(1);
}

System.exit(0);

} catch(e) {
  println e
  System.exit(2);
}

