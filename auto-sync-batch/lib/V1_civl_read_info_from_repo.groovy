
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.OdiSequence
import oracle.odi.domain.project.OdiVariable
import oracle.odi.domain.project.finder.IOdiFolderFinder
import oracle.odi.domain.project.OdiFolder

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder

import oracle.odi.domain.project.finder.IOdiKMFinder
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.project.finder.IOdiSequenceFinder
import oracle.odi.domain.project.finder.IOdiVariableFinder
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.model.finder.IOdiColumnFinder
import oracle.odi.domain.model.finder.IOdiDataStoreFinder
import oracle.odi.domain.model.OdiDataStore

import oracle.odi.domain.model.OdiModel
import oracle.odi.domain.model.OdiModelFolder
import oracle.odi.domain.model.finder.IOdiModelFolderFinder

import oracle.odi.domain.project.finder.IOdiUserProcedureFinder
import oracle.odi.domain.project.OdiUserProcedure

import oracle.odi.domain.mapping.component.SetComponent
import oracle.odi.domain.mapping.component.DatastoreComponent
import oracle.odi.domain.mapping.component.ExpressionComponent
import oracle.odi.domain.mapping.component.FilterComponent
import oracle.odi.domain.mapping.component.JoinComponent
import oracle.odi.domain.mapping.component.LookupComponent
import oracle.odi.mapping.generation.JoinTable.JoinType
import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.adapter.project.IKnowledgeModule.ProcessingType
import oracle.odi.domain.project.OdiIKM
import oracle.odi.domain.project.OdiLKM
import oracle.odi.domain.topology.OdiContext
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.mapping.expression.MapExpression.ExecuteOnLocation
import oracle.odi.domain.mapping.physical.MapPhysicalNode
import oracle.odi.domain.model.OdiColumn

import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

def DisplayProjectInfo( OdiFolder FolderIn, List InfoList ) {

   FolderIn.getSubFolders().each { fldrDisp ->
     DisplayProjectInfo ( fldrDisp, InfoList )
   }
   
   fldr_struc = FolderIn.getName()
   par_folder=FolderIn.getParentFolder()
   while ( par_folder != null) {
       fldr_struc=par_folder.getName()+"/"+fldr_struc
       par_folder=par_folder.getParentFolder()
   }

   linein = "projectfolder|"+FolderIn.getName()+"|"+FolderIn.getGlobalId()+"|"+fldr_struc 
   InfoList.add(linein)

   all_maps=FolderIn.getMappings()
   for (def map: all_maps){
     linein= "mapping|"+map.getName()+"|"+map.getGlobalId()+"|"+fldr_struc
     println linein
     InfoList.add(linein)
   }
  
   all_pckgs=FolderIn.getPackages()
   for (def pckg: all_pckgs){
     linein="package|"+pckg.getName()+"|"+pckg.getGlobalId()+"|"+fldr_struc
     println linein
     InfoList.add(linein)
   }   

   all_procedures=FolderIn.getUserProcedures()
   for (def procedure: all_procedures){
     linein= "procedure|"+procedure.getName()+"|"+procedure.getGlobalId()+"|"+fldr_struc
     println linein
     InfoList.add(linein)
   }
}

def DisplayProjectFolder( String FolderName, String ProjectName, OdiInstance odiInstance, List InfoList) {
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  def folder_coll = ((IOdiFolderFinder)tme.getFinder(OdiFolder.class)).findByName(FolderName,ProjectName)
  
  folder_coll.each { fldr ->
     DisplayProjectInfo( fldr ,InfoList)
  }

}


def DisplayModelInfo( OdiModelFolder FolderIn , List InfoList) {

   FolderIn.getModelFolders().each { fldrDisp ->
     DisplayModelInfo ( fldrDisp , InfoList)
   }

   fldr_struc = FolderIn.getName()
   par_folder=FolderIn.getParentModelFolder()
   while ( par_folder != null) {
       fldr_struc=par_folder.getName()+"/"+fldr_struc
       par_folder=par_folder.getParentModelFolder()
   }

   linein= "modelfolder|"+FolderIn.getName()+"|"+FolderIn.getGlobalId()+"|"+fldr_struc
   println linein
   InfoList.add(linein)

   all_models=FolderIn.getModels()

   for (def model: all_models){

      linein= "model|"+model.getName()+"|"+model.getGlobalId()+"|"+fldr_struc
      println linein
      InfoList.add(linein)

      all_datastores = model.getDataStores()
      for ( def datastore: all_datastores ) {
         linein= "datastore|"+datastore.getName()+"|"+datastore.getGlobalId()+"|"+model.getName()+"|"+model.getGlobalId()+"|"+fldr_struc
         println linein
         InfoList.add(linein)
     }
   }
}

def DisplayModelFolder( String FolderName, String ProjectName, OdiInstance odiInstance, List InfoList) {
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  def modelFColl = ((IOdiModelFolderFinder)tme.getFinder(OdiModelFolder.class)).findByName(FolderName)

  modelFColl.each { fldr ->
     DisplayModelInfo( fldr , InfoList)
  }
}

