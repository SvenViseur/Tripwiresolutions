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

import oracle.odi.domain.mapping.Mapping

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.runtime.scenario.OdiScenario

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

def cli = new CliBuilder(usage: 'civl_importLoadplans.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
        d longOpt: 'dirname', args:1, required: true, 'Directory of the deployment'
//        f longOpt: 'filename', args:1, required: true, 'File of the deployment'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

def remove_loadplans( String pimpDir, odiInstance) {

        println("INFO: ... REMOVING LOADPLANS" )
        ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
        def tm = odiInstance.getTransactionManager()
        def tme = odiInstance.getTransactionalEntityManager()

        def dir
        dir = new File(pimpDir).eachFile (FileType.FILES) { file ->
                   println("INFO: processing file " + file.path )

                   pObjName = file.name
                   pObjName = pObjName.substring(3)
                   pObjName = pObjName.substring(0, pObjName.lastIndexOf("."))
                   def lp = ((IOdiLoadPlanFinder)tme.getFinder(OdiLoadPlan.class)).findByName(pObjName)

                   if ( lp != null ) {
                      if ( lp.getScenarioFolder() != null ) {
                         // Remove from folder
                         def fldr=lp.getScenarioFolder()
                         fldr.removeLoadPlan(lp);
                      }
                      // Remove from repository
                      tme.remove(lp)
                   }
                   }
        tm.commit(trans)
}

def import_loadplans(String pimpDir, odiInstance) {

	println("INFO: ... IMPORT LOADPLANS" )
	ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
	def tm = odiInstance.getTransactionManager()
	def dir
	def Imp = new ImportServiceImpl(odiInstance)

        dir = new File(pimpDir).eachFile (FileType.FILES) { file ->
                   println("INFO: importing file " + file.path )
                   txnDef = new DefaultTransactionDefinition();
                   tm = odiInstance.getTransactionManager()
                   txnStatus = tm.getTransaction(txnDef)
                   Imp.importObjectFromXml( IImportService.IMPORT_MODE_SYNONYM_INSERT_UPDATE, file.path ,false ,null,true)
                   tm.commit(txnStatus)
                   }
	tm.commit(trans)
}

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

def importDir = options.d

println("INFO: Import directory: " + importDir ); 

remove_loadplans(importDir, odiInstance)

import_loadplans(importDir, odiInstance)

println("INFO: Process Completed");

