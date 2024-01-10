//Generate loadplans
//SH - 20/04/2021

import oracle.odi.core.persistence.transaction.ITransactionDefinition;
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition;
import oracle.odi.core.persistence.transaction.ITransactionManager;
import oracle.odi.core.persistence.transaction.ITransactionStatus;
import oracle.odi.core.persistence.IOdiEntityManager;
import oracle.odi.domain.project.OdiProject;
import oracle.odi.domain.project.OdiVariable;
import oracle.odi.domain.project.finder.IOdiProjectFinder;
import oracle.odi.domain.project.finder.IOdiVariableFinder;
import oracle.odi.domain.topology.finder.IOdiLogicalSchemaFinder;
import oracle.odi.domain.topology.finder.IOdiLogicalAgentFinder;
import oracle.odi.domain.topology.finder.IOdiContextFinder;
import org.codehaus.groovy.runtime.*;
import oracle.odi.domain.topology.OdiLogicalSchema;
import oracle.odi.domain.xrefs.expression.ExpressionStringBuilder;
import oracle.odi.languages.ILanguageProvider;
import oracle.odi.languages.support.LanguageProviderImpl;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan;
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder;
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder;
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder;
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder;
import oracle.odi.domain.runtime.scenario.OdiScenario;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanElement;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanStep;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanStepContainer;
import oracle.odi.domain.topology.OdiLogicalAgent;
import oracle.odi.domain.topology.OdiContext;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanStepParallel;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanStepParallel.RestartType;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanStepRunScenario;
import oracle.odi.domain.runtime.loadplan.OdiCaseWhen.*;
import oracle.odi.generation.support.OdiVariableTextGeneratorDwgImpl;
import oracle.odi.generation.*;

//--------------------------------------------- NIET AANKOMEN ------------------------------------------------------------


// functie om alles scenarios uit scenariosubfolders onder een opgegeven scenariofolder toe te voegen aan een loadplan
// Scenariofoldername
//  + Scenariofoldername_1
//  ++Scenario11
//  ++Scenario12
//  ++Scenario13
//  + Scenariofoldername_2
//  ++Scenario21
//  ++Scenario22
//  ++Scenario23
//  + Scenariofoldername_X
//  ++ScenarioX1
//  ++ScenarioX2
//  ++ScenarioX3
// de scenarios worden toegevoegd onder parallel stappen in het loadplan
// de foldernamen van de subfolders worden gebruikt als naam voor de parallele stappen in het loadplan
// restarttype van de parallele stap wordt op RESTART_FAILED_CHILDREN gezet

