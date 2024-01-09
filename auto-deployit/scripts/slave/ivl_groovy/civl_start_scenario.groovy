import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.runtime.agent.RuntimeAgent
import oracle.odi.runtime.agent.invocation.*
import oracle.odi.runtime.agent.invocation.RemoteRuntimeAgentInvoker
import oracle.odi.runtime.agent.invocation.StartupParams.*
import oracle.odi.runtime.agent.invocation.LoadPlanStartupParams

import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.topology.OdiContext
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.runtime.agent.invocation.ExecutionInfo.SessionStatus
import oracle.odi.runtime.agent.invocation.LoadPlanStatusInfo

import oracle.odi.domain.topology.finder.IOdiLogicalAgentFinder
import oracle.odi.domain.topology.OdiLogicalAgent

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

def cli = new CliBuilder(usage: 'civl_execute_process.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'processFile', args:1, required: false, 'Process Info file'
        p longOpt: 'processInfo', args:1, required: false, 'Process Info: <scenario/loadplan>#context#agent#LogLevel#WaitTillFinished'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

if (!options.f && !options.p) {
   println "no options specified"
   System.exit(1)
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

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

def pMapList
//def odiserver=Url.split("/")[3].replaceAll("PEDR","").replaceAll("1_srv","")

//println odiserver

if (options.f) {
   def File file = new File( options.f );
   pMapList_tmp = ( file as List ).collect { it.split( '#' ) }

   pMapList=pMapList_tmp.findAll { item -> item.size()>1 }
}

//if (options.p) {
//   pMapList = []
//   pMapList.add( options.p.split('#').plus( odiserver ) )
//}


pMapList.each { ProcessInfo ->

   def in_scenario_lp=ProcessInfo[0]
   def in_context=ProcessInfo[1]
   def in_agent=ProcessInfo[2]
   def in_level=ProcessInfo[3]
   def in_sync_param=ProcessInfo[4]

   if (in_sync_param=="N") {
      in_sync=false
   } else {
      in_sync=true
   }


   if ( in_scenario_lp == null || in_context == null || in_agent == null) {
      println options.p
      println "ERROR: No scenario/loadplan / context / agent specified"
      System.exit(1)
   }

   // Zoek eerst de logical agent 
   def LogicalAgent = ((IOdiLogicalAgentFinder)tme.getFinder(OdiLogicalAgent.class)).findByName(in_agent)
   if ( LogicalAgent == null ) {
      println "ERROR: Logical agent not found! =>"+in_agent
      System.exit(1)
   }

   println "INFO: Logical Agent: "+LogicalAgent.getName()

   // Zoek nu de context op
   def context = ((IOdiContextFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiContext.class)).findByCode(in_context)
   if ( context == null ) {
      println "ERROR: context not found by code! =>"+in_context
      System.exit(1)
   }

   // Zoek de physical agent voor die logical agent met de juist context
   def PhysicalAgent = LogicalAgent.getPhysicalAgent(context)

   if ( PhysicalAgent == null )  {
      println "ERROR: Physical agent not found for context ("+in_context+") in logical agent ("+in_agent+")."
      System.exit(1)
   }

   // Zoek het scenario of loadplan

   def run_scenario = ((IOdiScenarioFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findLatestByName(in_scenario_lp)

   def run_loadplan = ((IOdiLoadPlanFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(in_scenario_lp)

   if ( run_scenario == null && run_loadplan == null ) {
      println "ERROR: Process not found by name! =>"+in_scenario_lp
      System.exit(1)
   }

   url_agent = PhysicalAgent.getURLString()
   RemoteRuntimeAgentInvoker remoteAgentInvoker= new RemoteRuntimeAgentInvoker(url_agent, Odi_User, Odi_Pass.toCharArray());

   // If all is ok, run the scenario/loadplan
   if (run_scenario != null) {
      println "INFO: Running scenario: "+run_scenario.getName()

      def props = new Properties();
      def parms = new StartupParams(props);

      scen_name = run_scenario.getName()
      scen_version = run_scenario.getVersion()
      context_code = context.getCode()

      try{
         ExecutionInfo exeInfo = remoteAgentInvoker.invokeStartScenario(scen_name, scen_version, parms, "", context_code, in_level.toInteger(), "" , in_sync, WorkRep)

         if (exeInfo.getSessionStatus() == SessionStatus.ERROR) {
            println "Status => "+exeInfo.getSessionStatus()
            println "Message => "+exeInfo.getStatusMessage()
            println "StatusInRepo =>"+exeInfo.getSessionStatusInRepository()
            System.exit(1)
         }
      }
      catch (e) {
         println("ERROR: Exception catched while running scenario "+run_scenario.getName()+" : error : " + e)
         System.exit(1)
      }
   }

   if (run_loadplan != null) {
      println "INFO: Running Loadplan: "+run_loadplan.getName()

      Map paramsValues = new HashMap();
      Properties lpProps = new Properties();
      LoadPlanStartupParams startupParams = new LoadPlanStartupParams(paramsValues);

      lp_name = run_loadplan.getName()
      context_code = context.getCode()

      try{
         LoadPlanExecutionInfo exeInfo = remoteAgentInvoker.invokeStartLoadPlan(lp_name, context_code, startupParams , '' , WorkRep , lpProps, in_level.toInteger())

         if (in_sync ) {
            still_waiting=true

            while (still_waiting) {
               sleep(5000)

               lpStatInfo=remoteAgentInvoker.invokeGetLoadPlanStatus( [exeInfo.getLoadPlanInstanceId()], [1], WorkRep)

               lpStatInfo.each() { lpstat ->
                  if (lpstat.getLoadPlanRunStatus() != 'R'){
                     if ( lpstat.getLoadPlanRunStatus() == "E") {
                        println "RunMessage => "+lpstat.getLoadPlanRunMessage()
                        println "RunCode => "+lpstat.getLoadPlanRunRC()
                        System.exit(1)
                     }
                     still_waiting = false
                  }
               }
            }
         }
      }
      catch (e) {
         println("ERROR: Exception catched while running loadplan "+run_loadplan.getName()+" : error : " + e)
         System.exit(1)
      }
   }
}

println("Process Completed");
System.exit(0)

