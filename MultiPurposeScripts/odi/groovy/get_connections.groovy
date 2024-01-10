//Created by DI Studio
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
import oracle.odi.domain.topology.OdiContextualSchemaMapping
import oracle.odi.domain.topology.OdiPhysicalSchema
import oracle.odi.domain.topology.OdiContextualSchemaMapping

import oracle.odi.domain.model.OdiDataStore
import oracle.odi.domain.model.finder.IOdiDataStoreFinder

import oracle.odi.domain.topology.finder.IOdiTechnologyFinder
import oracle.odi.domain.topology.OdiTechnology
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
import oracle.odi.domain.topology.finder.IOdiPhysicalSchemaFinder
import oracle.odi.domain.topology.OdiPhysicalSchema

import org.apache.tools.zip.ZipOutputStream
import org.apache.tools.zip.ZipEntry
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.core.service.deployment.*
import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

// Connection
//MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
//WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
//OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
//Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
//odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

//def srv=Url.split("/")[3]

def masterInfo = odiInstance.getConfig().getMasterRepositoryDbInfo()
def workrep = odiInstance.getConfig().getWorkRepositoryDbInfo()

Url = masterInfo.getJdbcUrl()
def srv=Url.split("/")[3]
def Master_User = masterInfo.getJdbcUsername()

List InfoList = new ArrayList()
def all_technologie = ((IOdiTechnologyFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiTechnology.class)).findAll()

for (def technologie : all_technologie) {
  if (technologie.getName() == "Oracle") {
     def all_ds = technologie.getDataServers()
     for (def ds : all_ds) { 
         print srv
         print "|"
         print Master_User
         print "|"
         print "Connection from ODI"
         print "|"
         print ds.getName()
         print "|" 
         println ds.getConnectionInfo().getJdbcUrl()
         
//         println srv+"|"+Master_User+"|"+ds.getName()+"|"+ds.getConnectionInfo().getJdbcUrl()+"|"+ds.getConnectionInfo().getJdbcUrl().split("/")[2]+"|"+ds.getConnectionInfo().getJdbcUrl().split("/")[3]
    }
  }
}

//print workrep
//print " ==> "
//println masterInfo.getJdbcUrl()

//println masterInfo.getJdbcUrl().split("/")[3]

print srv
print "|"
print Master_User
print "|"
print "Master Connection to ODI"
print "|"
print Master_User
print "|"
println  masterInfo.getJdbcUrl()

//println srv+"|"+Master_User+"|"+workrep+"|"+Url