def addScenarios(loadPlanName,folderName, stepName, filterMask) {
	
  lPlan = ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(loadPlanName);
  lScenarioFolder = ((IOdiScenarioFolderFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findByName(folderName);
  root = lPlan.getRootStep();
  if (!lScenarioFolder) {
	  return;
  }
  folderlist = lScenarioFolder.getSubFolders();
  //find start step
  lParentStep = root.getChildrenSteps().find { item -> item.getName() == 'Serial' }.getChildrenSteps().find { item -> item.getName() == 'Case Variable: CIVL.P_FILE_RUN_ID' }.getCaseWhenList().find { item -> item.getName() == 'When Value > 0'}.getRootStep().getChildrenSteps().find { item -> item.getName() == stepName };

  
  
  if (lParentStep == null) {
    
    root.getChildrenSteps().find { item -> item.getName() == 'Serial' }.getChildrenSteps().find { item -> item.getName() == 'Case Variable: CIVL.P_FILE_RUN_ID' }.getCaseWhenList().find { item -> item.getName() == 'When Value > 0'}.getRootStep().addStepSerial(stepName);
    lParentStep = root.getChildrenSteps().find { item -> item.getName() == 'Serial' }.getChildrenSteps().find { item -> item.getName() == 'Case Variable: CIVL.P_FILE_RUN_ID' }.getCaseWhenList().find { item -> item.getName() == 'When Value > 0'}.getRootStep().getChildrenSteps().find { item -> item.getName() == stepName };
    
  }

	
  if (folderName == '00_FILE_TO_SRC') {
        lSrcScenarioFolder = lScenarioFolder.getSubFolders().find { item -> item.getName().contains(filterMask) }
	//maak een nieuwe lijst van de "unmodifiable" collection
	List list = new ArrayList<OdiScenario>();
	for (OdiScenario scen : lSrcScenarioFolder.getScenarios()){
		// filter de scenario's aan de hand van de parameter "filterMask"
		if (scen.getName().matches('.*'+filterMask+'.*')) {
			list.add(scen);
		}
	}
	//maak een comparator zodat we kunnen sorteren
	Comparator<OdiScenario> compScen = new Comparator<OdiScenario>(){
		@Override
		public int compare(OdiScenario o1, OdiScenario o2) {
			return o1.getName().compareTo(o2.getName());
		}
	};
	//sorteer de lijst alfabetisch
	Collections.sort(list, compScen);
	//split de lijst als er te veel scenario's in de folder zitten
	int i = 0;
	int batchSize = 10;
	List<List<OdiScenario>> batches = new ArrayList<List<OdiScenario>>();
	
	while (i<list.size()){
		int nextInc = Math.min(list.size()-i,batchSize);
		//println('listsize:' + list.size() + ' - batchsize: ' + batchSize + ' => nextInc: ' + nextInc);
        List<OdiScenario> batch = list.subList(i,i+nextInc);
        batches.add(batch);
        i = i + nextInc;
	}
	int batchNr = 0;
	for (List<OdiScenario> batch : batches){
		++batchNr;
		lParentStep.addStepParallel('BATCH'+batchNr);
		lSubStep = lParentStep.getChildrenSteps().find { item -> item.getName() == 'BATCH'+batchNr }
		restarttype =  OdiLoadPlanStepParallel.RestartType.valueOf('PARALLEL_STEP_FAILED_CHILDREN');
		lSubStep.setRestartType(restarttype);
		for (OdiScenario scn : batch) {
			// wanneer de target folder gelijk is aan "Serial FILE > SRC" dan mogen alleen de scenario's van de packages genomen worden
			if (stepName == 'Serial FILE > SRC') {
				if (scn.getSourceComponentClass().getName() == 'oracle.odi.domain.project.OdiPackage') { 
					lSubStep.addStepRunScenario(scn.getName(),scn, null , null);
				}
			} else {
				lSubStep.addStepRunScenario(scn.getName(),scn, null , null);
			}
		}
	}
  } else {
  
  for (OdiScenarioFolder folder : folderlist) {

	if ((folder.getName().matches('.*'+filterMask+'.*') && filterMask != "")  || filterMask == ""){    
                
		foldername = folder.getName();   
		list = folder.getScenarios();
                
		//maak step aan
                if (folder.getName().contains("HUB")){
                  lParentStep.addStepSerial(foldername);
                  loadplanstep = lParentStep.getChildrenSteps().find { item -> item.getName() == foldername}
                } else {
                  lParentStep.addStepParallel(foldername);
                  loadplanstep = lParentStep.getChildrenSteps().find { item -> item.getName() == foldername}
                  restarttype =  OdiLoadPlanStepParallel.RestartType.valueOf('PARALLEL_STEP_FAILED_CHILDREN');
                  loadplanstep.setRestartType(restarttype)                  
                }
	 
		for (OdiScenario scn : list) {
			if (scn.getName().contains("INCR")) {
                            loadplanstep.addStepRunScenario(scn.getName(),scn, null , null) 
                        }
                    }
                }
                
                listPD = folder.getScenarios().find { item -> item.getName().matches('.*PREP_DELETE') }
                if (listPD != null){
                  //voor EX > STG mappings nog een extra opsplitsing nodig voor PREP_DELETE mappings
                  foldername = folder.getName()+'_PREP_DELETE';
                  
                  //maak parallel step aan
                  lParentStep.addStepParallel(foldername);
                  loadplanstep = lParentStep.getChildrenSteps().find { item -> item.getName() == foldername}        
                  restarttype =  OdiLoadPlanStepParallel.RestartType.valueOf('PARALLEL_STEP_FAILED_CHILDREN');
                  loadplanstep.setRestartType(restarttype);
           
                  for (OdiScenario scn : list) {
                          if (scn.getName().contains("PREP_DELETE")) {
                              loadplanstep.addStepRunScenario(scn.getName(),scn, null , null) 
                          }
                  }
                }
	}
  }
}

//functie om scenario toe te voegen aan loadplan
//de naam van het scenario wordt gebruikt voor de naam van de loadplanstep
def addScenario(loadPlanName,scenarioName) {

  lPlan = ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(loadPlanName);
  lScenario = ((IOdiScenarioFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findLatestByName(scenarioName);
  root = lPlan.getRootStep();
  scnname = lScenario.getName();
  restarttype =  OdiLoadPlanStepRunScenario.RestartType.valueOf('RUN_SCENARIO_NEW_SESSION');
     
  root.addStepRunScenario(scnname,lScenario, null , null).setRestartType(restarttype);  
}

// deleten van alle stappen SRC, EX, STG en RDV laag van een loadplan
def deleteSteps(loadPlanName) {

  lPlan = ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(loadPlanName);
  root = lPlan.getRootStep();
  lParentStep = root.getChildrenSteps().find { item -> item.getName() == 'Serial' }.getChildrenSteps().find { item -> item.getName() == 'Case Variable: CIVL.P_FILE_RUN_ID' }.getCaseWhenList().find { item -> item.getName() == 'When Value > 0'}.getRootStep().getChildrenSteps();
  
  for (OdiLoadPlanStep stp : lParentStep) {
       
	if (stp.getClass().getName() == 'oracle.odi.domain.runtime.loadplan.OdiLoadPlanStepSerial' || stp.getClass().getName() == 'oracle.odi.domain.runtime.loadplan.OdiLoadPlanStepParallel'){
	   if (stp.getName().matches(".*(FILE > SRC|SRC > EX|EX > STG|STG > RDV|SRC > DFV|DFV > EX).*")){
		
		for (OdiLoadPlanStep substp : stp.getChildrenSteps()) {
    
			lPlan.removeStep(substp);
			//println(' -- '+substp.getName());
		}
	   }
	}
  }   
  
}

// Toevoegen van een serial step
def addSerial(loadPlanName, serialName) {

  lPlan = ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(loadPlanName);
  root = lPlan.getRootStep();
  
  //Voeg Serial toe
  root.addStepSerial(serialName);
  
}

// Toevoegen van een variable aan het lp
def addVariable(loadPlanName, varName) {
	
  varTextGen = new OdiVariableTextGeneratorDwgImpl(odiInstance)

  lPlan = ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(loadPlanName);
  lVar = ((IOdiVariableFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiVariable.class)).findByQualifiedName(varName);

  lPlanVariable = lPlan.addVariable(lVar, varTextGen);

}

// Toevoegen van een case aan het lp
def addCase(loadPlanName, caseName, varName, stepName) {
	
  lPlan = ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(loadPlanName);
  root = lPlan.getRootStep();
  lStep = root.getChildrenSteps().find { item -> item.getName() == stepName };

  lStep.addStepCase(caseName,lPlan.getVariableIfExistsInLoadPlan(varName));
  
  //lCase = lStep.getChildrenSteps().find { item -> item.getName() == caseName };
  //lCase.addCaseWhen(OdiCaseWhen.ComparisonOperator, '0');

}


def initLoadplan(loadPlanName, source, typ) {
  // init 
  println('Init Loadplan : '+ loadPlanName);
  
  txnDef = new DefaultTransactionDefinition();
  tm = odiInstance.getTransactionManager()
  txnStatus = tm.getTransaction(txnDef)
  
  // clean loadplan
  println('-- delete oude scenario steps');
  deleteSteps(loadplanname);
  
  odiInstance.getTransactionalEntityManager().persist(lPlan);
  tm.commit(txnStatus);
  
  txnDef = new DefaultTransactionDefinition();
  tm = odiInstance.getTransactionManager()
  txnStatus = tm.getTransaction(txnDef)
  
  // laad de FILE mappings
  println('-- laad FILE to SRC laag'); 
  addScenarios(loadplanname,'00_FILE_TO_SRC','Serial FILE > SRC',source);
  
  if (typ == 'INIT') {
	  // laad de EXT mappings
	  println('-- laad EXT laag');
	  addScenarios(loadplanname,'EXT_'+typ+'_'+source, 'Serial SRC > EX',''); 
  }
  
  if (typ == 'INCR') {
	  
	  // laad de SRC mappings
	  println('-- laad SRC laag');
	  addScenarios(loadplanname,'SRC_'+typ+'_'+source, 'Serial SRC > DFV',''); 

	  // laad de EXT mappings
	  println('-- laad EXT laag');
	  addScenarios(loadplanname,'EXT_'+typ+'_'+source, 'Serial DFV > EX',''); 	  
	  
  }
  // laad de STG mappings
  println('-- laad STG laag');
  addScenarios(loadplanname,'STG_'+typ+'_'+source, 'Serial EX > STG',''); 
  
  // laad de STG DL mappings
  println('-- laad STG DL laag');
  addScenarios(loadplanname,'STG_DL_'+typ+'_'+source, 'Serial EX > STG',''); 

  // laad de HUB mappings
  println('-- laad RDV laag (HUB)');
  addScenarios(loadplanname,'HUB_'+typ+'_'+source, 'Serial STG > RDV',''); 

  // laad de LNK mappings
  println('-- laad RDV laag (LNK)');
  addScenarios(loadplanname,'LNK_'+typ+'_'+source, 'Serial STG > RDV','');

  // laad de SAT mappings
  println('-- laad RDV laag (SAT)');
  addScenarios(loadplanname,'SAT_'+typ+'_'+source, 'Serial STG > RDV','');   

  // laad de LKS mappings
  println('-- laad RDV laag (LKS)');
  addScenarios(loadplanname,'LKS_'+typ+'_'+source, 'Serial STG > RDV','');

  // laad de NHL mappings
  println('-- laad RDV laag (NHL)');
  addScenarios(loadplanname,'NHL_'+typ+'_'+source, 'Serial STG > RDV','');

  // laad de LND mappings !!!!! uitzondering voor LND omdat de folder naam iets anders is !!!!
  println('-- laad RDV laag (LND)');
  if (typ == 'INCR') {
	addScenarios(loadplanname,'LND_'+source, 'Serial STG > RDV','');   
  } else {
	addScenarios(loadplanname,'LND_'+typ+'_'+source, 'Serial STG > RDV',''); 
  }	

  // laad de LDS mappings 
  println('-- laad RDV laag (LDS)');
  addScenarios(loadplanname,'LDS_'+typ+'_'+source, 'Serial STG > RDV','');

  // laad de REF mappings
  println('-- laad RDV laag (REF)');
  addScenarios(loadplanname,'REF_'+typ+'_'+source, 'Serial STG > RDV','');
 
  // commit
  println('Finish Loadplan : '+ loadPlanName);
  odiInstance.getTransactionalEntityManager().persist(lPlan);
  tm.commit(txnStatus);
  
}

//--------------------------------------------- WEL AANKOMEN ------------------------------------------------------------


// loadplan naam: het loadplan moet bestaan, anders crasht het script :)
source = 'SBP';

loadplanname = 'CIVL_LP_900236_SBP_INCR_LOAD';

initLoadplan(loadplanname, source, 'INCR');
