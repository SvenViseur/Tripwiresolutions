import oracle.odi.domain.marker.finder.IOdiMarkerGroupFinder
import oracle.odi.domain.marker.OdiMarkerGroup
import oracle.odi.domain.model.finder.IOdiModelFolderFinder
import oracle.odi.domain.model.OdiModelFolder
import oracle.odi.domain.project.OdiSequence
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication

import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiUserProcedure

import oracle.odi.domain.project.OdiFolder
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.OdiKM
import oracle.odi.domain.project.OdiVariable
import oracle.odi.domain.project.finder.IOdiFolderFinder
import oracle.odi.domain.project.finder.IOdiKMFinder
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.domain.project.finder.IOdiSequenceFinder
import oracle.odi.domain.project.finder.IOdiVariableFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan

import oracle.odi.domain.model.finder.IOdiModelFolderFinder
import oracle.odi.domain.model.OdiModelFolder

import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl
import java.text.*
import org.apache.tools.zip.ZipOutputStream
import org.apache.tools.zip.ZipEntry
import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.project.finder.IOdiUserProcedureFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.project.OdiUserProcedure

import oracle.odi.core.service.deployment.*

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'civl_check_release.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'filename', args:1, required: true, 'Filename with odiinfo extension'
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


println "INFO: Processing file: "+options.f;

      def File file = new File(options.f);

      def pMapList = ( file as List).collect { it.split('\\|') }
      def return_val=0

      pMapList.each() { item ->
           pTicket= item[0] // ticket_id
           pType=   item[1] // type scenario/loadplan
           pNaam=  item[2] // Naam
           pLastAdaptBy= item[3] // laatst aangepast door
           pGlobalId= item[4] // global id
           pLastAdaptOn= item[5] // Datum laatste aanpassing
           //println pTicket
           //println pType
           //print "Controle : "+pNaam+" -> "
           //println pLastAdaptBy
           //println pGlobalId
           //println pLastAdaptOn

           def dateLastAdaptedOn = Date.parse( 'yyyy-MM-dd k:mm:SS', pLastAdaptOn)

           if (pType == "scenario") {
               def scn = ((IOdiScenarioFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findLatestByName(pNaam)
               if (scn != null) {
                  scen_lastdate = scn.getLastDate()
                  scen_globalid = scn.getGlobalId()
                  //println "["+scen_lastdate + "] - [" + pLastAdaptOn + "]"
                  if (scen_lastdate < dateLastAdaptedOn) {
                     println "ERROR: --> !! Scenario: "+pNaam+" : Datum is onjuist !!. Datum aangepast: "+pLastAdaptOn+". Datum op target : "+scen_lastdate
                     return_val=1
                  }
               }
               else
               {
                  println "ERROR: --> !! Scenario not found : "+pNaam
                  return_val=1
               }
           }


           if (pType == "loadplan") {
               def lp = ((IOdiLoadPlanFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(pNaam)
               if (lp != null) {
                  lp_lastdate = lp.getLastDate()
                  lp_globalid = lp.getGlobalId()
                  //println "["+lp_lastdate + "] - [" + pLastAdaptOn + "]"
                  if (lp_lastdate < dateLastAdaptedOn) {
                     println "ERROR: --> !! Loadplan: "+pNaam+" : Datum is onjuist !!. Datum aangepast: "+pLastAdaptOn+". Datum op target : "+lp_lastdate
                     return_val=1
                  }
               }
               else
               {
                  println "ERROR: --> !! Loadplan not found : "+pNaam
                  return_val=1
               }
           }

       }
System.exit(return_val);

