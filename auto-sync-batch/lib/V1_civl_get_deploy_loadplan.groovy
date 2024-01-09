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
        f longOpt: 'ExecFile', args:1, required: true, 'File DeployArchive (EXEC_ or Full)'
        b longOpt: 'BaseOutputFile', args:1, required: true, 'Base Output file'
        e longOpt: 'ExecOutputFile', args:1, required: true, 'Exec ZIP Output file'
        n longOpt: 'OrderFile', args:1, required: true, 'Order of the EXEC file in Deploy Release'
}

def options = cli.parse(args)

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
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

println "Processing file: "+options.f;

File BaseOutFile = new File(options.b)
File ExecOutFile = new File(options.e)

BaseOutFile.append("")
ExecOutFile.append("")

File InputFile = new File(options.f)

def pLoadplanList = ( InputFile as List ).collect { it.split('\\|') }

pLoadplanList.each() { EachLine ->

   In_Order=EachLine[0]
   In_File=EachLine[1]
   SearchLoadplan = EachLine[2]
   In_Date=EachLine[3]
   In_TypeDate=EachLine[4]
   In_User=EachLine[5]
   In_Type=EachLine[6]

   println "Searching for loadplan: " + SearchLoadplan

   ExecOutFile << In_Order + "|" + In_File + "|" + SearchLoadplan + "|" + In_Date + "|" + In_TypeDate + "|" + In_User + "|" + In_Type + "\n"

   OdiLoadPlan lp = ((IOdiLoadPlanFinder)tme.getFinder(OdiLoadPlan.class)).findByName(SearchLoadplan)

   if (lp != null && lp.getName() == SearchLoadplan) {
     BaseOutFile << "0|REPOSITORY|" + lp.getName() + "|" + lp.getFirstDate().format('yyyyMMddHHmmss').toString() + "|first_date_ODI_repo|" + lp.getFirstUser()+ "|Loadplan" + "\n"
   }
   else
   {
     BaseOutFile << "0|NEW|" + SearchLoadplan + "|19000101000000|NewLoadplan_ODI_repo|new|Loadplan"+"\n"
   }
}

println "Script exit .. "

