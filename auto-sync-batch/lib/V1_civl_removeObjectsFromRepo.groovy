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
import oracle.odi.domain.project.finder.IOdiUserProcedureFinder
import oracle.odi.domain.mapping.finder.IMappingFinder

import oracle.odi.domain.project.OdiSequence
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.OdiUserProcedure
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
def remove_OdiScenario(String pSearchScenarioName, String pSearchProject, OdiInstance odiInstance, String pExpDir, String GUID_Origin) {

  tm_scen = odiInstance.getTransactionManager()
  tme_scen = odiInstance.getTransactionalEntityManager()
  trans_scen = tm_scen.getTransaction(new DefaultTransactionDefinition());


  OdiScenario sc = ((IOdiScenarioFinder)tme_scen.getFinder(OdiScenario.class)).findLatestByName(pSearchScenarioName)

  try{

    if (sc != null && sc.getName() == pSearchScenarioName) {
     // Check if other version
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
     tme_scen.remove(sc)
    }else{ println "not found" }
    tm_scen.commit(trans_scen);
  }
  catch (e) {
        print e
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm_scen.rollback(trans_scen)
  }

}

// REMOVE PACKAGE
def remove_OdiPackage(String pSearchPackageName, String pSearchProject, OdiInstance odiInstance , String pExpDir, String GUID_Origin) {

  tm_pkg = odiInstance.getTransactionManager()
  tme_pkg = odiInstance.getTransactionalEntityManager()
  trans_pkg = tm_pkg.getTransaction(new DefaultTransactionDefinition());


  try{

    def packages = ((IOdiPackageFinder)tme_pkg.getFinder(OdiPackage.class)).findByName(pSearchPackageName, pSearchProject)
      
      for (def pkg : packages) {
        // Check if other version
        println "Remove Package     "+ pkg.getName()

        if ( pExpDir != "" ) {
          export_to_xml( pkg, pExpDir, odiInstance )
        }

        fldr= pkg.getParentFolder();
        //  Remove from folder
        fldr.removePackage(pkg);
        // Remove from repository
        tme_pkg.remove(pkg);
     } 
    tm_pkg.commit(trans_pkg);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm_pkg.rollback(trans_pkg)
  }

}

// REMOVE PROCEDURE
def remove_OdiProcedure(String pSearchProcedureName, String pSearchProject, OdiInstance odiInstance , String pExpDir, String GUID_Origin) {

  tm_proc = odiInstance.getTransactionManager()
  tme_proc = odiInstance.getTransactionalEntityManager()
  trans_proc = tm_proc.getTransaction(new DefaultTransactionDefinition());

  try{

    def procedures = ((IOdiUserProcedureFinder)tme_proc.getFinder(OdiUserProcedure.class)).findByName(pSearchProcedureName, pSearchProject)

      for (def prc : procedures) {
        // Check if other version
        println "Remove Procedure     "+ prc.getName()

        if ( pExpDir != "" ) {
          export_to_xml( prc, pExpDir, odiInstance )
        }

        fldr= prc.getFolder();
        //  Remove from folder
        fldr.removeUserProcedure(prc);
        // Remove from repository
        tme_proc.remove(prc);
     }
    tm_proc.commit(trans_proc);
  }
  catch (e) {
        println("Exception catched : error : " + e)
//        println("....Rollback work")
//        tm_proc.rollback(trans_proc)
  }

}


// REMOVE SEQUENCE
def remove_OdiSequence(String pSearchSequenceName, String pSearchProject, OdiInstance odiInstance , String pExpDir, String GUID_Origin) {

  tm_seq = odiInstance.getTransactionManager()
  tme_seq = odiInstance.getTransactionalEntityManager()
  trans_seq = tm_seq.getTransaction(new DefaultTransactionDefinition());

  try{

    def sequence = ((IOdiSequenceFinder)tme_seq.getFinder(OdiSequence.class)).findByName(pSearchSequenceName, pSearchProject)

    if (sequence != null) {
     // Check if other version
     println "Remove Sequence    "+ sequence.getName()

     if ( pExpDir != "" ) {
       export_to_xml( sequence, pExpDir, odiInstance )
     }

     def prjct = ((IOdiProjectFinder)tme.getFinder(OdiProject.class)).findByCode(pSearchProject)
     prjct.removeSequence(sequence)
     tme_seq.remove(sequence)
    }
    tm_seq.commit(trans_seq);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm_seq.rollback(trans_seq)
  }

}

