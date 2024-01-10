//Remove scenario
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

def removeScenario(scenarioName) {
  
  txnDef = new DefaultTransactionDefinition();
  tm = odiInstance.getTransactionManager()
  txnStatus = tm.getTransaction(txnDef)

  lScenario = ((IOdiScenarioFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findLatestByName(scenarioName);
  lScenario.getScenarioFolder().removeScenario(lScenario);
  // commit
  odiInstance.getTransactionalEntityManager().persist(lScenario);
  tm.commit(txnStatus);
  
}


//--------------------------------------------- WEL AANKOMEN ------------------------------------------------------------

removeScenario('SCEN_SRC_SBP_PC503_TDFT_INCR');
removeScenario('SCEN_EXT_SBP_PC502_INCR');
removeScenario('SCEN_EXT_SBP_PC503_INCR');
removeScenario('SCEN_STG_DL_SBP_PC503_INCR');
removeScenario('SCEN_STG_SBP_PC502_INCR');
removeScenario('SCEN_EXT_SBP_PC502_INIT');
removeScenario('SCEN_EXT_SBP_PC503_INIT');
removeScenario('SCEN_STG_DL_SBP_PC503_INIT');
removeScenario('SCEN_STG_SBP_PC502_INIT');
removeScenario('SCEN_LKS_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INCR');
removeScenario('SCEN_LKS_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INCR');
removeScenario('SCEN_LKS_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INCR');
removeScenario('SCEN_LKS_SBP_DS501_DS503_INCR');
removeScenario('SCEN_LKS_SBP_DS504_DS503_INCR');
removeScenario('SCEN_LKS_SBP_DS505_DS503_INCR');
removeScenario('SCEN_LKS_SBP_DS508_DS503_INCR');
removeScenario('SCEN_LKS_SBP_DS511_DS503_INCR');
removeScenario('SCEN_LKS_SBP_DS511_KANTOREN_INCR');
removeScenario('SCEN_LKS_SBP_DS517_DS503_INCR');
removeScenario('SCEN_LKS_SBP_SE505_SE505_SE505_INCR');
removeScenario('SCEN_LNK_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INCR');
removeScenario('SCEN_LNK_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INCR');
removeScenario('SCEN_LNK_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INCR');
removeScenario('SCEN_LNK_SBP_SE505_SE505_SE505_INCR');
removeScenario('SCEN_SAT_SBP_DS334CLIENTNOTIFICATIONDATA_INCR');
removeScenario('SCEN_STG_SBP_DS334CLIENTNOTIFICATIONDATA_INCR');
removeScenario('SCEN_LKS_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INIT');
removeScenario('SCEN_LKS_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INIT');
removeScenario('SCEN_LKS_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INIT');
removeScenario('SCEN_LKS_SBP_DS501_DS503_INIT');
removeScenario('SCEN_LKS_SBP_DS504_DS503_INIT');
removeScenario('SCEN_LKS_SBP_DS505_DS503_INIT');
removeScenario('SCEN_LKS_SBP_DS508_DS503_INIT');
removeScenario('SCEN_LKS_SBP_DS511_DS503_INIT');
removeScenario('SCEN_LKS_SBP_DS511_KANTOREN_INIT');
removeScenario('SCEN_LKS_SBP_DS517_DS503_INIT');
removeScenario('SCEN_LKS_SBP_SE505_SE505_SE505_INIT');
removeScenario('SCEN_LNK_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INIT');
removeScenario('SCEN_LNK_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INIT');
removeScenario('SCEN_LNK_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INIT');
removeScenario('SCEN_LNK_SBP_SE505_SE505_SE505_INIT');
removeScenario('SCEN_SAT_SBP_DS334CLIENTNOTIFICATIONDATA_INIT');
removeScenario('SCEN_LKS_SBP_DS513_DS503_INCR');
removeScenario('SCEN_LKS_SBP_DS513_DS503_INIT');



