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
import oracle.odi.core.persistence.IOdiEntityManager;
import oracle.odi.core.repository.WorkRepository
import oracle.odi.core.repository.WorkRepository.WorkType

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.model.finder.IOdiModelFinder
import oracle.odi.domain.project.finder.IOdiUserProcedureFinder
import oracle.odi.domain.project.OdiUserProcedure
import oracle.odi.domain.model.finder.IOdiSubModelFinder
import oracle.odi.domain.model.OdiSubModel
import oracle.odi.domain.model.finder.IOdiModelFinder
import oracle.odi.domain.model.OdiModel
import oracle.odi.domain.model.finder.IOdiModelFolderFinder
import oracle.odi.domain.model.OdiModelFolder
import oracle.odi.domain.model.OdiReference
import oracle.odi.domain.model.finder.IOdiReferenceFinder

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

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioScheduleFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioSchedule

import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanScheduleFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanSchedule
import oracle.odi.domain.runtime.scheduling.ScheduleStatus

import oracle.odi.domain.model.OdiModel
import oracle.odi.domain.model.OdiModelFolder
import oracle.odi.domain.model.finder.IOdiModelFolderFinder

import oracle.odi.domain.project.finder.IOdiUserProcedureFinder
import oracle.odi.domain.project.OdiUserProcedure

import oracle.odi.domain.model.finder.IOdiReferenceFinder

import oracle.odi.domain.mapping.component.SetComponent
import oracle.odi.domain.mapping.component.DatastoreComponent
import oracle.odi.domain.mapping.component.ExpressionComponent
import oracle.odi.domain.mapping.component.FilterComponent
import oracle.odi.domain.mapping.component.JoinComponent
import oracle.odi.domain.mapping.component.LookupComponent
import oracle.odi.mapping.generation.JoinTable.JoinType
import oracle.odi.domain.adapter.project.IKnowledgeModule.ProcessingType
import oracle.odi.domain.project.OdiIKM
import oracle.odi.domain.project.OdiLKM
import oracle.odi.domain.topology.OdiContext
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.mapping.expression.MapExpression.ExecuteOnLocation
import oracle.odi.domain.mapping.physical.MapPhysicalNode
import oracle.odi.domain.model.OdiColumn
import oracle.odi.core.repository.WorkRepository.WorkType

type_design=WorkType.DESIGN
type_runtime=WorkType.RUNTIME

import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

