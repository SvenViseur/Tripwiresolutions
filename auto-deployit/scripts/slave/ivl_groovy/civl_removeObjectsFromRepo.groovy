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
import oracle.odi.domain.project.finder.IOdiFolderFinder
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.domain.project.finder.IOdiSequenceFinder
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.mapping.finder.IMappingFinder

import oracle.odi.domain.project.OdiSequence
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.finder.IOdiVariableFinder
import oracle.odi.domain.project.OdiVariable
import oracle.odi.domain.topology.OdiContext

import oracle.odi.domain.mapping.Mapping

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.runtime.scenario.OdiScenario

import oracle.odi.domain.topology.finder.IOdiContextualSchemaMappingFinder
import oracle.odi.domain.topology.OdiPhysicalSchema
import oracle.odi.domain.topology.OdiContextualSchemaMapping
import oracle.odi.domain.topology.finder.IOdiLogicalAgentFinder
import oracle.odi.domain.topology.OdiLogicalAgent
import oracle.odi.domain.topology.finder.IOdiContextualAgentMappingFinder
import oracle.odi.domain.topology.OdiContextualAgentMapping

import oracle.odi.domain.model.OdiDataStore
import oracle.odi.domain.model.finder.IOdiDataStoreFinder

import oracle.odi.domain.model.AbstractOdiSubModel
import oracle.odi.domain.model.OdiReference
import oracle.odi.domain.model.ReferenceColumn
import oracle.odi.domain.model.OdiColumn; 
import oracle.odi.domain.model.OdiKey;
import oracle.odi.domain.model.finder.IOdiReferenceFinder

import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl

import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartImportServiceImpl
import oracle.odi.impexp.support.ImportServiceImpl

import oracle.odi.impexp.IImportService

import groovy.io.FileType
import java.io.File
import java.util.zip.ZipOutputStream
import javax.swing.JOptionPane;
import javax.swing.filechooser.FileFilter
import javax.swing.JFileChooser
import oracle.odi.generation.support.OdiScenarioGeneratorImpl

import org.apache.tools.zip.ZipOutputStream
import org.apache.tools.zip.ZipEntry
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.core.service.deployment.*
import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'removeSessionFromRepo.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'filename', args:1, required: true, 'File DeployArchive (EXEC_ or Full)'
        p longOpt: 'project', args:1, required: true, 'Project name'
        b longOpt: 'backupdir', args:1, required: false, 'Backup Directory name'
}

def options = cli.parse(args)

println "f:"+options.f

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

// Create ZIP file
def zipIt (String pZipArchive, String pZipDir, String pFilesDir, List pFilesToZip ) {
        ByteArrayOutputStream baos = new ByteArrayOutputStream()
        ZipOutputStream zipFile = new ZipOutputStream(baos)
        def filesToZip=pFilesToZip.sort{a,b -> a.getName().compareTo(b.getName())}
        filesToZip.each{
                if( it.isFile() ){
                        zipFile.putNextEntry(new ZipEntry(it.name))
                        it.withInputStream { i -> zipFile << i }
                        zipFile.closeEntry()
                }
        }
        zipFile.finish()

        OutputStream outputStream = new FileOutputStream (pZipDir+"/"+pZipArchive )
        baos.writeTo(outputStream)
        pFilesToZip.each{ it.delete() }
}

def export_to_xml( export_source, pExpDir, odiInstance ) {

        // Export the current version
        def encOpt = new EncodingOptions()
        def Exp2 = new ExportServiceImpl(odiInstance)
        char[] exportKey = 'ThisIsNotUsed0='

        Exp2.exportToXml( export_source ,
                          pExpDir,
                          true,
                          false,
                          encOpt,
                          exportKey,
                          false)
        println " <-- Exported"

}

