import groovy.json.JsonSlurper
import groovy.json.JsonOutput

import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*
import java.text.*

def cli = new CliBuilder(usage: 'applyDeployArchives.groovy ')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'filename', args:1, required: true, 'Name of the json file'
        o longOpt: 'out_filename', args:1, required: true, 'Name of the output file'
        t longOpt: 'Type_json', args:1, required: true, 'Type json: issue or epic'
        b longOpt: 'Build', args:1, required: true, 'Build included or only deploy'
		d longOpt: 'Team', args:1, required: true, 'Build for which team in 4ME'
}

def options = cli.parse(args)

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}
 
filename = options.filename
 
def fileContents = new File(filename).getText('UTF-8')

def json = new JsonSlurper().parseText(fileContents)

// Parse and get the correct key/value from the json input file
def pOmgeving
def pKey
def pURL
def pTeam
def pSummary
def pAssignee
def pProject
def pSource
def pEpic
def pAutoDeploy
def pStopEnv
def pTIRelease
def pTIProject
def pTIProjectID
def pReleaseType
def pBuild
def pReleaseItemType
def pTIList
def pTypeIssue
def pComponent
def pDeployTool

def pAutoDeploy_tmp
def pStopEnv_tmp
def pDeployType

Date date = new Date()
String datePart = date.format("dd/MM/yyyy")
String timePart = date.format("HH:mm:ss")

String regex = "\\[|\\]"

pReleaseItemType="Sofware pakket"
pTIList="RT Hoofdstraat"
pComponent="CIVL"

pStopEnv=""
pAutoDeploy=""

pDeployType="Normale Deploy"
pDeployTool="TRACEIT"

// customfield_10617

//
// ISSUE SLURPER
//

