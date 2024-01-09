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

def cli = new CliBuilder(usage: 'civl_applyTopology.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'name', args:1, required: true, 'Name of the Topology archive'
}

def options = cli.parse(args)

println "INFO: f: "+options.f

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

def importFile = options.f

//def AllPhysSchema = ((IOdiPhysicalSchemaFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiPhysicalSchema.class)).findAll()

// def phys_list = []

//AllPhysSchema.each() { phys ->
//  if (phys.getTechnology().getName() == "Oracle" ) {
//     println " --> "+phys.getName()+"-"+phys.getGlobalId()+"-"+phys.getSchemaName()+"-"+phys.getWorkSchemaName()
//     phys_list.add([phys.getName(), phys.getGlobalId(), phys.getSchemaName() ,phys.getWorkSchemaName() ])
//  }
//}

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition())
def tm = odiInstance.getTransactionManager()

try{

        println("INFO: Applying topology")

        def Exp = new ImportServiceImpl(odiInstance)

        def encOpt = new EncodingOptions()
        def expSI = new ImportServiceImpl(odiInstance)
        char[] exportKey = 'ThisIsNotUsed0='


        Exp.importTopologyFromZipFile( IImportService.IMPORT_MODE_SYNONYM_INSERT_UPDATE,
                                       importFile,
                                       true,
                                       exportKey,
                                       false)

        println("INFO: comitting" )
        tm.commit(trans)

}
catch (e) {
        println("ERROR: Exception catched : error : " + e)
        println("ERROR: Rollback work")
        tm.rollback(trans)
        System.exit(1);
}

//ITransactionStatus trans2 = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition())
//def tm2 = odiInstance.getTransactionManager()

//try{

//   phys_list.each() { phys ->
//     // Find by global id
//     println "Setting : "+phys[0]
//     def physicalSchema = ((IOdiPhysicalSchemaFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiPhysicalSchema.class)).findByGlobalId(phys[1])
//     if ( physicalSchema != null && phys[0] == "IVL_ODI_REPO.IVL_ODI_REPO" ) {
//        println phys[0]+" - "+phys[2]+" - "+phys[3]
//        physicalSchema.setSchemaName(phys[3])
//        physicalSchema.setWorkSchemaName(phys[2])
//     }
//   }
//   tm2.commit(trans2)
//}
//catch (e) {
//        println("Exception catched : error : " + e)
//        println("....Rollback work")
//        tm2.rollback(trans2)
//        System.exit(1);
//}

println("INFO: Process successfully completed")