// REMOVE SCENARIO
def remove_OdiScenario(String pSearchScenarioName, String pSearchProject, odiInstance, String pExpDir, String GUID_Origin) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  OdiScenario sc = ((IOdiScenarioFinder)tme.getFinder(OdiScenario.class)).findLatestByName(pSearchScenarioName)

  try{

    if (sc != null && sc.getName() == pSearchScenarioName) {
     // Check if other version
     if (sc.getGlobalId() != GUID_Origin ) { 
        println "Remove Scenario     "+ sc.getName()

        if ( pExpDir != "" ) {
           export_to_xml( sc, pExpDir, odiInstance )
        }
 
        if ( sc.getScenarioFolder() != null ) {
          // Step 2: Remove from folder
          def fldr=sc.getScenarioFolder()
          fldr.removeScenario(sc);
       }
       // Remove from repository
       tme.remove(sc)
     }else { println "Found but no other version" }
    }else{ println "not found" }
    tm.commit(trans);
  }
  catch (e) {
        print e
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }

}

// REMOVE PACKAGE
def remove_OdiPackage(String pSearchPackageName, String pSearchProject, odiInstance , String pExpDir, String GUID_Origin) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  try{

    def packages = ((IOdiPackageFinder)tme.getFinder(OdiPackage.class)).findByName(pSearchPackageName, pSearchProject)
      
      for (def pkg : packages) {
        // Check if other version
        if (pkg.getGlobalId() != GUID_Origin ) {
          println "Remove Package     "+ pkg.getName()

          if ( pExpDir != "" ) {
             export_to_xml( pkg, pExpDir, odiInstance )
          }

          fldr= pkg.getParentFolder();
          //  Remove from folder
          fldr.removePackage(pkg);
          // Remove from repository
          tme.remove(pkg);
        }else { println "Found but no other version" }
     } 
    tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }

}

// REMOVE SEQUENCE
def remove_OdiSequence(String pSearchSequenceName, String pSearchProject, odiInstance , String pExpDir, String GUID_Origin) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  try{

    def sequence = ((IOdiSequenceFinder)tme.getFinder(OdiSequence.class)).findByName(pSearchSequenceName, pSearchProject)

    if (sequence != null) {
     // Check if other version
     if (sequence.getGlobalId() != GUID_Origin ) {

       println "Remove Sequence    "+ sequence.getName()

       if ( pExpDir != "" ) {
          export_to_xml( sequence, pExpDir, odiInstance )
       }

       def prjct = ((IOdiProjectFinder)tme.getFinder(OdiProject.class)).findByCode(pSearchProject)
       prjct.removeSequence(sequence)
       tme.remove(sequence)
     }else { println "Found but no other version" }
    }
    tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }

}

// REMOVE VARIABLE
def remove_OdiVariable(String pSearchVariableName, String pSearchProject, odiInstance , String pExpDir, String GUID_Origin) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  try{

    def variable = ((IOdiVariableFinder)tme.getFinder(OdiVariable.class)).findByName(pSearchVariableName, pSearchProject)

    if (variable != null) {
     // Check if other version
     if (variable.getGlobalId() != GUID_Origin ) {
       println "Remove Variable     "+ variable.getName()

       if ( pExpDir != "" ) {
          export_to_xml( variable, pExpDir, odiInstance )
       }

       def prjct = ((IOdiProjectFinder)tme.getFinder(OdiProject.class)).findByCode(pSearchProject)
       prjct.removeVariable(variable)
       tme.remove(variable)
     }else { println "Found but no other version" }
    }
    tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }
}

def remove_MapRootContainer(String pSearchMapName, String pSearchProject, odiInstance , String pExpDir, String GUID_Origin) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  try{

    "Processing ... "+pSearchMapName

    def mappings = ((IMappingFinder)tme.getFinder(Mapping.class)).findByName( pSearchMapName, pSearchProject)

    if (mappings == null) {  
       println " not found" 
    } else { println "mappings found: "+mappings.size() }

    for (def mapping : mappings) {
     // Check if other version
     if (mapping.getGlobalId() != GUID_Origin ) {
       println "Remove Mapping     "+ mapping.getName()
       if ( pExpDir != "" ) {
          export_to_xml( mapping, pExpDir, odiInstance )
       }

       odiMapID = mapping.getInternalId()
       // if there are packages with this mapping, the package must be removed also
       def packages = ((IOdiPackageFinder)tme.getFinder(OdiPackage.class)).findByMapping(odiMapID)
       for (def pck_tmp : packages) {
          def pck_tmp_name = pck_tmp.getName()
          println pck_tmp_name
          pck_tmp.getParentFolder().removePackage(pck_tmp);
          ref = tme.findById(OdiPackage.class, pck_tmp.getInternalId())
          tme.remove(ref)
       }
       mapping.getFolder().removeMapping(mapping)
       tme.remove(mapping)
     }else { println "Found but no other version" }
    }
    tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }

}