def DisplaySequences( String ProjectName, OdiInstance odiInstance, List InfoList) {
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  def SequenceColl = ((IOdiSequenceFinder)tme.getFinder(OdiSequence.class)).findByProject(ProjectName)

  SequenceColl.each { sequence ->
     linein= "sequence|"+sequence.getName()+"|"+sequence.getGlobalId()
     println linein
     InfoList.add(linein)

  }
}

def DisplayVariables( String ProjectName, OdiInstance odiInstance, List InfoList) {
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  def VariableColl = ((IOdiVariableFinder)tme.getFinder(OdiVariable.class)).findByProject(ProjectName)

  VariableColl.each { variable ->
     linein= "variable|"+variable.getName()+"|"+variable.getGlobalId()
     println linein
     InfoList.add(linein)
  }
}

def DisplayScenarioInfo( OdiScenarioFolder FolderIn , List InfoList) {

   FolderIn.getSubFolders().each { fldrDisp ->
     DisplayScenarioInfo ( fldrDisp , InfoList)
   }

   fldr_struc = FolderIn.getName()
   par_folder=FolderIn.getParentScenFolder()
   while ( par_folder != null) {
       fldr_struc=par_folder.getName()+"/"+fldr_struc
       par_folder=par_folder.getParentScenFolder()
   }

   linein= "scenariofolder|"+FolderIn.getName()+"|"+FolderIn.getGlobalId()+"|"+fldr_struc
   println linein
   InfoList.add(linein)

   all_scenarios=FolderIn.getScenarios()

   for (def scenario: all_scenarios){

      linein= "scenario|"+scenario.getName()+"|"+scenario.getGlobalId()+"|"+fldr_struc
      println linein
      InfoList.add(linein)
   }
}

def DisplayScenarios( String FolderName,  OdiInstance odiInstance, List InfoList) {
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  def scenarioFColl = ((IOdiScenarioFolderFinder)tme.getFinder(OdiScenarioFolder.class)).findByName(FolderName)

  scenarioFColl.each { fldr ->
     DisplayScenarioInfo( fldr , InfoList)
  }
}


def DisplayLoadplanInfo( OdiScenarioFolder FolderIn , List InfoList) {

   FolderIn.getSubFolders().each { fldrDisp ->
     DisplayLoadplanInfo ( fldrDisp , InfoList)
   }

   fldr_struc = FolderIn.getName()
   par_folder=FolderIn.getParentScenFolder()
   while ( par_folder != null) {
       fldr_struc=par_folder.getName()+"/"+fldr_struc
       par_folder=par_folder.getParentScenFolder()
   }

   linein= "loadplanfolder|"+FolderIn.getName()+"|"+FolderIn.getGlobalId()+"|"+fldr_struc
   println linein
   InfoList.add(linein)

   all_loadplans=FolderIn.getLoadPlans()

   for (def loadplan: all_loadplans){

      linein= "loadplan|"+loadplan.getName()+"|"+loadplan.getGlobalId()+"|"+fldr_struc
      println linein
      InfoList.add(linein)
   }
}

def DisplayLoadplans( String FolderName,  OdiInstance odiInstance, List InfoList) {
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  def loadplanFColl = ((IOdiScenarioFolderFinder)tme.getFinder(OdiScenarioFolder.class)).findByName(FolderName)

  loadplanFColl.each { fldr ->
     DisplayLoadplanInfo( fldr , InfoList)
  }
}


def cli = new CliBuilder(usage: 'civl_read_info_from_repo.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        p longOpt: 'project', args:1, required: true, 'Project Name'
        f longOpt: 'FolderName', args:1, required: false, 'Folder Name'
        t longOpt: 'FolderType', args:1, required: true, 'Folder Type project|model|scenario|sequence|variable'
        o longOpt: 'OutputFile', args:1, required: false, 'Output File name to append to'
}

def options = cli.parse(args)

println "p:"+options.p
println "f:"+options.f

if(!options){
        return
}

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

typedisp=options.t

List InfoList = new ArrayList()

if (typedisp == "project") {
   DisplayProjectFolder(options.f,options.p, odiInstance, InfoList)
}

if (typedisp == "model") {
   DisplayModelFolder(options.f,options.p, odiInstance, InfoList)
}

if (typedisp == "sequence") {
   DisplaySequences(options.p, odiInstance, InfoList)
}

if (typedisp == "variable") {
   DisplayVariables(options.p, odiInstance, InfoList)
}

if (typedisp == "scenario") {
   DisplayScenarios(options.f, odiInstance, InfoList)
   DisplayLoadplans(options.f, odiInstance, InfoList)
}


if (options.o) {
File flist = new File("/home/oracle/IVL_release/bin/display_info/tmp/"+options.o)
flist.append("")
InfoList.each { listitem ->
flist << listitem+"\n" }
}