def remove_scenario( String scenario_name, String scenario_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_scen = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm_scen = odiInstance.getTransactionManager()
   def tme_scen = odiInstance.getTransactionalEntityManager()

   scen_found=((IOdiScenarioFinder)tme_scen.getFinder(OdiScenario.class)).findByGlobalId( scenario_globalId )

   if ( scen_found != null ){
     try {
        if ( scen_found.getScenarioFolder()  !=  null ) {
          def fldr_tmp=scen_found.getScenarioFolder()
          fldr_tmp.removeScenario( scen_found );
        }
        tme_scen.remove( scen_found );
        tm_scen.commit( trans_scen );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm_scen.rollback( trans_scen )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}



def remove_schedules_loadplan( OdiLoadPlan lp_found, OdiInstance odiInstance ) {
   ITransactionStatus trans_sched = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   def lp_scheds = ((IOdiLoadPlanScheduleFinder)tme.getFinder(OdiLoadPlanSchedule.class)).findAll()
   lp_scheds.each() { schedule ->
      if ( schedule.getLoadPlan().getName()==lp_found.getName()){
         tme.remove( schedule )
      }
   }
   tm.commit( trans_sched )
}

def remove_loadplan( String lp_name, String lp_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_lp = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   lp_found=((IOdiLoadPlanFinder)tme.getFinder(OdiLoadPlan.class)).findByGlobalId( lp_globalId )

   if ( lp_found != null ){
     try {

println lp_found.getName()

        remove_schedules_loadplan( lp_found, odiInstance )

        if ( lp_found.getScenarioFolder()  !=  null ) {
          def fldr_tmp=lp_found.getScenarioFolder()
          fldr_tmp.removeLoadPlan( lp_found );
        }
        tme.remove( lp_found );
        tm.commit( trans_lp );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_lp )
        println ( e );
      }
   } else
   {
     println "   not found"
   }
}

def remove_scenfolder( String fldr_name, String fldr_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_scenfolder  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   fldr_found=((IOdiScenarioFolderFinder)tme.getFinder(OdiScenarioFolder.class)).findByGlobalId( fldr_globalId )

   if ( fldr_found != null ){
     try {
        tme.remove( fldr_found );
        tm.commit( trans_scenfolder );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_scenfolder )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}

def remove_OdiPackage(String pSearchPackageName, String pSearchGlobalId, String pSearchProject, odiInstance) {

   ITransactionStatus trans  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

  try{

    def packages = ((IOdiPackageFinder)tme.getFinder(OdiPackage.class)).findByName(pSearchPackageName, pSearchProject)

      for (def pkg : packages) {
          println "Remove Package     "+ pkg.getName()
          if (pkg.getGlobalId() == pSearchGlobalId) {
             fldr= pkg.getParentFolder()
             println fldr.getName()
             //  Remove from folder
             fldr.removePackage(pkg)
             // Remove from repository
             tme.remove(pkg)
          }
     }
    tm.commit(trans)
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }

}



def old_remove_package(String pSearchPackageName, String pckg_globalId, odiInstance) {

   ITransactionStatus trans_scen = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   packages = ((IOdiPackageFinder)tme.getFinder(OdiPackage.class)).findByGlobalId( pckg_globalId )

   for (def pkg : packages) {
          println "Remove Package     "+ pkg.getName()

          fldr= pkg.getParentFolder();
          //  Remove from folder
          fldr.removePackage(pkg);
          // Remove from repository
          tme.remove(pkg);

     }
    tm.commit(trans_scen);
}

def remove_package( String pckg_name, String pckg_globalId, OdiInstance odiInstance ) {

   ITransactionStatus trans_var  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   try {

   pckg_found=((IOdiPackageFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiPackage.class)).findByGlobalId( pckg_globalId )

   if ( pckg_found != null ) {
      for (def pckg : pckg_found) {
            tmp_folder=pckg.getParentFolder()
            println tmp_folder.getName()
            tmp_folder.removePackage( pckg )
            odiInstance.getTransactionalEntityManager().remove( pckg )
            odiInstance.getTransactionManager().commit(trans_var)
            println "   ok"
         }
   } else
      {
      println "   not found"
      }
   }

   catch( e ) {
      println "   not removed"
      odiInstance.getTransactionManager().rollback( trans_var )
      println ( e )
   }
}

def remove_userprocedure( String procedure_name, String procedure_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_prc  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );

   procedure_found=((IOdiUserProcedureFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiUserProcedure.class)).findByGlobalId( procedure_globalId )

   if ( procedure_found != null ){
     try {
        tmp_folder=procedure_found.getFolder()
        tmp_folder.removeUserProcedure( procedure_found );
        odiInstance.getTransactionalEntityManager().remove( procedure_found );
        odiInstance.getTransactionManager().commit( trans_prc );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        odiInstance.getTransactionManager().rollback( trans_prc )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}


def remove_mapping( String mapp_name, String mapp_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_map  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   mapp_found=((IMappingFinder)tme.getFinder(Mapping.class)).findByGlobalId( mapp_globalId )

   if ( mapp_found != null ){
     try {
        tmp_folder=mapp_found.getFolder()
        tmp_folder.removeMapping( mapp_found );
        odiInstance.getTransactionalEntityManager().remove( mapp_found );
        odiInstance.getTransactionManager().commit( trans_map );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        odiInstance.getTransactionManager().rollback( trans_map )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}


def remove_prjfolder( String fldr_name, String fldr_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_prjfolder  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   fldr_found=((IOdiFolderFinder)tme.getFinder(OdiFolder.class)).findByGlobalId( fldr_globalId )

   if ( fldr_found != null ){
     try {
        tme.remove( fldr_found );
        tm.commit( trans_prjfolder );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_prjfolder )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}


def remove_variable( String var_name, String var_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_var  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   var_found=((IOdiVariableFinder)tme.getFinder(OdiVariable.class)).findByGlobalId( var_globalId )

   if ( var_found != null ){
     try {
        var_found.getProject().removeVariable( var_found );
        tme.remove( var_found );
        tm.commit( trans_var );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_var )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}


def remove_sequence( String seq_name, String seq_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_seq  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   seq_found=((IOdiSequenceFinder)tme.getFinder(OdiSequence.class)).findByGlobalId( seq_globalId )
   if ( seq_found != null ){
     try {
        seq_found.getProject().removeSequence( seq_found );
        tme.remove( seq_found );
        tm.commit( trans_seq );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_seq )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}


def removeConstraints(pProject, pModel){

        ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
        def tm = odiInstance.getTransactionManager()
        def tme = odiInstance.getTransactionalEntityManager()

        odiModel = ((IOdiModelFinder)tme.getFinder(OdiModel.class)).findByCode(pModel)
        def odiDatastores = odiModel.getDataStores()

        for (def datastore : odiDatastores) {

                println("..Working on datastore "+ datastore.getName())
                def odiReferences = datastore.getOutboundReferences()

                for (def ref : odiReferences) {
                  println("working on: "+ref.getName())
                  odiInstance.getTransactionalEntityManager().remove(ref)
                }
        }
        for (def datastore : odiDatastores) {

                println("..Working on datastore "+ datastore.getName())
                def odiReferences = datastore.getOutboundRelationships()

                for (def ref : odiReferences) {
                  println("working on: "+ref.getName())
                  odiInstance.getTransactionalEntityManager().remove(ref)
                }
        }
        println("....Commit")
        tm.commit(trans);
}

def remove_modelitem( String item_name, String item_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_modelitem  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   item_found=((IOdiDataStoreFinder)tme.getFinder(OdiDataStore.class)).findByGlobalId( item_globalId )

   if ( item_found != null ){
     try {
        // Remove all keys
        def all_keys = item_found.getKeys()
        for ( def ckey : all_keys ) {
          item_found.removeKey( ckey )
        }
        // Remove all the references also
        def refs = ((IOdiReferenceFinder)tme.getFinder(OdiReference.class)).findByPrimaryDataStore( item_found.getDataStoreId() )
        for ( def ref: refs ) {
          tme.remove( ref )
        }
        item_found.getSubModel().removeDataStore( item_found )
        tme.remove( item_found );
        tm.commit( trans_modelitem );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_modelitem )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}

def remove_model( String model_name, String model_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_model  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   model_found=((IOdiModelFinder)tme.getFinder(OdiModel.class)).findByGlobalId( model_globalId )

   if ( model_found != null ){
     try {
        tme.remove( model_found );
        tm.commit( trans_model );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_model )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}

def remove_modelfolder( String modfolder_name, String modfolder_globalId, OdiInstance odiInstance ) {
   ITransactionStatus trans_modelfolder  = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
   def tm = odiInstance.getTransactionManager()
   def tme = odiInstance.getTransactionalEntityManager()

   if ( modfolder_found != null ){
     try {
        tme.remove( modfolder_found );
        tm.commit( trans_modelfolder );
        println "   ok"
     }
        catch( e ) {
        println "   not removed"
        tm.rollback( trans_modelfolder )
        println ( e );
     }
   } else
   {
     println "   not found"
   }
}

def Url = System.getenv( 'ODI_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Master_User=System.getenv( 'ODI_MASTER_USER' );
def Master_Pass=System.getenv( 'ODI_MASTER_PWD' );
def WorkRep=System.getenv( 'ODI_WORKREP' );
def Odi_User=System.getenv( 'ODI_USER' );
def Odi_Pass=System.getenv( 'ODI_PWD' );

// Connection
//MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo( Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes() )
//WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo( WorkRep, new PoolingAttributes() )
//OdiInstance odiInstance=OdiInstance.createInstance( new OdiInstanceConfig( masterInfo,workInfo))
//Authentication auth = odiInstance.getSecurityManager().createAuthentication( Odi_User,Odi_Pass.toCharArray() )
//odiInstance.getSecurityManager().setCurrentThreadAuthentication( auth )

def File file = new File("d:\\tmp\\data_delete_04_12_2023.txt");

repo_type=odiInstance.getWorkRepository().getType() 

def workrepType="DVL"
//workrepType="RT"

def pMapList

pMapList = ( file as List ).collect { it.split( '\\|' ) }

List paramList = new ArrayList()

List pListMappings = new ArrayList()
List pListPackages = new ArrayList()
List pListProcedures = new ArrayList()

List pListVariables = new ArrayList()
List pListSequences = new ArrayList()

List pListModel = new ArrayList()
List pListModelItems = new ArrayList()
List pListModelFolder = new ArrayList()

List pListScenarios = new ArrayList()
List pListLoadplans = new ArrayList()

List pListPrjFolders = new ArrayList()
List pListScenFolders = new ArrayList()

pMapList.each { listitem ->

if ( listitem[0]=="mapping" ) { pListMappings.add( listitem ) }
if ( listitem[0]=="package" ) { pListPackages.add( listitem ) }
if ( listitem[0]=="procedure" ) { pListProcedures.add( listitem ) }
if ( listitem[0]=="projectfolder" ) { pListPrjFolders.add( listitem ) }

if ( listitem[0]=="variable" ) { pListVariables.add( listitem ) }
if ( listitem[0]=="sequence" ) { pListSequences.add( listitem ) }

if ( listitem[0]=="modelfolder" ) { pListModelFolder.add( listitem ) }
if ( listitem[0]=="model" ) { pListModel.add( listitem ) }
if ( listitem[0]=="datastore" ) { pListModelItems.add( listitem ) }

if ( listitem[0]=="scenariofolder" ) { pListScenFolders.add( listitem ) }
if ( listitem[0]=="scenario" ) { pListScenarios.add( listitem ) }

if ( listitem[0]=="loadplanfolder" ) { pListScenFolders.add( listitem ) }
if ( listitem[0]=="loadplan" ) { pListLoadplans.add( listitem ) }

}

ITransactionStatus global_trans = odiInstance.getTransactionManager().getTransaction( new DefaultTransactionDefinition() );
def global_tm = odiInstance.getTransactionManager()
def global_tme = odiInstance.getTransactionalEntityManager()

// Info

pListScenarios.each { scenario ->
   scenario_name=scenario[1]
   scenario_globalId= scenario[2]
   disp=scenario_name+"--["+scenario_globalId+"]"
   header="Scenario:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing Loadplans

pListLoadplans.each { loadplan ->
   lp_name=loadplan[1]
   lp_globalId=loadplan[2]
   disp=lp_name+"--["+lp_globalId+"]"
   header="Loadplan:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing Scenario Folders

pListScenFolders.each { scenfolder ->
   fldr_name = scenfolder[1]
   fldr_globalId= scenfolder[2]
   disp=fldr_name+"--["+fldr_globalId+"]"
   header="Scenario Folder:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

////////////////////
//     PROJECT    //
////////////////////

if ( repo_type == type_design  ) {

// Processing procedures
pListProcedures.each { procedure ->
   procedure_name = procedure[1]
   procedure_globalId = procedure[2]
   disp=procedure_name+"--["+procedure_globalId+"]"
   header="Procedure:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing packages
pListPackages.each { pckg ->
   pckg_name = pckg[1]
   pckg_globalId = pckg[2]
   disp=pckg_name+"--["+pckg_globalId+"]"
   header="Package:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}


// Processing mappings
pListMappings.each { mapping ->
   mapp_name=mapping[1]
   mapp_globalId = mapping[2]
   disp=mapp_name+"--["+mapp_globalId+"]"
   header="Mapping:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing variables
pListVariables.each { variable ->
   var_name=variable[1]
   var_globalId=variable[2]
   disp=var_name+"--["+var_globalId+"]"
   header="Variable:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing sequences
pListSequences.each { sequence ->
   seq_name=sequence[1]
   seq_globalId=sequence[2]
   disp=seq_name+"--["+seq_globalId+"]"
   header="Sequence:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing project folders
pListPrjFolders.each { fldr ->
   fldr_name=fldr[1]
   fldr_globalId=fldr[2]
   disp=fldr_name+"--["+fldr_globalId+"]"
   header="Project Folder:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

////////////////////
//     MODEL      //
////////////////////
// Processing Model Items
pListModelItems.each { modelitem ->
   item_name=modelitem[1]
   item_globalId=modelitem[2]
   disp=item_name+"--["+item_globalId+"]"
   header="ModelItem:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing Model
pListModel.each { model ->
   model_name=model[1]
   model_globalId=model[2]
   disp=model_name+"--["+model_globalId+"]"
   header="Model:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

// Processing Model Folders
pListModelFolder.each { modfolder ->
   modfolder_name=modfolder[1]
   modfolder_globalId=modfolder[2]
   disp=modfolder_name+"--["+modfolder_globalId+"]"
   header="ModelFolder:"
   println header.padRight( 20 )+disp.padRight( 130,"-" )
}

}

//System.exit(1)

// Remove now

pListScenarios.each { scenario ->
   scenario_name=scenario[1]
   scenario_globalId= scenario[2]
   disp=scenario_name+"--["+scenario_globalId+"]"
   header="Scenario:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_scenario( scenario_name, scenario_globalId, odiInstance )
}

// Processing Loadplans

pListLoadplans.each { loadplan ->
   lp_name=loadplan[1]
   lp_globalId=loadplan[2]
   disp=lp_name+"--["+lp_globalId+"]"
   header="Loadplan:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_loadplan( lp_name, lp_globalId, odiInstance )
}

// Processing Scenario Folders

pListScenFolders.each { scenfolder ->
   fldr_name = scenfolder[1]
   fldr_globalId= scenfolder[2]
   disp=fldr_name+"--["+fldr_globalId+"]"
   header="Scenario Folder:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_scenfolder( fldr_name, fldr_globalId, odiInstance )
}

////////////////////
//     PROJECT    //
////////////////////

if ( repo_type == type_design ) {

// Processing procedures
pListProcedures.each { procedure ->
   procedure_name = procedure[1]
   procedure_globalId = procedure[2]
   disp=procedure_name+"--["+procedure_globalId+"]"
   header="Procedure:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_userprocedure( procedure_name, procedure_globalId, odiInstance )
}

// Processing packages
pListPackages.each { pckg ->
   pckg_name = pckg[1]
   pckg_globalId = pckg[2]
   disp=pckg_name+"--["+pckg_globalId+"]"
   header="Package:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_package( pckg_name, pckg_globalId, odiInstance)
}

// Processing mappings
pListMappings.each { mapping ->
   mapp_name=mapping[1]
   mapp_globalId = mapping[2]
   disp=mapp_name+"--["+mapp_globalId+"]"
   header="Mapping:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_mapping( mapp_name, mapp_globalId, odiInstance )
}

// Processing variables
pListVariables.each { variable ->
   var_name=variable[1]
   var_globalId=variable[2]
   disp=var_name+"--["+var_globalId+"]"
   header="Variable:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_variable( var_name, var_globalId, odiInstance )
}

// Processing sequences
pListSequences.each { sequence ->
   seq_name=sequence[1]
   seq_globalId=sequence[2]
   disp=seq_name+"--["+seq_globalId+"]"
   header="Sequence:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_sequence( seq_name, seq_globalId, odiInstance )
}

// Processing project folders
pListPrjFolders.each { fldr ->
   fldr_name=fldr[1]
   fldr_globalId=fldr[2]
   disp=fldr_name+"--["+fldr_globalId+"]"
   header="Project Folder:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_prjfolder( fldr_name, fldr_globalId, odiInstance )
}

////////////////////
//     MODEL      //
////////////////////
// Processing Model Items
pListModelItems.each { modelitem ->
   item_name=modelitem[1]
   item_globalId=modelitem[2]
   disp=item_name+"--["+item_globalId+"]"
   header="ModelItem:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_modelitem( item_name, item_globalId, odiInstance )
}

// Processing Model
pListModel.each { model ->
   model_name=model[1]
   model_globalId=model[2]
   disp=model_name+"--["+model_globalId+"]"
   header="Model:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_model( model_name, model_globalId, odiInstance )
}

// Processing Model Folders
pListModelFolder.each { modfolder ->
   modfolder_name=modfolder[1]
   modfolder_globalId=modfolder[2]
   disp=modfolder_name+"--["+modfolder_globalId+"]"
   header="ModelFolder:"
   print header.padRight( 20 )+disp.padRight( 130,"-" )
   remove_modelfolder( modfolder_name, modfolder_globalId, odiInstance )
}
}

println "committing global transactions .... "
global_tm.commit(global_trans)
println "Script exited"
