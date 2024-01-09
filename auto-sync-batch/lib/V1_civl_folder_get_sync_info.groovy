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
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl
import java.text.*
import org.apache.tools.zip.ZipOutputStream
import org.apache.tools.zip.ZipEntry

import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder

import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan

import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

import oracle.odi.core.repository.WorkRepository.WorkType

def cli = new CliBuilder(usage: 'createDeployArchives.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        d longOpt: 'exportdir', args:1, required: true, 'export directory'
        f longOpt: 'exportfile', args:1, required: true, 'export filename'
        x longOpt: 'excludefile', args:1, required: true, 'exclude foldernames'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

// Global definitions

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


// Create zip

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

def recursiveRunFolder(String pExpDir, OdiScenarioFolder pFolder, OdiInstance odiInstance, String pStartSequence, Integer pSeqNo, List FolderInfoList, List excl_fldrs) {
        println ".. Working on Folder ["+pFolder.getName() + "] [" + pExpDir + "]"
        Integer seqNo = ++pSeqNo
        def zipNeeded=false
        def filesToZip = []
        def tme = odiInstance.getTransactionalEntityManager()
        def FolderName = pFolder.getName()

        description = pFolder.getDescription()

        if ( description == null || ! description.contains("EXCLUDE") ) {

          if ( ! excl_fldrs.contains( FolderName ) ) {

            pFolder.getSubFolders().each(){ fol->
              recursiveRunFolder(pExpDir+FolderName+"/", fol, odiInstance, pStartSequence, seqNo , FolderInfoList, excl_fldrs)
            }

            def encOpt = new EncodingOptions()
            def expSI = new ExportServiceImpl(odiInstance)
            char[] exportKey = 'ThisIsNotUsed0='

            globalid = pFolder.getGlobalId()
            parentfolder = pFolder.getParentScenFolder()

            parent_globalid = "NONE"
            parent_foldername = "ROOT"

            if ( parentfolder != null )  {
               parent_globalid = parentfolder.getGlobalId()
               parent_foldername = parentfolder.getName()
            }

            if ( description != null ) {
              List lines = description.split( '\n' )
              lines.each() { line ->
                FolderInfoList.add(FolderName+"|"+globalid+"|"+line+"|"+parent_foldername+"|"+parent_globalid+"|"+pExpDir+"|recursiveRunFolder"+"|"+seqNo)
              }
            } else {
              FolderInfoList.add(FolderName+"|"+globalid+"|"+description+"|"+parent_foldername+"|"+parent_globalid+"|"+pExpDir+"|recursiveRunFolder"+"|"+seqNo)
            }

            expSI.exportToXml(
                            pFolder ,
                            pExpDir,
                            true,
                            false,
                            encOpt,
                            exportKey,
                            false)
          }
        }

}

def workOnRunFolder(String pExpDir, OdiScenarioFolder pFolder, OdiInstance odiInstance, String pStartSequence, List FolderInfoList, List excl_fldrs) {
        println ".. Working on Folder ["+pFolder.getName() + "] [" + pExpDir + "]"
        Integer seqNo = 0
        def filesToZip = []
        def parentFolders = []
        def zipNeeded=false
        def tme = odiInstance.getTransactionalEntityManager()

        def FolderName = pFolder.getName()
        description = pFolder.getDescription()

        if ( description == null || ! description.contains("EXCLUDE") ) {

          if ( ! excl_fldrs.contains( FolderName ) ) {
            pFolder.getSubFolders().each(){ fol->
              recursiveRunFolder(pExpDir, fol, odiInstance, pStartSequence, seqNo, FolderInfoList,excl_fldrs)
            }

            def encOpt = new EncodingOptions()
            def expSI = new ExportServiceImpl(odiInstance)
            char[] exportKey = 'ThisIsNotUsed0='

            description = pFolder.getDescription()
            globalid = pFolder.getGlobalId()
            parentfolder = pFolder.getParentScenFolder()

            parent_globalid = "NONE"
            parent_foldername = "ROOT"

            if ( parentfolder != null )  {
               parent_globalid = parentfolder.getGlobalId()
               parent_foldername = parentfolder.getName()
            }

            if ( description != null ) {
               List lines = description.split( '\n' )
               lines.each() { line ->
                  FolderInfoList.add(FolderName+"|"+globalid+"|"+line+"|"+parent_foldername+"|"+parent_globalid+"|"+pExpDir+"|workOnRunFolder"+"|"+seqNo)
               }
            } else {
               FolderInfoList.add(FolderName+"|"+globalid+"|"+description+"|"+parent_foldername+"|"+parent_globalid+"|"+pExpDir+"|workOnRunFolder"+"|"+seqNo)
            }

            expSI.exportToXml(
                            pFolder ,
                            pExpDir,
                            true,
                            false,
                            encOpt,
                            exportKey,
                            false);
          }
       }
}

/////////////////////////////////////////////////

def startSequence
def baseDirs = []
def tmpbaseDirs
List FolderInfoList = new ArrayList()

def exportDir = options.d

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

// Get ALL the scenario root folderL
baseDirs=((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findAll()

startSequence = "2"
bck_subfolder = "2_PROJECT_FOLDERS/"

def tmp_excl_fldrs = new File(options.x) as String[]
def excl_fldrs = []

tmp_excl_fldrs.each() { fldr ->
   if ( fldr != "" ) {
      excl_fldrs.add(fldr)
   }
}

excl_fldrs.each() { fldr -> println fldr }

// Empty target directory first

def mainDir = new File(exportDir)
if ( mainDir.exists() ) {
   mainDir.deleteDir()
}

baseDirs.each(){ folder->
  par_fold = folder.getParentScenFolder()
  if (par_fold == null){
    workOnRunFolder(exportDir+bck_subfolder, folder , odiInstance, startSequence, FolderInfoList, excl_fldrs)
  }
}

filenaam = exportDir + options.f
println "writing to : "+filenaam

File flist = new File(filenaam)
flist.write("")
FolderInfoList.each{ listitem ->
     flist << listitem
     flist << "\n"
}


println("Process Completed");

