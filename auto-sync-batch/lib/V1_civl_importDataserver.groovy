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

import oracle.odi.domain.topology.finder.IOdiDataServerFinder
import oracle.odi.domain.topology.OdiDataServer

import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl
import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartImportServiceImpl
import oracle.odi.impexp.support.ImportServiceImpl

import oracle.odi.impexp.IImportService

import groovy.util.*

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
        f longOpt: 'filename', args:1, required: true, 'Dataserver xml file name'
        n longOpt: 'dataserver_name', args:1, required: true, 'Dataserver name'
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

def import_dataserver(String pimpFile, odiInstance) {

	println("INFO: ... IMPORT DATASERVER" )
	//ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
	def Imp = new ImportServiceImpl(odiInstance)

        println("INFO: importing file " + pimpFile )
        txnDef = new DefaultTransactionDefinition();
        tm = odiInstance.getTransactionManager()
        txnStatus = tm.getTransaction(txnDef)
        Imp.importObjectFromXml( IImportService.IMPORT_MODE_SYNONYM_INSERT_UPDATE, pimpFile ,false ,null,true)
        tm.commit(txnStatus)
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

def importFile = options.f

def dataserver_odi = ((IOdiDataServerFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiDataServer.class)).findByName(options.n)

if ( ! dataserver_odi ) {
   println "WARNING: NEW DATASERVER DEPLOYED: "+options.n
   println "WARNING: If this is a database connection, please change the password"
   import_dataserver(importFile, odiInstance)
} else {
   println "INFO: dataserver: ["+options.n+"] already exists."
   println "INFO: No need for futher steps"
}

println("INFO: Process Completed");

