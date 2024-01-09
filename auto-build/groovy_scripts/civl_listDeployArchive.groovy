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

def cli = new CliBuilder(usage: 'civl_listDeployArchive.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
        n longOpt: 'name', args:1, required: true, 'Name of the deployment archive'
        r longOpt: 'release', args:1, required: true, 'Name of the release'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

def rel=options.release
def nam=options.name

Date date = new Date()
String datePart = date.format("dd/MM/yyyy")
String timePart = date.format("HH:mm:ss")

try{
        DeploymentService dplSrv = new DeploymentService()

def xIDeploymentArchive = dplSrv.getDeploymentArchive(options.name)

xIDeploymentArchive.getUpdatedObjects() each {
   print "scenario"
   print '|'
   print it.getName()
   print '|'
   print ""
   print '|'
   print it.getGlobalId()
   print '|'
   print xIDeploymentArchive.getName()
   print '|'
   println xIDeploymentArchive.getCreatedDate().format('yyyy-MM-dd k:mm:SS')
}

//xIDeploymentArchive.getUpdatedObjects() each {
//   print rel
//   print '|'
//   print nam
//   print '|'
//   print it.getGlobalId()
//   print '|'
//   print datePart
//   print ' '
//   print timePart
//   print '|'
//   print xIDeploymentArchive.getCreatedDate()
//   print '|'
//   print it.getPath()
//   print '|'
//   print it.getType()
//   print '|'
//println it.getName() 
//}

}
catch (e) {
        println("ERROR: Exception catched : error : " + e)
        System.exit(1);
}

