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

import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.topology.OdiContext

import oracle.odi.domain.topology.finder.IOdiContextualSchemaMappingFinder
import oracle.odi.domain.topology.OdiContextualSchemaMapping
import oracle.odi.domain.topology.finder.IOdiContextualAgentMappingFinder
import oracle.odi.domain.topology.OdiContextualAgentMapping

import oracle.odi.domain.topology.finder.IOdiLogicalSchemaFinder
import oracle.odi.domain.topology.OdiLogicalSchema

import oracle.odi.domain.topology.finder.IOdiPhysicalSchemaFinder
import oracle.odi.domain.topology.OdiPhysicalSchema
import oracle.odi.domain.topology.finder.IOdiLogicalAgentFinder
import oracle.odi.domain.topology.OdiLogicalAgent

import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl
import java.text.*
import org.apache.tools.zip.ZipOutputStream
import org.apache.tools.zip.ZipEntry

def zipIt (String pZipArchive, String pZipDir, String pFilesDir, List pFilesToZip ) {
        ByteArrayOutputStream baos = new ByteArrayOutputStream()
        ZipOutputStream zipFile = new ZipOutputStream(baos)
        def filesToZip=pFilesToZip.sort{a,b -> a.getName().compareTo(b.getName())}
        filesToZip.each{
                if( it.isFile() ){
                        zipFile.putNextEntry(new ZipEntry(it.name))
                        it.withInputStream { i -> zipFile << i }
                        zipFile.closeEntry()
                }
        }
        zipFile.finish()

        OutputStream outputStream = new FileOutputStream (pZipDir+"/"+pZipArchive )
        baos.writeTo(outputStream)
        pFilesToZip.each{ it.delete() }

}


def export_to_xml_nochilds ( export_source, pExpDir, odiInstance ) {

        // Export the current version
        def encOpt = new EncodingOptions()
        def Exp2 = new ExportServiceImpl(odiInstance)
        char[] exportKey = 'ThisIsNotUsed0='

// Export without cypherData !!

        Exp2.exportToXml( export_source ,
                          pExpDir,
                          true,
                          false,
                          encOpt,
                          exportKey,
                          true)
}


def export_to_xml( export_source, pExpDir, odiInstance ) {

        // Export the current version
        def encOpt = new EncodingOptions()
        def Exp2 = new ExportServiceImpl(odiInstance)
        char[] exportKey = 'ThisIsNotUsed0='

// Export without cypherData !!

        Exp2.exportToXml( export_source ,
                          pExpDir,
                          true,
                          true, //false,
                          encOpt,
                          exportKey,
                          true)
}

