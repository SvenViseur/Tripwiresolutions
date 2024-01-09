import oracle.odi.domain.marker.finder.IOdiMarkerGroupFinder
import oracle.odi.domain.marker.OdiMarkerGroup
import oracle.odi.domain.model.finder.IOdiModelFolderFinder
import oracle.odi.domain.model.OdiModelFolder
import oracle.odi.domain.project.OdiSequence
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.project.OdiFolder
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.OdiKM
import oracle.odi.domain.project.OdiVariable
import oracle.odi.domain.project.finder.IOdiFolderFinder
import oracle.odi.domain.project.finder.IOdiKMFinder
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.domain.project.finder.IOdiSequenceFinder
import oracle.odi.domain.project.finder.IOdiVariableFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl
import oracle.odi.impexp.smartie.impl.SmartImportServiceImpl
import oracle.odi.impexp.support.ImportServiceImpl
import oracle.odi.impexp.IImportService
import java.text.*
import org.apache.tools.zip.ZipOutputStream
import org.apache.tools.zip.ZipEntry

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder

import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan

import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

import oracle.odi.core.repository.WorkRepository.WorkType

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'createDeployArchives.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'listfile', args:1, required: true, 'Filename all folders'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

def Add_Non_Existing_Folders ( List pFolderList, odiInstance ) {
   println "##################################"
   println "INFO: Add non-existing folders ..."
   println "##################################"

   ITransactionStatus trans_import = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
   def tm_import = odiInstance.getTransactionManager()
   def tme_import = odiInstance.getTransactionalEntityManager()

   char[] exportKey = 'ThisIsNotUsed0='

   // Step 1: create non existing folders first
   pFolderList.each() { item ->
     println " .. processing ... ["+item[0]+"]"
     findfolder=((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findByGlobalId( item[1] )
     if (findfolder == null ) {
        println " .... INFO: scenario folder not found: "+item[0]

        // search for the specific xml file
        xml_filename = "SFOL_"+item[0]+".xml"
        xml_location = item[5]

        File file = new File(xml_location+xml_filename)
        // Check if the file exist
        if ( file.exists() ) {

          sImp = new ImportServiceImpl(odiInstance)
          sImp.importObjectFromXml(IImportService.IMPORT_MODE_SYNONYM_INSERT, file.path, false,  exportKey, true )
//          tm_import.commit(trans_import)
          println " .... INFO: File found, importing ... "
        } else {
          println " .... ERROR: file not found: "+file.path
        }
     }
  }
  tm_import.commit(trans_import)
}

def Move_subfolders ( List pFolderList, odiInstance ) {
   println "###################################################"
   println "INFO: Move and rename folders correct structure ..."
   println "###################################################"

   ITransactionStatus trans_move = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
   def tm_move = odiInstance.getTransactionManager()
   def tme_move = odiInstance.getTransactionalEntityManager()

   pFolderList.each() { item ->

     // IF ROOT then search the folder and move to the root if it is still a sub-direcotry

     if ( item[3] == "ROOT" ) {
       findfolder=((IOdiScenarioFolderFinder)tme_move.getFinder(OdiScenarioFolder.class)).findByGlobalId( item[1] )
       if (findfolder != null ) {
          if (findfolder.getParentScenFolder() != null) {
             parent_folder=findfolder.getParentScenFolder()
             println " .. remove subfolder ["+item[0]+"] from folder ["+parent_folder.getName()+"]"
             parent_folder.removeSubFolder( findfolder )
          }
          println " .. set name to "+item[0]
          findfolder.setName( item[0] )
       }
     } else {
       findfolder=((IOdiScenarioFolderFinder)tme_move.getFinder(OdiScenarioFolder.class)).findByGlobalId( item[1] )
       if (findfolder != null ) {
          parent_folder=((IOdiScenarioFolderFinder)tme_move.getFinder(OdiScenarioFolder.class)).findByGlobalId( item[4] )
          println " .. move subfolder ["+item[0]+"] to folder ["+parent_folder.getName()+"]"
          parent_folder.addSubFolder( findfolder )
          println " .. set name to ["+item[0]+"]"
          findfolder.setName( item[0] )
       }
     }
   }
   tm_move.commit(trans_move)
}

def Empty_Descriptions ( odiInstance ) {

   println "############################"
   println "INFO: Empty descriptions ..."
   println "############################"

   ITransactionStatus trans_desc_empty = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
   def tm_desc_empty = odiInstance.getTransactionManager()
   def tme_desc_empty = odiInstance.getTransactionalEntityManager()

   def tmpbaseDirs=((IOdiScenarioFolderFinder)tme_desc_empty.getFinder(OdiScenarioFolder.class)).findAll()

   tmpbaseDirs.each() { fldr ->
      fldr.setDescription("")
   }
   tm_desc_empty.commit(trans_desc_empty)
}


def Set_Descriptions ( List pFolderList, odiInstance ) {

   println "##########################"
   println "INFO: Set descriptions ..."
   println "##########################"

   ITransactionStatus trans_desc = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
   def tm_desc = odiInstance.getTransactionManager()
   def tme_desc = odiInstance.getTransactionalEntityManager()

   List pDescList = new ArrayList()

   pFolderList.each() { item ->
      if ( item[2] != "null" ) {
         pDescList.add( [ item[1], item[2] ] )
      }
   }

   pDescList.each() { fldr ->
      findfolder=((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findByGlobalId( fldr[0] )
      if (findfolder != null ) {
        p_desc=findfolder.getDescription()
        if ( p_desc == null ) {
          findfolder.setDescription( fldr[1] )
        } else {
          findfolder.setDescription( p_desc+"\n"+fldr[1] )
        }
      }
   }

   tm_desc.commit(trans_desc)

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

ITransactionStatus trans_global = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
def tm_global = odiInstance.getTransactionManager()
def tme_global = odiInstance.getTransactionalEntityManager()

def File file = new File(options.f);

def tmpfold = ( file as List).collect { it.split('\\|') }

// Sort on level
def pFolderList=tmpfold.sort{ it[7] }

def tmpbaseDirs=((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findAll()

// Step 1: create non existing folders first
Add_Non_Existing_Folders( pFolderList,odiInstance )

// Step 2: move the correct folders to the correct parent folder
Move_subfolders( pFolderList,odiInstance )

// Step 3: empty all the descriptions
Empty_Descriptions (odiInstance)

// Step 4: Set the description to the folder correct

Set_Descriptions ( pFolderList,odiInstance )

tm_global.commit(trans_global)

println "Program finished"


