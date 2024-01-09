import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.domain.project.finder.IOdiUserProcedureFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.project.OdiUserProcedure
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.core.service.deployment.*
import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*


import oracle.odi.domain.topology.finder.IOdiContextualSchemaMappingFinder
import oracle.odi.domain.topology.OdiContextualSchemaMapping
import oracle.odi.domain.topology.finder.IOdiContextualAgentMappingFinder
import oracle.odi.domain.topology.OdiContextualAgentMapping

import oracle.odi.domain.topology.finder.IOdiLogicalSchemaFinder
import oracle.odi.domain.topology.OdiLogicalSchema

import oracle.odi.domain.topology.finder.IOdiPhysicalSchemaFinder
import oracle.odi.domain.topology.OdiPhysicalSchema
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.topology.OdiContext
import oracle.odi.domain.topology.OdiContextualSchemaMapping

import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartImportServiceImpl
import oracle.odi.impexp.support.ImportServiceImpl
import oracle.odi.impexp.IImportService

import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl
import java.text.*
import org.apache.tools.zip.ZipOutputStream
import org.apache.tools.zip.ZipEntry

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'civl_link_context_topology.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'context', args:1, required: true, 'Name of the Context file settings'
}

def options = cli.parse(args)
def include_physical

// by default:

include_physical = false

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
// TNS_ADMIN settings
def tnsAdminFromEnv = System.getenv('TNS_ADMIN');
if (tnsAdminFromEnv != null && !tnsAdminFromEnv.isEmpty()) {
	System.setProperty('oracle.net.tns_admin', tnsAdminFromEnv);
} else {
	System.setProperty('oracle.net.tns_admin', '/cgk/dba/tnsadmin'); // default op Linux
}

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes())
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes())
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo))
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray())
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth)

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition())
def tm = odiInstance.getTransactionManager()

// Set also the correct link logical schema vs physical schema in context
def File file = new File(options.f);

def pContextList = ( file as List).collect { it.split('\\|') }
def return_val=0

pContextList.each() { item ->
   pContext= item[0]
   pLogicalSchema= item[1]
   pPhysicalSchema= item[2]
   pPhysicalID= item[3]
   pPhysicalGlobalID= item[4]

   // Find the context
   def linkLschemaContext = ((IOdiContextualSchemaMappingFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiContextualSchemaMapping.class)).findByLogicalSchema(pLogicalSchema, pContext)

   // Find the logical Schema
   def logicalSchema = ((IOdiLogicalSchemaFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiLogicalSchema.class)).findByName(pLogicalSchema)

   def context = ((IOdiContextFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiContext.class)).findByCode(pContext)

   // Find the physical Schema

   def physicalSchema = ((IOdiPhysicalSchemaFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiPhysicalSchema.class)).findByGlobalId(pPhysicalGlobalID)

   if (physicalSchema != null) {

     if ( linkLschemaContext == null ) {
       cschema = new OdiContextualSchemaMapping(context, logicalSchema, physicalSchema)
     }

     if ( linkLschemaContext != null) {
//      println "INFO: link to context: "+pContext+": "+linkLschemaContext.getLogicalSchema().getName()+ " to "+physicalSchema.getName()
      linkLschemaContext.setPhysicalSchema(physicalSchema)
     }
   }
}
tm.commit(trans)

println("Process successfully completed........")