if (options.t == "issue") {

   pOmgeving = json.issues.fields.customfield_10068.value[0]
   pTypeIssue = json.issues.fields.issuetype.name[0]
   pKey = json.issues.key[0] 
   pURL = json.issues.self[0]
   pTeam = options.d
   pSummary = json.issues.fields.summary[0]
   pAssignee = json.issues.fields.assignee.emailAddress[0] 
   pProject = json.issues.fields.project.projectCategory.name[0] 
   pSource = json.issues.fields.customfield_10107.value[0]
   pAutoDeploy_tmp = json.issues.fields.customfield_10108.value[0]
   pStopEnv_tmp = json.issues.fields.customfield_10082.value[0]
   pDeployTool=json.issues.fields.customfield_10617.value[0]
   pEpic = json.issues.fields.customfield_10008[0]
   pDDL = json.issues.fields.customfield_10057[0]
   pODI = json.issues.fields.customfield_10056[0]

   pDeployType = json.issues.fields.customfield_10183.value[0]

   if (pDeployType == null || pDeployType.size() <= 0){ pDeployType="Normale Deploy" }

   if (pDeployTool == null || pDeployTool.size() <= 0){ pDeployTool="TraceIt" }

   pDeployTool = pDeployTool.toUpperCase()

   pTIRelease = json.issues.fields.customfield_10084[0]
   pTIProject = json.issues.fields.customfield_10085[0]
   pTIProjectID = json.issues.fields.customfield_10096[0]

   pReleaseType = json.issues.fields.customfield_10109.value[0]

   if ( pStopEnv_tmp != null && pStopEnv_tmp != "None") {
      pStopEnv = pStopEnv_tmp.substring(0,1)
   }

   if ( pAutoDeploy_tmp != null && pAutoDeploy_tmp != "None") {
      pAutoDeploy = pAutoDeploy_tmp.substring(0,1)
   }

   json.issues.fields.components.each() { component ->
      pComponent=component.name.value.join(";")
   }

   if (pComponent.size() <= 0){ pComponent="CIVL"}

   pBuild = options.b

   if (pDDL != null) { pDDL=pDDL.trim() }
   if (pODI != null) { pODI=pODI.trim() }

   if (pDDL) { 
      pDDL=pDDL.replaceAll("\\n", ";");
      pDDL=pDDL.replaceAll("\\r", "");
   } else {
      pDDL=""
   }

   if (pODI) {
      pODI=pODI.replaceAll("\\n", ";");
      pODI=pODI.replaceAll("\\r", "");
   } else {
      pODI=""
   }

   //Prep TI summary
   if (pSummary.length() > 50){
      TISummary=pSummary.substring(0,50)
   }
   else
   {
      TISummary=pSummary
   }

   List PropList = new ArrayList()

   PropList.add("BLDR_Omgeving="+pOmgeving)
   PropList.add("BLDR_TicketID="+pKey)
   PropList.add("BLDR_URL="+pURL)
   PropList.add("BLDR_Team="+pTeam)
   PropList.add("BLDR_Summary="+pSummary)
   PropList.add("BLDR_Assignee="+pAssignee)
   PropList.add("BLDR_Project="+pProject)
   PropList.add("BLDR_Source="+pSource)
   PropList.add("BLDR_DDL_List="+pDDL)
   PropList.add("BLDR_ODI_List="+pODI)
   PropList.add("BLDR_Stop_Env="+pStopEnv)
   PropList.add("BLDR_Epic="+pEpic)
   PropList.add("BLDR_TIProject="+pTIProject)
   PropList.add("BLDR_TIRelease="+pTIRelease)
   PropList.add("BLDR_TIProjectID="+pTIProjectID)
   PropList.add("BLDR_ReleaseType="+pReleaseType)

   switch (pDeployType) {
        case "Normale Deploy":
            pDeployShort="NORMAL_DPLY"
            pDeployADC = pOmgeving+"_"+"EDW"
            break
        case "Stop ODI omgeving":
            pDeployShort="ODI_STOP"
            pDeployADC = pOmgeving+"_"+"AA"
            break
        case "Start ODI omgeving":
            pDeployShort="ODI_START"
            pDeployADC = pOmgeving+"_"+"AA"
            break
        case "Run ODI scenario/loadplan":
            pDeployShort="ODI_RUN"
            pDeployADC = pOmgeving+"_"+"AA"
            break
        default:
            pDeployShort="NORMAL_DPLY"
            pDeployADC = pOmgeving+"_"+"EDW"
            break
   }

   PropList.add("BLDR_TIADC="+pDeployADC)
   PropList.add("BLDR_AutoBuild="+pBuild)
   PropList.add("BLDR_AutoDeployACC="+pAutoDeploy)
   PropList.add("BLDR_TIOmschrijving="+pOmgeving+" Patch - "+pKey)
   PropList.add("BLDR_TITeam=DWH - Analyse")
   PropList.add("BLDR_BuildRequest="+datePart+'-'+timePart)
   PropList.add("BLDR_ReleaseItemType="+pReleaseItemType)
   PropList.add("BLDR_TypeStory="+pTypeIssue)
   PropList.add("BLDR_Component="+pComponent)
   PropList.add("BLDR_DeployType="+pDeployType)
   PropList.add("BLDR_DeployShort="+pDeployShort)
   PropList.add("BLDR_Deploytool="+pDeployTool)

   File flist = new File(options.o)
   flist.write("")
   PropList.each { listitem ->
      flist << listitem+"\n" }
}

if (options.t == "epic") {

   pTIRelease=json.issues.fields.customfield_10084.value[0]
   pTIProject=json.issues.fields.customfield_10085.value[0]
   pTIProjectID=json.issues.fields.customfield_10096[0]

   List PropList = new ArrayList()

   PropList.add("BLDR_TIProject="+pTIProject)
   PropList.add("BLDR_TIRelease="+pTIRelease)
   PropList.add("BLDR_TIProjectID="+pTIProjectID)

   File flist = new File(options.o)
   flist.append("")
   PropList.each { listitem ->
      flist << listitem+"\n" }
}


