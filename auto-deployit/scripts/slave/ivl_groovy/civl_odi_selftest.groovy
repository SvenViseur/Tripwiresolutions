

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


import oracle.odi.domain.topology.finder.IOdiTechnologyFinder
import oracle.odi.domain.topology.OdiTechnology

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
// TNS_ADMIN settings
def tnsAdminFromEnv = System.getenv('TNS_ADMIN');
if (tnsAdminFromEnv != null && !tnsAdminFromEnv.isEmpty()) {
	System.setProperty('oracle.net.tns_admin', tnsAdminFromEnv);
} else {
	System.setProperty('oracle.net.tns_admin', '/cgk/dba/tnsadmin'); // default op Linux
}

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

// Get all the OracleTechnologies first

List InfoList = new ArrayList()

def all_technologie = ((IOdiTechnologyFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiTechnology.class)).findAll()

for (def technologie : all_technologie) {
  if (technologie.getName() == "Oracle") {
     def all_ds = technologie.getDataServers()
     for (def ds : all_ds) {
         InfoList.add([ds.getName(), ds.getDataServerId()])
     }
  }
}

def physagents = ((IOdiPhysicalAgentFinder)tme.getFinder(OdiPhysicalAgent.class)).findAll()

def return_value=0
def display_list = new ArrayList()

println "Processing ..."

physagents.each() { physical_agent ->
   url_agent = physical_agent.getURLString()

   // Defaults are
   return_isAlive = "No"
   return_DB_ok = "No"

   try {
      try {
         RemoteRuntimeAgentInvoker remoteAgentInvoker= new RemoteRuntimeAgentInvoker(url_agent, Odi_User, Odi_Pass.toCharArray());
         isAlive = remoteAgentInvoker.invokeIsAlive()
         display_list.add( [ physical_agent.getName(), " Is live", "Yes" ] )
      } catch(e) {
        display_list.add( [ physical_agent.getName(), " Is live", "No"  ] )
        return_value = 1
      }

      try {
         RemoteRuntimeAgentInvoker remoteAgentInvoker= new RemoteRuntimeAgentInvoker(url_agent, Odi_User, Odi_Pass.toCharArray());
         InfoList.each() { oraTech ->
            TestDataServer = remoteAgentInvoker.invokeTestDataServer(oraTech[1])
            display_list.add( [ physical_agent.getName(), " Data server: "+oraTech[0] , "Ok"  ] )
         }
      } catch(e) {
        display_list.add( [ physical_agent.getName(), " Data server:" , "Fail"  ] )
        return_value = 1
      }
   } catch(e) { 
     return_value = 1
   }
}

display_list.each() { item->
   println item[0].padRight(40,".")+item[1].padRight(80,"." )+" : "+item[2]
}

println "result value=> "+return_value

System.exit(return_value);

