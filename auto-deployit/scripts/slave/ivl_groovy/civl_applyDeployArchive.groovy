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

import oracle.odi.impexp.EncodingOptions
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

def cli = new CliBuilder(usage: 'civl_applyDeployArchives.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'name', args:1, required: true, 'Name of the deployment archive'
        b longOpt: 'backupdir', args:1, required: false, 'Directory for the rollback'
        p longOpt: 'Physical', args:0, required: false, 'Physical schema included'
}

def options = cli.parse(args)

println "INFO: ######################"
println "INFO: Name      : "+options.f
println "INFO: Backupdir : "+options.b
println "INFO: ######################"

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

def include_physical

// by default:

include_physical = false

if(options.p){
  include_physical = true
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

try{
        println("INFO: ............Applying deployment archive ")

        def exportKey = "ThisIsMyKey"
        def dplType = DeploymentArchiveType.PATCH

        DeploymentService dplSrv = new DeploymentService()

println "INFO: Start apply deploy creation"
def prollbackname=null

        if(options.b) {
            dplSrv.applyPatchDeploymentArchive(odiInstance,
                                               options.name,
                                               true,
                                               options.b,
                                               include_physical ,
                                               exportKey.toCharArray(),
                                               true)
        }
        else {
            dplSrv.applyPatchDeploymentArchive(odiInstance,
                                               options.name,
                                               false,
                                               null,
                                               include_physical ,
                                               exportKey.toCharArray(),
                                               true)
        }
        tm.commit(trans)
}
catch (e) {
        if (e.getMessage()=="ODI-11032: Nothing to apply.") {
           println( e.getMessage() )
           tm.rollback(trans)
           System.exit(0)
        } else {
        println("Exception catched : error : " + e)
        println("....Rollback work")
        tm.rollback(trans)
        System.exit(1);
        }
}

println("INFO: Process successfully completed........")
odiInstance.close()