def buildList ( List pList, List pErrList, List pVersionList, String pObjName, OdiInstance odiInstance, String pProject, List pfilesToZip , String pExpDir, String pTicketId, String pCheckOnly, List pDetailList, String pBuildID, String ArchiveName ){
        def objId
        //scenarios ?
        def scn = ((IOdiScenarioFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findLatestByName(pObjName)
        if(scn != null){
                pVersionList.add(pTicketId  + "|" + "scenario|" + scn.getName() + "|" + scn.getLastUser() + "|" + scn.getGlobalId() + "|" +  scn.getLastDate().format('yyyy-MM-dd HH:mm:SS')  + "|" + pBuildID+ "|" + ArchiveName)
                // println("..Adding scenario "+scn.getName())
                if (scn.wasGeneratedFromPackage()){
                        //println("....Include package")
                        def pckId = scn.getSourcePackageId()
                        objId = new OdiObjectId(OdiPackage.class, pckId)
                        pList.add(objId)
                        def pckg = ((IOdiPackageFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiPackage.class)).findById(pckId)
                        pDetailList.add(pTicketId  + "|" + "scenario|" + scn.getName() + "|package|" + pckg.getName() + "|" + pckg.getLastUser() + "|" + pckg.getGlobalId() + "|" +  pckg.getLastDate().format('yyyy-MM-dd HH:mm:SS') + "|" + pBuildID + "|" + ArchiveName)
                }
                if (scn.wasGeneratedFromMapping()){
                        //println("....Include mapping")
                        def mapId = scn.getSourceMappingId()
                        def map = ((IMappingFinder)odiInstance.getTransactionalEntityManager().getFinder(Mapping.class)).findById(scn.getSourceComponentId())
                        pDetailList.add(pTicketId  + "|" + "scenario|" + scn.getName() + "|mapping|" + map.getName() + "|" + map.getLastUser() + "|" + map.getGlobalId() + "|" +  map.getLastDate().format('yyyy-MM-dd HH:mm:SS') + "|" + pBuildID + "|" + ArchiveName)
                        objId = new OdiObjectId(Mapping.class, mapId)
                        pList.add(objId)
                }
                if (scn.wasGeneratedFromUserProcedure()){
                        //println("....Include procedure")
                        def prcId = scn.getSourceComponentId()
                        def prc = ((IOdiUserProcedureFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiUserProcedure.class)).findById(scn.getSourceComponentId())
                        pDetailList.add(pTicketId  + "|" + "scenario|" + scn.getName() + "|procedure|" + prc.getName() + "|" + prc.getLastUser() + "|" + prc.getGlobalId() + "|" +  prc.getLastDate().format('yyyy-MM-dd HH:mm:SS') + "|" + pBuildID + "|" + ArchiveName)
                        //objId = new OdiObjectId(Mapping.class, prcId)
                        objId = new OdiObjectId(OdiUserProcedure.class, prcId)
                        pList.add(objId)
                }
                objId = new OdiObjectId(OdiScenario.class, scn.getInternalId())
                pList.add(objId)
        }
        else
        {
                //Load Plan ?
                def lp = ((IOdiLoadPlanFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(pObjName)
                if(lp != null){
                        pVersionList.add(pTicketId  + "|" + "loadplan|" + lp.getName() + "|" + lp.getLastUser() + "|" + lp.getGlobalId() + "|" + lp.getLastDate().format('yyyy-MM-dd HH:mm:SS') + "|" + pBuildID + "|" + ArchiveName)
                        println("INFO: Export to xml: Loadplan "+ lp.getName())

                  if (pCheckOnly == "No"){
                        objId = new OdiObjectId(OdiLoadPlan.class, lp.getInternalId())

                        def encOpt = new EncodingOptions()
                        def Exp2 = new ExportServiceImpl(odiInstance)
                        char[] exportKey = 'ThisIsNotUsed0='
                        //pExpDir = '/home/oracle/DeploymentArchives'
                        encOpt = new EncodingOptions()
                        Exp2 = new ExportServiceImpl(odiInstance)

                        Exp2.exportToXml(
                                lp ,
                                pExpDir,
                                true,
                                true,
                                encOpt,
                                exportKey,
                                false)

                        zipit_name = "LP_"+lp.getName().replace(".","_")
                        zipit_name = zipit_name.replace("-","_")

                        new File(pExpDir).eachFileMatch(zipit_name+".xml") {
                           file -> pfilesToZip.add(file)
                        }
                }

        }
                else
        {
                //println("### Object to be deployed is not found : " + pObjName + " ###");
                pErrList.add(pObjName);
                //System.exit(1);
        }
                }
}

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"
def cli = new CliBuilder(usage: 'createDeployArchives.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        n longOpt: 'name', args:1, required: true, 'Name of the deployment archive'
        d longOpt: 'description', args:1, required: true, 'Description for the deployment archive'
        p longOpt: 'filepath', args:1, required: true, 'Path of the deployment archive'
        f longOpt: 'fileName', args:1, required: true, 'Deployment archive zip file'
        g longOpt: 'generateScenario', args:0, required: false, 'Generate Scenarios'
        l longOpt: 'loadplans',  args:1, required: true, 'Load plans zip file'
        c longOpt: 'checkonly',  args:0, required: false, 'Check only but do not create anything'
        e longOpt: 'environment',  args:1, required: false, 'Environment (IVL -default or CIVL)'
        b longOpt: 'buildID', args:1, required: true, 'Jenkins Build ID'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

def regenScen = false

if(options.g){
        regenScen = true
}

//def Url = "jdbc:oracle:thin:@//ARGEXA02-SCAN-DVL:1521/PEDRDVL1_srv";
//def Driver="oracle.jdbc.OracleDriver";
//def Master_User="B18111_ODI_REPO";
//def Master_Pass="Q7xavsDUMGtN5zUj"
//def WorkRep="WORKREP";
//def Odi_User="IVL_BATCH";
//def Odi_Pass="Tripwire1";

def Url = System.getenv( 'ODI_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Master_User=System.getenv( 'ODI_MASTER_USR' );
def Master_Pass=System.getenv( 'ODI_MASTER_PSW' );
def WorkRep=System.getenv( 'ODI_WORKREP' );
def Odi_User=System.getenv( 'ODI_USR' );
def Odi_Pass=System.getenv( 'ODI_PSW' );

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes())
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes())
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo))
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray())
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth)

