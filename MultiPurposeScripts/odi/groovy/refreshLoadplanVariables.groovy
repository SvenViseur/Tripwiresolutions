import oracle.odi.core.persistence.transaction.ITransactionDefinition;
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition;
import oracle.odi.core.persistence.transaction.ITransactionManager;
import oracle.odi.core.persistence.transaction.ITransactionStatus;
import oracle.odi.domain.project.OdiVariable;
import oracle.odi.domain.project.finder.IOdiVariableFinder;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlanVariable;
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder;
import oracle.odi.generation.support.OdiVariableTextGeneratorDwgImpl;

//--------------------------------------------- START FUNCTIE ----------------------------------------------------------
def refreshLoadPlanVars(loadPlanName, varName) {

  // connectie
  txnDef = new DefaultTransactionDefinition();
  tm = odiInstance.getTransactionManager()
  txnStatus = tm.getTransaction(txnDef)
  // zoek loadplan
  if (loadPlanName != null) {
    lPlan = ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findByName(loadPlanName);
    if (!lPlan) { return; } 
    else {
      println('Start Loadplan : '+ loadPlanName);
    }
  }
  
  // zoek variabele
  if (varName != null) {
    lVar = ((IOdiVariableFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiVariable.class)).findByQualifiedName(varName);
    if (!lVar) { return; } 
    else {
      println('Refreh variable : '+varName);
    }
  }  
  
  // als het loadplan en de variabele meegegeven zijn, voeg toe/refresh de variabele
  if (loadPlanName != null && varName != null) {
    lPlan.addVariable(lVar, new OdiVariableTextGeneratorDwgImpl(odiInstance));
  // als het loadplan meegegeven is zonder variable,refresh alle variabelen van het loadplan
  } else if (loadplanName != null && varName == null) {
    List<OdiLoadPlanVariable> rmVar = new ArrayList<OdiLoadPlanVariable>();
    List<OdiLoadPlanVariable> reVar = new ArrayList<OdiLoadPlanVariable>(lPlan.getVariables());
    for (OdiLoadPlanVariable lpvar : reVar){
      var = ((IOdiVariableFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiVariable.class)).findByQualifiedName(lpvar.getName());
      if (var !=null){
        println('Add/Refresh '+var.getName());
        lPlan.addVariable(var,  new OdiVariableTextGeneratorDwgImpl(odiInstance));
      } else {
        rmVar.add(lpvar);
      }
    }
    // verwijder variables die niet meer bestaan
    for (OdiLoadPlanVariable lpvar : rmVar){
      println('Remove var: '+lpvar.getName());
      lPlan.removeVariable(lpvar);
      // als bovenstaande deze fout geeft: "ORA-02292: integrity constraint (CIVL4_ODI_REPO.FK_LP_STVAR_VAR) violated - child record found" dan komt het omdat de variable niet bestaat onder "Designer > Variables".
    }
  // als alleen de variabele meegegeven is,refresh alle loadplannen die deze variabele gebruiken
  } else if (loadPlanName == null && varName != null) {
    for (OdiLoadPlan lp : ((IOdiLoadPlanFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiLoadPlan.class)).findAll()) {
      for (OdiLoadPlanVariable lpvar : lp.getVariables().find {item -> item.getName() == varName}) {
        var = ((IOdiVariableFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiVariable.class)).findByQualifiedName(lpvar.getName());
        println(lp.getName());
        lp.addVariable(var, new OdiVariableTextGeneratorDwgImpl(odiInstance));
        odiInstance.getTransactionalEntityManager().persist(lp);
      }
    }
  }

  // commit 
  tm.commit(txnStatus);
}

//--------------------------------------------- EINDE FUNCTIE ----------------------------------------------------------

// er zijn 3 opties:
// 1. vul beide parameters in voor de refresh van 1 variable
// 2. vul alleen het loadplan in, voor een refresh van alle variable van een loadplan
// 3. vul alleen de variable in, voor een refresh van alle loadplannen die die variable gebruiken

//loadplanName = 'CIVL_LP_9002_ARG_ALG_INCR_LOAD';
loadplanName = null;
varName = 'CIVL.P_CHECK_DB_GG';
//varName = null;

refreshLoadPlanVars(loadplanName, varName);
