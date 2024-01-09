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

def pExpDir
def now = new Date()
pExpDir = ""

File BaseOutFile = new File(options.b)

File ExecOutFile = new File(options.e)

BaseOutFile.append("")
ExecOutFile.append("")

DeploymentService dplSrv = new DeploymentService()

def xIDeploymentArchive = dplSrv.getDeploymentArchive(options.f)

//Loop 1
//Packages, Scenarios, Sequences

xIDeploymentArchive.getUpdatedObjects() each {
   xClass = it.getType()
   classname = xClass.getSimpleName()
   objname = it.name

   if (classname == "OdiScenario") {
      println objname + " --> " + classname
      //Split the name: scenario names are extended with "version 001" in the EXEC_ zip file
      String[] str;
      str = objname.split(' Version ');
      SearchScenarioName = str[0];

      //##################################################
      //# Find the scenario in the ODI repository itself #
      //##################################################

      OdiScenario sc = ((IOdiScenarioFinder)tme.getFinder(OdiScenario.class)).findLatestByName(SearchScenarioName)

      if (sc != null && sc.getName() == SearchScenarioName) {
        BaseOutFile << "0|REPOSITORY|" + sc.getName() + "|" + sc.getFirstDate().format('yyyyMMddHHmmss').toString() + "|first_date_ODI_repo|" + sc.getFirstUser()+ "|Scenario" + "\n"
      }
      else
      {
        BaseOutFile << "0|0|" + pSearchScenarioName + "|19000101000000|NewScen_ODI_repo|new|Scenario"+"\n"
      }

      //#############################
      //# Output to the ExecOutFile #
      //#############################
      ExecOutFile << options.n + "|" + xIDeploymentArchive.getName() + "|" + SearchScenarioName + "|" + xIDeploymentArchive.getCreatedDate().format('yyyyMMddHHmmss').toString() + "|Build_Date|" + xIDeploymentArchive.getCreatedBy() + "|Scenario" + "\n"

   };
}

println "Script exit .. "