// REMOVE VARIABLE
def remove_OdiVariable(String pSearchVariableName, String pSearchProject, OdiInstance odiInstance , String pExpDir, String GUID_Origin) {

  tm = odiInstance.getTransactionManager()
  tme = odiInstance.getTransactionalEntityManager()
  trans = tm.getTransaction(new DefaultTransactionDefinition());

  try{

    def variable = ((IOdiVariableFinder)tme.getFinder(OdiVariable.class)).findByName(pSearchVariableName, pSearchProject)

    if (variable != null) {
     // Check if other version
     println "Remove Variable     "+ variable.getName()

     if ( pExpDir != "" ) {
       export_to_xml( variable, pExpDir, odiInstance )
     }

     def prjct = ((IOdiProjectFinder)tme.getFinder(OdiProject.class)).findByCode(pSearchProject)
     prjct.removeVariable(variable)
     tme.remove(variable)
    }
    tm.commit(trans);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
  }
}

def remove_MapRootContainer(String pSearchMapName, String pSearchProject, OdiInstance odiInstance , String pExpDir, String GUID_Origin) {

  tm_map = odiInstance.getTransactionManager()
  tme_map = odiInstance.getTransactionalEntityManager()
  trans_map = tm_map.getTransaction(new DefaultTransactionDefinition());

  try{

    "Processing ... "+pSearchMapName

    def mappings = ((IMappingFinder)tme_map.getFinder(Mapping.class)).findByName( pSearchMapName, pSearchProject)

    if (mappings == null) {  
       println " not found" 
    } else { println "mappings found: "+mappings.size() }

    for (def mapping : mappings) {
     // Check if other version
     println "Remove Mapping     "+ mapping.getName()
     if ( pExpDir != "" ) {
       export_to_xml( mapping, pExpDir, odiInstance )
     }

     odiMapID = mapping.getInternalId()
     // if there are packages with this mapping, the package must be removed also
     def packages = ((IOdiPackageFinder)tme_map.getFinder(OdiPackage.class)).findByMapping(odiMapID)
     for (def pck_tmp : packages) {
       def pck_tmp_name = pck_tmp.getName()
       println "Package name : " + pck_tmp_name
       ref = tme_map.findById(OdiPackage.class, pck_tmp.getInternalId())

       pck_tmp.getParentFolder().removePackage(pck_tmp);
       tme_map.remove(pck_tmp)
     }
     map_folder=mapping.getFolder()
     mapping.getFolder().removeMapping(mapping)

     tme_map.remove(mapping)
    }
    tm_map.commit(trans_map);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm_map.rollback(trans_map)
  }

}

def removeConstraints(constraint, odiInstance){

   tm_cons = odiInstance.getTransactionManager() 
   tme_cons = odiInstance.getTransactionalEntityManager() 
   trans_cons = tm_cons.getTransaction(new DefaultTransactionDefinition());

   tme_cons.remove(constraint);
   tm_cons.commit(trans);
}

def remove_OdiDataStore(String pSearchDSName, String pSearchProject, OdiInstance odiInstance , String pExpDir, String pGlobalId, String pPath) {

  tm_ds = odiInstance.getTransactionManager()
  tme_ds = odiInstance.getTransactionalEntityManager()
  trans_ds = tm_ds.getTransaction(new DefaultTransactionDefinition());

  try{

    def datastore = ((IOdiDataStoreFinder)tme_ds.getFinder(OdiDataStore.class)).findByGlobalId(pGlobalId)

    print pSearchDSName + "(" + pGlobalId + ")  : "

    if (datastore != null) {
      println " found -> "+ datastore.getName()
    }else{
      println " not found ... searching by Name"

      // try to find by name
      def all_datastores = ((IOdiDataStoreFinder)tme_ds.getFinder(OdiDataStore.class)).findAll()

      for ( def datastore_list : all_datastores) {
        if ( datastore_list.getName() == pSearchDSName) {
          // Check if it is in the same model/submodel
          //tmp_modelFolder = datastore_list.getModel().getParentModelFolder().getName()
          tmp_model = datastore_list.getModel().getName()
          tmp_submodel = datastore_list.getSubModel().getName()
          tmp_check = "/"+tmp_model+"/"+tmp_submodel+"/"
          println "Datastore found in list by Name in folder " + tmp_check + " ---- " + pPath

          if ( pPath.contains( tmp_check ) == true ) {
            println "datastore found "+datastore_list.getName()
            datastore = datastore_list
          } else { println "datastore is not in same path" }
        }
      }
    }

    if ( datastore != null && datastore.getName() == pSearchDSName ) {
     // Check if other version
       println "datastore has been found and name is identical"
 
       def submodel = datastore.getSubModel()
       def model = datastore.getModel()

       // Remove all keys
       def all_keys = datastore.getKeys()
       for (def ckey : all_keys) {
          println "remove key"
          datastore.removeKey( ckey )
       }

       // Remove all the references also
       def refs = ((IOdiReferenceFinder)tme_ds.getFinder(OdiReference.class)).findByPrimaryDataStore(datastore.getDataStoreId())
       for (def ref: refs) {
         println "remove ref"
         tme_ds.remove(ref)
       }

       submodel.removeDataStore(datastore)
       tme_ds.remove(datastore)
    }
    else
    {
      println "Datastore not found to delete : "+pSearchDSName+"/"+pGlobalId+"/"+pPath
    }
    tm_ds.commit(trans_ds);
  }
  catch (e) {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm_ds.rollback(trans_ds)
  }
}

