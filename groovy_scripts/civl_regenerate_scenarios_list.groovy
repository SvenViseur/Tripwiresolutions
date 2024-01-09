import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.generation.support.OdiScenarioGeneratorImpl
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication


println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"


def Url = System.getenv( 'ODI_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Master_User=System.getenv( 'ODI_MASTER_USR' );
def Master_Pass=System.getenv( 'ODI_MASTER_PSW' );
def WorkRep=System.getenv( 'ODI_WORKREP' );
def Odi_User=System.getenv( 'ODI_USR' );
def Odi_Pass=System.getenv( 'ODI_PSW' );

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance  odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication  auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

List objErrList = new ArrayList()

def regen_scenario( String scen_name, odiInstance, List pobjErrList ) {

   ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
   def tm = odiInstance.getTransactionManager()

   try {
     scGenImpl = new OdiScenarioGeneratorImpl(odiInstance)
     scGenImpl.regenerateLatestScenario( scen_name )
     tm.commit(trans)
   } catch (e) {
     pobjErrList.add("===========================================")
     pobjErrList.add(scen_name)
     pobjErrList.add("-------------------------------------------")
     pobjErrList.add(" error message: " + e.getMessage())
     pobjErrList.add("-------------------------------------------")
     e.getStackTrace().each() { eline -> 
        pobjErrList.add("   --> " + eline)
     }
     pobjErrList.add("===========================================")
     println " ----> Error " + scen_name
//     println("Exception catched while creating scenario "+scen_name+" : error : " + e)
     tm.rollback(trans)
		}
}

List all_scenarios = new ArrayList()

System.in.eachLine() { line ->
   scn =  ((IOdiScenarioFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findLatestByName(line)
   if ( scn != null ) {
      all_scenarios.add(scn)
   }
}

//def all_scenarios = ((IOdiScenarioFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findAll()

println "--------------------------------------"
println "Regenerate Scenario's"
println "--------------------------------------"

all_scenarios.each() { scen ->
  println "------------------------------------------------------------------------"
  println scen.getName()
  println "------------------------------------------------------------------------"
  regen_scenario( scen.getName() , odiInstance, objErrList )
}

if (objErrList.size() > 0){

   println "------------------------------------"
   println "---- Error generating scenarios ----"
   println "------------------------------------"

   objErrList.each{ listitem ->
        println listitem
   }
   System.exit(1)
}

println("Process Completed");

System.exit(0)