def project = "CIVL"

def BuildID = options.b

if(options.e){
     project=options.e
}

ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition())
def tm = odiInstance.getTransactionManager()

List objList = new ArrayList()
def filesToZip = []
def filesToZip_topology = []
def filesToZip_dataserver = []

List objErrList = new ArrayList()

List VersionList = new ArrayList()
List TopologyList = new ArrayList()
List DetailList = new ArrayList()
List DataServerList = new ArrayList()
List PDataServerList = new ArrayList()

def pNoErrors
pNoErrors=0

def checkonly="No"

def list_contexts = new ArrayList()
def pExpDir_topology = options.filepath+"/topology"
def pExpDir_dataservers = options.filepath+"/dataserver"

if (options.c) {
    checkonly="Yes"
}

System.in.eachLine() { line ->
        buildList(objList, objErrList, VersionList, line, odiInstance, project, filesToZip, options.filepath, options.d, checkonly, DetailList, BuildID, options.name)
}


if (options.c) {
   if (objErrList.size() > 0){
      objErrList.each{
       print "ERROR: ####  Missing ODI object => "
       println "["+it+"]"
      }
      pNoErrors=1
   }
   odiInstance.close()
   System.exit(pNoErrors)
}

try{

        if (objList.size() > 0) {
 
          def exportKey = "ThisIsMyKey"
          def dplType = DeploymentArchiveType.PATCH

          println "INFO: Start deploy archive creation"
          println "INFO: Number of Objects in List : " + objList.size()

          DeploymentService dplSrv = new DeploymentService()

          println "INFO: Start deploy archive creation"

          def dplArch = dplSrv.createDeploymentArchiveFromRepo(
                        odiInstance,
                        objList,
                        options.name,
                        options.description,
                        dplType,
                        options.filepath + "/" + options.fileName,
                        false,
                        exportKey.toCharArray(),
                        true,
                        false,
                        regenScen)

          // Export Topology found in order of context, logical agent and logical schema
          dplArch.getUpdatedObjects() each {
             xClass = it.getType()
             classname = xClass.getSimpleName()
             objname = it.name
             if (classname == "NOdiLogicalAgent") {
                def lagent = ((IOdiLogicalAgentFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiLogicalAgent.class)).findByName(objname)
                if ( lagent != null ) {
                   export_to_xml( lagent, pExpDir_topology, odiInstance)
                }
             };
             if (classname == "OdiContext" && objname.toUpperCase() == "GLOBAL") {
                def context = ((IOdiContextFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiContext.class)).findByCode(objname.toUpperCase())
                list_contexts.add(context)
             };
          }

          dplArch.getUpdatedObjects() each {
             xClass = it.getType()
             classname = xClass.getSimpleName()
             objname = it.name
             if (classname == "OdiLogicalSchema") {
                def lschema = ((IOdiLogicalSchemaFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiLogicalSchema.class)).findByName(objname)
                list_contexts.each() {
                   if ( lschema.getPhysicalSchema(it) != null ) {
                      if ( lschema.getName() == "FILE_GENERIC" && lschema.getPhysicalSchema(it).getName().contains("/homes/") ) {
                         println "ERROR: File is linked to unauthorized directory"
                         System.exit(1)
                      }
                      // Do not export the repository connection itself as the underlying schemas are different
                      if ( lschema.getPhysicalSchema(it).getDataServer().getName() != "IVL4_ODI_REPO" && lschema.getPhysicalSchema(it).getDataServer().getName() != "CIVL4_ODI_REPO" ) {
                          TopologyList.add(it.getCode()+"|"+lschema.getName()+"|"+lschema.getPhysicalSchema(it).getName()+"|"+lschema.getPhysicalSchema(it).getPhysicalSchemaId()+"|"+lschema.getPhysicalSchema(it).getGlobalId())
                          export_to_xml( lschema, pExpDir_topology, odiInstance)
                          export_to_xml( lschema.getPhysicalSchema(it), pExpDir_topology, odiInstance)
                          PDataServerList.add(lschema.getPhysicalSchema(it).getDataServer())
                      }
                   }
                }
              }
          }
          println "Number of dataservers: "+PDataServerList.size()

          PDataServerList.unique().each { dataserver ->
             // Export also the dataservers if any
             DataServerList.add( dataserver.getName()+"|"+dataserver.getGlobalId() )
             export_to_xml_nochilds( dataserver, pExpDir_dataservers, odiInstance)
          }
        }
        else
        {
           println "INFO: No content found to create a DeployArchive"
        }

        if (filesToZip.size() > 0){
           println "INFO: files zip loadplans: size => "+filesToZip.size()
           zipIt(options.loadplans, options.filepath, options.filepath, filesToZip)
        }

        File cf = new File(pExpDir_topology);
        if ( cf.exists() ) {

           new File(pExpDir_topology).eachFile {
                       file -> filesToZip_topology.add(file)
           }

           if (filesToZip_topology.size() > 0){
              println "INFO: files zip topology: size => "+filesToZip_topology.size()
              zipIt("TOPOLOGY_"+options.description+".zip", options.filepath, options.filepath, filesToZip_topology)
              new File(pExpDir_topology).deleteDir()
           }

           //Topology: context related Logical Schemas
           File tlist = new File(options.filepath + "/" + options.description + ".topology")
           tlist.write("")
           TopologyList.each { listitem ->
           tlist << listitem+"\n" }
        }

        File ds = new File(pExpDir_dataservers);
        if ( ds.exists() ) {

           new File(pExpDir_dataservers).eachFile {
                       file -> filesToZip_dataserver.add(file)
           }

           if (filesToZip_dataserver.size() > 0){
              println "INFO: files zip dataservers: size => "+filesToZip_dataserver.size()
              zipIt("DATASERVER_"+options.description+".zip", options.filepath, options.filepath, filesToZip_dataserver)
              new File(pExpDir_dataservers).deleteDir()
           }
           File flist = new File(options.filepath + "/" + options.description + ".dataserverinfo")
           flist.write("")
           DataServerList.each { listitem ->
           flist << listitem+"\n" }
         }

        //odiinfo file

        File flist = new File(options.filepath + "/" + options.description + ".odiinfo")
        flist.write("")
        VersionList.each { listitem ->
        flist << listitem+"\n" }

        File fDetaillist = new File(options.filepath + "/" + options.description + ".detailodiinfo")
        fDetaillist.write("")
        DetailList.each { listitem ->
        fDetaillist << listitem+"\n" }

        println("INFO: Commiting work")
        tm.commit(trans)

}
catch (e) {
        println("ERROR: Exception catched : error : " + e)
        println("ERROR: Rollback work")
        tm.rollback(trans)
        System.exit(1);
}

println("INFO: Process successfully completed........")
odiInstance.close()