def removeConstraints(constraint, odiInstance){
	
	ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
	def tm = odiInstance.getTransactionManager() 
        def tme = odiInstance.getTransactionalEntityManager() 
        tme.remove(constraint)	
	tm.commit(trans);
}

def remove_OdiDataStore(String pSearchDSName, String pSearchProject, odiInstance , String pExpDir, String pGlobalId, String pPath) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  try{

    def datastore = ((IOdiDataStoreFinder)tme.getFinder(OdiDataStore.class)).findByGlobalId(pGlobalId)

    print pSearchDSName + "(" + pGlobalId + ")  : "
    if (datastore != null) {
       println  datastore.getGlobalId()
    }else{
       println " not found"
    }

    if (datastore == null) {
      // try to find by name
      def all_datastores = ((IOdiDataStoreFinder)tme.getFinder(OdiDataStore.class)).findAll()
      
      for ( def datastore_list : all_datastores) {
        if ( datastore_list.getName() == pSearchDSName) {
          // Check if it is in the same model/submodel
          tmp_modelFolder = datastore_list.getModel().getParentModelFolder().getName()
          tmp_model = datastore_list.getModel().getName()
          tmp_submodel = datastore_list.getSubModel().getName()
          tmp_check = "/"+tmp_modelFolder+"/"+tmp_model+"/"+tmp_submodel+"/"

          //println "check "+tmp_check
          if ( pPath.contains( tmp_check ) == true ) {
            //println "datastore found "
            //println datastore_list.getName()
            datastore = datastore_list
          }
        }
      }
    }

    if (datastore != null && datastore.getName() == pSearchDSName) {
     // Check if other version
     if (datastore.getGlobalId() != pGlobalId ) {
 
       def submodel = datastore.getSubModel()
       def model = datastore.getModel()

       // Remove all keys
       def all_keys = datastore.getKeys()
       for (def ckey : all_keys) {
          datastore.removeKey( ckey )
       }

       // Remove all the references also
       def refs = ((IOdiReferenceFinder)tme.getFinder(OdiReference.class)).findByPrimaryDataStore(datastore.getDataStoreId())
       for (def ref: refs) {
         //if (ref.getPrimaryDataStore().getGlobalId() == pGlobalId) {
         //println ref.getName()
         //println " P => "+ref.getPrimaryDataStore().getName()+"/"+ref.getPrimaryDataStore().getGlobalId()
         //println " F => "+ref.getForeignDataStore().getName()+"/"+ref.getForeignDataStore().getGlobalId()
         tme.remove(ref)
         //}
       }

       submodel.removeDataStore(datastore)
       tme.remove(datastore)
       println "Datastore "+datastore.getName()+" Removed"
     }else { println "Found but no other version" }
    }
    else
    {
      println "Datastore not found : "+pSearchDSName+"/"+pGlobalId+"/"+pPath
    }
    tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }

}

