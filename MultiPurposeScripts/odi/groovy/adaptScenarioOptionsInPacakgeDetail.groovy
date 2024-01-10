//adapt scenario options in pacakges + regenerate scenario
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
import oracle.odi.domain.project.finder.*;
import oracle.odi.domain.xrefs.expression.Expression;
import oracle.odi.generation.support.OdiScenarioGeneratorImpl

//--------------------------------------------- NIET AANKOMEN ------------------------------------------------------------

def adaptScenarioOptionsInPacakge(packageName, stepName) {
  
  txnDef = new DefaultTransactionDefinition();
  tm = odiInstance.getTransactionManager()
  txnStatus = tm.getTransaction(txnDef)

  lPackage = ((IOdiPackageFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiPackage.class)).findByName(packageName);
  for (Step step : lPackage[0].getSteps()){
    if (step.getName() == stepName){
      step.setCommandExpression(new Expression('OdiStartScen "-SCEN_NAME='+stepName+'" "-SCEN_VERSION=001" "-AGENT_CODE=" "-CIVL.P_FILE_LOAD_DATE=#CIVL.P_FILE_LOAD_DATE" "-CIVL.P_FILE_LOAD_DATE_FMT=#CIVL.P_FILE_LOAD_DATE_FMT"',null, Expression.SqlGroupType.NONE));
      lScenario = ((IOdiScenarioFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findBySourcePackage(lPackage[0].getPackageId());
      scGenImpl = new OdiScenarioGeneratorImpl(odiInstance);
      scGenImpl.regenerateLatestScenario(lScenario[0].getName());
      println(lScenario[0].getName() + ' - ' + step.getName());
    }
  }
  // commit
  odiInstance.getTransactionalEntityManager().persist(lPackage);
  tm.commit(txnStatus);
  
}


//--------------------------------------------- WEL AANKOMEN ------------------------------------------------------------


adaptScenarioOptionsInPacakge('CIVL_PA_001701_LELEUX_MCE','CIVL_S_0017_LELEUX_MCE_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001702_LELEUX_MTI','CIVL_S_0017_LELEUX_MTI_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001703_LELEUX_ORD','CIVL_S_0017_LELEUX_ORD_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001704_LELEUX_ORJ','CIVL_S_0017_LELEUX_ORJ_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001705_LELEUX_PRV','CIVL_S_0017_LELEUX_PRV_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001706_LELEUX_RIP','CIVL_S_0017_LELEUX_RIP_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001707_LELEUX_SIT','CIVL_S_0017_LELEUX_SIT_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001708_LELEUX_TIT','CIVL_S_0017_LELEUX_MCE_MAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001709_LELEUX_WSL','CIVL_S_0017_LELEUX_WSL_MAP');