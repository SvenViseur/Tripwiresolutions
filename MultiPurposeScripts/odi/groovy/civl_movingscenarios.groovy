import java.util.regex.Pattern
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiFolder
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.OdiSequence
import oracle.odi.domain.project.OdiVariable
import oracle.odi.domain.project.StepMapping
import oracle.odi.domain.project.Step
import oracle.odi.domain.project.OdiSequence.SequenceType
import oracle.odi.domain.project.finder.IOdiFolderFinder
import oracle.odi.domain.project.finder.IOdiKMFinder
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.domain.model.finder.IOdiColumnFinder
import oracle.odi.domain.model.finder.IOdiDataStoreFinder
import oracle.odi.domain.model.OdiDataStore
import oracle.odi.domain.mapping.component.DatastoreComponent
import oracle.odi.domain.mapping.component.FilterComponent
import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.adapter.project.IKnowledgeModule.ProcessingType
import oracle.odi.domain.project.OdiIKM
import oracle.odi.domain.project.OdiLKM
import oracle.odi.domain.topology.OdiContext
import oracle.odi.domain.topology.OdiContextualSchemaMapping
import oracle.odi.domain.topology.OdiDataServer
import oracle.odi.domain.topology.OdiLogicalSchema
import oracle.odi.domain.topology.OdiPhysicalSchema
import oracle.odi.domain.topology.OdiTechnology
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.topology.finder.IOdiTechnologyFinder
import oracle.odi.domain.util.ObfuscatedString
import oracle.odi.domain.mapping.expression.MapExpression.ExecuteOnLocation
import oracle.odi.domain.mapping.physical.MapPhysicalNode
import oracle.odi.domain.model.OdiColumn
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.generation.support.OdiScenarioGeneratorImpl

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'civl_movingscenarios.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
        p longOpt: 'project', args:1, required: false, 'Project'
        b longOpt: 'break',  args:1, required: false, 'Break after check folder Uncategorized'
}

def options = cli.parse(args)

//if(!options){
//        return
//}

if(options.h){
        cli.usage()
        return
}

def Url = System.getenv( 'ODI_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Master_User=System.getenv( 'ODI_MASTER_USER' );
def Master_Pass=System.getenv( 'ODI_MASTER_PWD' );
def WorkRep=System.getenv( 'ODI_WORKREP' );
def Odi_User=System.getenv( 'ODI_USER' );
def Odi_Pass=System.getenv( 'ODI_PWD' );

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes())
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes())
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo))
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray())
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth)


ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()


def moveScenarios(pScenFolder, pPatternStr, odiInstance) {
   def scen = ((IOdiScenarioFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findAll()
   def scenFolders = ((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findAll()
   def scenFld;
   def pattern = Pattern.compile(pPatternStr);
   def matcher;

   scenFolders.each {
      if(it.getName().equals(pScenFolder)){
         scenFld = it
         println(".....Working on "+scenFld.getName())
         scen.each {
            if(pPatternStr == "ROOT"){
               //println(it.getScenarioFolder())
               if (it.getScenarioFolder() == null){
                  //println("............Moving scenario "+it.getName() + " to folder  "+scenFld.getName())
                  scenFld.addScenario(it)
               }
            } else {
               matcher = pattern.matcher(it.getName());
               while(matcher.find()) {
                  //println("............Moving scenario "+it.getName() + " to folder  "+scenFld.getName())
                  scenFld.addScenario(it)
               }
            }
         }
      }
   }
}

def moveLoadplans(pScenFolder, pPatternStr, odiInstance) {
   def lp = ((IOdiLoadPlanFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findAll()
   def scenFolders = ((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findAll()
   def lpFld;
   def pattern = Pattern.compile(pPatternStr);
   def matcher;

   scenFolders.each {
      if(it.getName().equals(pScenFolder)){
         lpFld = it
         println(".....Working on "+lpFld.getName())
         lp.each {
            if(pPatternStr == "ROOT"){
               //println(it.getScenarioFolder())
               if (it.getScenarioFolder() == null) {
               //println("............Moving loadplan "+it.getName() + " to folder  "+lpFld.getName())
               lpFld.addLoadPlan(it)
               }
            } else {
               matcher = pattern.matcher(it.getName());
               while(matcher.find()) {
                  //println("............Moving loadplan "+it.getName() + " to folder  "+lpFld.getName())
                  lpFld.addLoadPlan(it)
               }
            }
         }
      }
   }
}

def patternStr
def scenFolder

def scen_process_list = []
def lp_process_list = []
def folder_level_process_list = []

def all_scenFolders = ((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findAll()

all_scenFolders.each() { folder->

  descr = folder.getDescription()
  if ( descr != null ) {

    List lines = descr.split( '\n' )

    lines.each() { line ->

      println " ++++++> "+line

      if (line.count(":") > 1 ) {
        if ( line.startsWith("SCEN") ) {
          scen_process_list.add( [folder.getName(), line.split(":")[1], line.split(":")[2]] )
          println "scen-2"
        }
        if ( line.startsWith("LP") ) {
          lp_process_list.add( [folder.getName(), line.split(":")[1], line.split(":")[2]]  )
          println "lp-2"
        }
      } else {
        if ( line.startsWith("SCEN") ) {
          scen_process_list.add( [folder.getName(), line.split(":")[1], 0] )
          println "scen-0"
        }
        if ( line.startsWith("LP") ) {
          lp_process_list.add( [folder.getName(), line.split(":")[1], 0] )
          println "lp-0"
        }
      }
    }
  }
}

// Sort on the 2nd element
scen_process_list.sort{ it[0] }.sort{ it[2] }.each() {
println it
}

lp_process_list.sort{ it[0] }.sort{ it[2] }.each() {
println it
}

//System.exit(1)

println "----------"
println "scenario's"
println "----------"
scen_process_list.sort{ it[0] }.sort{ it[2] }.each() { proces->
   moveScenarios( proces[0] , proces[1] , odiInstance )
}

println "---------"
println "loadplans"
println "---------"
lp_process_list.sort{ it[0] }.sort{ it[2] }.each() { proces->
   moveLoadplans( proces[0] , proces[1] , odiInstance )
}

tm.commit(trans);


// Check if there are any scenario's/loadplans in the folder Uncategorized
check_folder = ((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findByName("Uncategorized")

check_scenarios = check_folder.getScenarios()
check_loadplans = check_folder.getLoadPlans()

break_if_any=options.b

println "---------------------------"
println "Check Uncategorized folder "
println "---------------------------"


check_scenarios.each() { scen_check->
   println "scenario in folder Uncategorized: " + scen_check.getName()
}

check_loadplans.each() { lp_check->
   println "Loadplan in folder Uncategorized: " + lp_check.getName()
}

if ( check_scenarios.size() > 0 && break_if_any == "Y" ) {
   println "ERROR NAMING CONVENTIONS SCENARIOS !!!"
   System.exit(1)
}

if ( check_scenarios.size() > 0 && break_if_any == "Y" ) {
   println "ERROR NAMING CONVENTIONS LOADPLANS !!!"
   System.exit(1)
}

println("INFO: Process successfully completed........");