// REMOVE CONTEXT
def remove_OdiContext(String pSearchContextName, String pSearchProject, odiInstance, String GUID_Origin ) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  try{

    def context = ((IOdiContextFinder)tme.getFinder(OdiContext.class)).findByCode(pSearchContextName.toUpperCase())
    
    if (context != null && context.getCode() == "GLOBAL") {
       println "Remove Context    "+ context.getName()

       def lschema = ((IOdiContextualSchemaMappingFinder)tme.getFinder(OdiContextualSchemaMapping.class)).findByContext(context.getCode())

       lschema.each {
           // println it.getLogicalSchema().getName()
           // println it.getPhysicalSchema().getName()
            tme.remove(it)
        }

       def lagent = ((IOdiContextualAgentMappingFinder)tme.getFinder(OdiContextualAgentMapping.class)).findByContext(context.getCode())
       lagent.each {
            //println it.getLogicalAgent().getName()
            //println it.getPhysicalAgent().getName()
            tme.remove(it)
        }
       tme.remove(context)
    }
    tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
         tm.rollback(trans)
  }

}

// LOGICAL AGENT
def remove_OdiLogicalAgent(String pLogicalAgentName, odiInstance, String pExpDir, String GUID_Origin ) {

  ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()

  try{

       println "Remove Logical Agent    "+ pLogicalAgentName
       def lagent = ((IOdiLogicalAgentFinder)tme.getFinder(OdiLogicalAgent.class)).findByName(pLogicalAgentName)
       if (lagent != null) {
          tme.remove(lagent)
       }
       tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
         tm.rollback(trans)
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
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);


ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

println "Processing file: "+options.f;

def pExpDir
def now = new Date()
pExpDir = ""

if (options.b) {

  pExpDir = options.b+"/ODI_EXP_"+now.format("YYYYMMdd_HHmmss")

  File directory = new File(pExpDir);
  if (! directory.exists()){
      directory.mkdir();
  }
}

DeploymentService dplSrv = new DeploymentService()

def xIDeploymentArchive = dplSrv.getDeploymentArchive(options.f)

def projectname
projectname = options.p;

//Loop 1
//Packages, Scenarios, Sequences

xIDeploymentArchive.getUpdatedObjects() each {
   xClass = it.getType()
   classname = xClass.getSimpleName()
   objname = it.name

   if (classname == "OdiPackage") { 
      println objname + " --> " + classname
      remove_OdiPackage(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
   if (classname == "OdiScenario") { 
      println objname + " --> " + classname
    //Split the name: scenario names are extended with "version 001" in the EXEC_ zip file
      String[] str;
      str = objname.split(' Version ');
      objname = str[0];
      remove_OdiScenario(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
   if (classname == "OdiSequence") { 
       println objname + " --> " + classname
       remove_OdiSequence(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
}

//Loop 2
//Mappings, DataStores
xIDeploymentArchive.getUpdatedObjects() each {
   xClass = it.getType()
   classname = xClass.getSimpleName()
   objname = it.name
//   println objname + " --> " + classname

   if (classname == "MapRootContainer") {
      println objname + " --> " + classname
      remove_MapRootContainer(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
   if (classname == "OdiDataStore") {
      println objname + " --> " + classname
      remove_OdiDataStore(objname, projectname, odiInstance, pExpDir, it.getGlobalId(), it.path);
   };
//   if (classname == "OdiLogicalAgent") {
//       remove_OdiLogicalAgent(objname, odiInstance, pExpDir);
//   };
}

//Loop 3
//Context
//xIDeploymentArchive.getUpdatedObjects() each {
//   xClass = it.getType()
//   classname = xClass.getSimpleName()
//   objname = it.name
//   println objname + " --> " + classname

//   if (classname == "OdiContext") {
//       remove_OdiContext(objname, projectname, odiInstance);
//      println objname + " --> " + classname
//      println "odi context no longer removed !!"
//   };
//}

// Zip content of the backup directory if any

if (options.b) {

   File backup_directory = new File(pExpDir);
   if ( backup_directory.listFiles().size() > 0 ) {
   def filesToZip = []
   new File(pExpDir).eachFileMatch(~/.*\.xml/) { zfile ->
        filesToZip.add(zfile)
   }
   zipIt("ROLLBACK_"+now.format("YYYYMMdd_HHmmss")+".zip", pExpDir, pExpDir, filesToZip)
   }
}

tm.commit(trans)

println "Script exit .. "