// REMOVE CONTEXT
def remove_OdiContext(String pSearchContextName, String pSearchProject, OdiInstance odiInstance, String GUID_Origin ) {

  tm = odiInstance.getTransactionManager()
  tme = odiInstance.getTransactionalEntityManager()
  trans = tm.getTransaction(new DefaultTransactionDefinition());

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
    println("Exception catched : error : " + e);
    println("....Rollback work");
    tm.rollback(trans);
  }

}

// LOGICAL AGENT
def remove_OdiLogicalAgent(String pLogicalAgentName, OdiInstance odiInstance, String pExpDir, String GUID_Origin ) {

  tm = odiInstance.getTransactionManager()
  tme = odiInstance.getTransactionalEntityManager()
  ITransactionStatus trans = tm.getTransaction(new DefaultTransactionDefinition());

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

//tm_global = odiInstance.getTransactionManager()
//tme_global = odiInstance.getTransactionalEntityManager()
//trans = tm_global.getTransaction(new DefaultTransactionDefinition());

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

//Loop 0
//Scenarios

xIDeploymentArchive.getUpdatedObjects() each {
   xClass = it.getType()
   classname = xClass.getSimpleName()
   objname = it.name

try {
   if (classname == "OdiScenario") {
      println objname + " --> " + classname
    //Split the name: scenario names are extended with "version 001" in the EXEC_ zip file
      String[] str;
      str = objname.split(' Version ');
      objname = str[0];
      remove_OdiScenario(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
}
  catch (e) {
        println("Exception catched : error : " + e)
  }

}

//Loop 1
//Packages, Scenarios, Sequences

xIDeploymentArchive.getUpdatedObjects() each {
   xClass = it.getType()
   classname = xClass.getSimpleName()
   objname = it.name

try {
   if (classname == "OdiPackage") { 
      println objname + " --> " + classname
      remove_OdiPackage(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };

//   if (classname == "OdiScenario") { 
//      println objname + " --> " + classname
//    //Split the name: scenario names are extended with "version 001" in the EXEC_ zip file
//      String[] str;
//      str = objname.split(' Version ');
//      objname = str[0];
//      remove_OdiScenario(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
//   };

   if (classname == "OdiSequence") { 
       println objname + " --> " + classname
       remove_OdiSequence(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
}
  catch (e) {
        println("Exception catched : error : " + e)
  }
}

//Loop 2
//Mappings, DataStores
xIDeploymentArchive.getUpdatedObjects() each {
   xClass = it.getType()
   classname = xClass.getSimpleName()
   objname = it.name

try {
   if (classname == "MapRootContainer") {
      println objname + " --> " + classname
      remove_MapRootContainer(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
   if (classname == "OdiProcedure") {
      println objname + " --> " + classname
      remove_OdiProcedure(objname, projectname, odiInstance,pExpDir, it.getGlobalId());
   };
}
  catch (e) {
        println("Exception catched : error : " + e)
  }
}

//Loop 3
//DataStores
xIDeploymentArchive.getUpdatedObjects() each { upd_object ->
   xClass = upd_object.getType()
   classname = xClass.getSimpleName()
   objname = upd_object.name
try {
   if (classname == "OdiDataStore") {
      println objname + " --> " + classname + " (" +upd_object.getGlobalId() + ")"
      remove_OdiDataStore(objname, projectname, odiInstance, pExpDir, upd_object.getGlobalId(), upd_object.path);
   };
}
  catch (e) {
        println("Exception catched : error : " + e)
  }
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

// tm_global.commit(trans)

println "Script exit .. "

