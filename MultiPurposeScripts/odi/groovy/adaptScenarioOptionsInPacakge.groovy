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

def adaptScenarioOptionsInPacakge(packageName) {
  
  txnDef = new DefaultTransactionDefinition();
  tm = odiInstance.getTransactionManager()
  txnStatus = tm.getTransaction(txnDef)

  lPackage = ((IOdiPackageFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiPackage.class)).findByName(packageName);
  for (Step step : lPackage[0].getSteps()){
    if (step.getName() == 'CIVL_S_9090_START_FILE_RUN'){
      step.setCommandExpression(new Expression('OdiStartScen "-SCEN_NAME=CIVL_S_9090_START_FILE_RUN" "-SCEN_VERSION=001" "-AGENT_CODE=" "-CIVL.P_FILE_ARRIVAL_LOCATION=#CIVL.P_FILE_ARRIVAL_LOCATION" "-CIVL.P_FILE_WORK_NAME=#CIVL.P_FILE_WORK_NAME" "-CIVL.P_FILE_WORKING_LOCATION=#CIVL.P_FILE_WORKING_LOCATION" "-CIVL.P_FILE_NAME=#CIVL.P_FILE_NAME" "-CIVL.P_FILE_RUN_ID=#CIVL.P_FILE_RUN_ID" ',null, Expression.SqlGroupType.NONE));
      lScenario = ((IOdiScenarioFinder) odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findBySourcePackage(lPackage[0].getPackageId());
      scGenImpl = new OdiScenarioGeneratorImpl(odiInstance);
      scGenImpl.regenerateLatestScenario(lScenario[0].getName());
      println(lScenario[0].getName());
    }
  }
  // commit
  odiInstance.getTransactionalEntityManager().persist(lPackage);
  tm.commit(txnStatus);
  
}


//--------------------------------------------- WEL AANKOMEN ------------------------------------------------------------

/*
SELECT pack.pack_name, 'adaptScenarioOptionsInPacakge('''||pack.pack_name||''');' stmt
  FROM civl4_odi_repo.snp_package pack
  JOIN civl4_odi_repo.snp_folder subf ON (pack.i_folder = subf.i_folder)
  JOIN civl4_odi_repo.snp_folder fold ON (subf.PAR_I_FOLDER = fold.i_folder)
 WHERE fold.folder_name = '00_FILE_TO_SRC';
*/

adaptScenarioOptionsInPacakge('CIVL_PA_001206_QUION_MAAND_FINANCIEEL');
adaptScenarioOptionsInPacakge('CIVL_PA_001208_QUION_MAAND_CRMA_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001202_QUION_MAAND_DEELLENINGEN_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001203_QUION_MAAND_BEREKENDE_WAARDEN_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001204_QUION_MAAND_E1011_LGD_MODULE');
adaptScenarioOptionsInPacakge('CIVL_PA_001209_QUION_MAAND_ONDERPANDEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001202_QUION_MAAND_DEELLENINGEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001207_QUION_MAAND_LENINGNEMERS');
adaptScenarioOptionsInPacakge('CIVL_PA_001204_QUION_MAAND_E1011_LGD_MODULE_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001206_QUION_MAAND_FINANCIEEL_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001208_QUION_MAAND_CRMA');
adaptScenarioOptionsInPacakge('CIVL_PA_001203_QUION_MAAND_BEREKENDE_WAARDEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001201_QUION_MAAND_LENINGEN_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001201_QUION_MAAND_LENINGEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001207_QUION_MAAND_LENINGNEMERS_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001214_QUION_BKR_TTS');
adaptScenarioOptionsInPacakge('CIVL_PA_001211_QUION_MAAND_VERLIEZEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001212_QUION_DAG_ACHTERSTANDEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001210_QUION_MAAND_POLISSEN_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001209_QUION_MAAND_ONDERPANDEN_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001210_QUION_MAAND_POLISSEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001211_QUION_MAAND_VERLIEZEN_IL');
adaptScenarioOptionsInPacakge('CIVL_PA_001213_QUION_MAAND_BOEKINGEN');
adaptScenarioOptionsInPacakge('CIVL_PA_0009_REF_CIDER_PARAMETERS');
adaptScenarioOptionsInPacakge('CIVL_PA_0009_REF_CIDER_PAND_INDEXEN');
adaptScenarioOptionsInPacakge('CIVL_PA_0009_REF_CIDER_BLACKLISTED_LOANS');
adaptScenarioOptionsInPacakge('CIVL_PA_0009_REF_CIDER_PERIODES_UITSLUITEN');
adaptScenarioOptionsInPacakge('CIVL_PA_001001_RRM_RB');
adaptScenarioOptionsInPacakge('CIVL_PA_001001_RRM_RBI');
adaptScenarioOptionsInPacakge('CIVL_PA_0011_REF_BIII_RATING_GRADE');
adaptScenarioOptionsInPacakge('CIVL_PA_001701_LELEUX_MCE');
adaptScenarioOptionsInPacakge('CIVL_PA_001709_LELEUX_WSL');
adaptScenarioOptionsInPacakge('CIVL_PA_001702_LELEUX_MTI');
adaptScenarioOptionsInPacakge('CIVL_PA_001703_LELEUX_ORD');
adaptScenarioOptionsInPacakge('CIVL_PA_001704_LELEUX_ORJ');
adaptScenarioOptionsInPacakge('CIVL_PA_001705_LELEUX_PRV');
adaptScenarioOptionsInPacakge('CIVL_PA_001706_LELEUX_RIP');
adaptScenarioOptionsInPacakge('CIVL_PA_001707_LELEUX_SIT');
adaptScenarioOptionsInPacakge('CIVL_PA_001708_LELEUX_TIT');
adaptScenarioOptionsInPacakge('CIVL_PA_000119_UL3_VNV_CRN');
adaptScenarioOptionsInPacakge('CIVL_PA_000102_UL3_VNV_ISR_PAY_ACC');
adaptScenarioOptionsInPacakge('CIVL_PA_000111_UL3_VNV_BFY_NOM');
adaptScenarioOptionsInPacakge('CIVL_PA_000107_UL3_VNV_ITR_RTE');
adaptScenarioOptionsInPacakge('CIVL_PA_000109_UL3_VNV_BEL');
adaptScenarioOptionsInPacakge('CIVL_PA_000105_UL3_VNV_BEL_UNT');
adaptScenarioOptionsInPacakge('CIVL_PA_000104_UL3_VNV_DPT_MOV');
adaptScenarioOptionsInPacakge('CIVL_PA_000118_UL3_VNV_IVC');
adaptScenarioOptionsInPacakge('CIVL_PA_000117_UL3_VNV_WRB');
adaptScenarioOptionsInPacakge('CIVL_PA_000110_UL3_VNV_BFY');
adaptScenarioOptionsInPacakge('CIVL_PA_000106_UL3_VNV_PRS_REL');
adaptScenarioOptionsInPacakge('CIVL_PA_000115_UL3_VNV_RCV_PMM');
adaptScenarioOptionsInPacakge('CIVL_PA_000108_UL3_VNV_PRD_DGN');
adaptScenarioOptionsInPacakge('CIVL_PA_000112_UL3_VNV_CDE_TBL');
adaptScenarioOptionsInPacakge('CIVL_PA_000101_UL3_VNV_DOS');
adaptScenarioOptionsInPacakge('CIVL_PA_000113_UL3_VNV_FSC_PMM');
adaptScenarioOptionsInPacakge('CIVL_PA_000103_UL3_VNV_DPT');
adaptScenarioOptionsInPacakge('CIVL_PA_000114_UL3_VNV_UDF');
adaptScenarioOptionsInPacakge('CIVL_PA_000116_UL3_VNV_REL_CDA_RCV');
adaptScenarioOptionsInPacakge('CIVL_PA_000202_DQ_COLLIBRA_DATA_QUALITY_RULEBOOK');
adaptScenarioOptionsInPacakge('CIVL_PA_000201_DQ_COLLIBRA_BUSINESS_RULEBOOK');
adaptScenarioOptionsInPacakge('CIVL_PA_000203_DQ_COLLIBRA_LIM_REGISTRY');
adaptScenarioOptionsInPacakge('CIVL_PA_000209_DQ_COLLIBRA_LOGICAL_REGISTRY');
adaptScenarioOptionsInPacakge('CIVL_PA_000206_DQ_COLLIBRA_OVERZICHT_USERS');
adaptScenarioOptionsInPacakge('CIVL_PA_000204_DQ_COLLIBRA_KOLOMMEN_BDV');
adaptScenarioOptionsInPacakge('CIVL_PA_000205_DQ_COLLIBRA_BUSINESS_TERMEN');
adaptScenarioOptionsInPacakge('CIVL_PA_000208_DQ_COLLIBRA_REFERENCE_DATA');
adaptScenarioOptionsInPacakge('CIVL_PA_000207_DQ_COLLIBRA_OVERZICHT_USER_PERSONAS');
adaptScenarioOptionsInPacakge('CIVL_PA_000301_GALVANIZE_CIVL_DATA_QUALITY_RESULTS_DBNIVEAU');
adaptScenarioOptionsInPacakge('CIVL_PA_000303_GALVANIZE_CIVL_SPC_RESULTS');
adaptScenarioOptionsInPacakge('CIVL_PA_000302_GALVANIZE_CIVL_KOLOMMEN_INCL_PROFILERING');
adaptScenarioOptionsInPacakge('CIVL_PA_000301_GALVANIZE_CIVL_DATA_QUALITY_RESULTS');
adaptScenarioOptionsInPacakge('CIVL_PA_000304_GALVANIZE_CIVL_SPC_RESULTS_DBNIVEAU');
adaptScenarioOptionsInPacakge('CIVL_PA_070101_DQ_COLLIBRA_RAPPORTERING_OUT');
adaptScenarioOptionsInPacakge('CIVL_PA_070101_DQ_PROFILERINGSRESULTATEN_OUT');
adaptScenarioOptionsInPacakge('CIVL_PA_000701_RISKPRO_RES_NPV');
adaptScenarioOptionsInPacakge('CIVL_PA_000703_RISKPRO_MSR_INV_REP');
adaptScenarioOptionsInPacakge('CIVL_PA_000702_RISKPRO_RES_LIQ_GAP');
adaptScenarioOptionsInPacakge('CIVL_PA_000407_EBS_I107_DAG');
adaptScenarioOptionsInPacakge('CIVL_PA_000408_EBS_I107_MAAND');
adaptScenarioOptionsInPacakge('CIVL_PA_000401_EBS_XXINT_I005_GL_BALANCES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_000403_MFT_FILE_COPY');
adaptScenarioOptionsInPacakge('CIVL_PA_000402_EBS_XXINT_I005_COA_VALUES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_000404_EBS_KLANT_SALDO_I089_DAG');
adaptScenarioOptionsInPacakge('CIVL_PA_000405_EBS_KLANT_SALDO_I088_MAAND');
adaptScenarioOptionsInPacakge('CIVL_PA_0008_SOLIAM_INSTRUMENTEN');
adaptScenarioOptionsInPacakge('CIVL_PA_0008_SOLIAM_CLEAR_FED');
adaptScenarioOptionsInPacakge('CIVL_PA_0008_SOLIAM_TEGENPARTIJEN');
adaptScenarioOptionsInPacakge('CIVL_PA_0008_SOLIAM_BEWEGINGEN');
adaptScenarioOptionsInPacakge('CIVL_PA_0008_SOLIAM_POSITIES');
adaptScenarioOptionsInPacakge('CIVL_PA_000601_CREDO_DISCLOSURE_REPORT');
adaptScenarioOptionsInPacakge('CIVL_PA_00502_AID_PDM_BRANDPOLISSEN');
adaptScenarioOptionsInPacakge('CIVL_PA_000501_AID_BEWAARSTAAT');
adaptScenarioOptionsInPacakge('CIVL_PA_0019_REF_RENTECURVES');
adaptScenarioOptionsInPacakge('CIVL_PA_0018_JIRA_CIO_PORTFOLIOS');
adaptScenarioOptionsInPacakge('CIVL_PA_0018_JIRA_CIO_PORTFOLIOS_thierry20220712');
adaptScenarioOptionsInPacakge('CIVL_PA_0018_JIRA_CIO_FEATURES');
adaptScenarioOptionsInPacakge('CIVL_PA_009901_CHK_CONSISTENCY_CHECKS');
adaptScenarioOptionsInPacakge('CIVL_PA_009902_CHK_OVERZICHT_DATA_MANAGEMENT');
adaptScenarioOptionsInPacakge('CIVL_PA_009906_CHK_BRON_BDV_COUNT_CONTROLES');
adaptScenarioOptionsInPacakge('CIVL_PA_009907_CHK_CIVL_DATABASE_VELDEN');
adaptScenarioOptionsInPacakge('CIVL_PA_009904_CHK_CIVL_TIMESTAMPS');
adaptScenarioOptionsInPacakge('CIVL_PA_001602_RISKPRO_SBX_RES_LIQ_GAP');
adaptScenarioOptionsInPacakge('CIVL_PA_001601_RISKPRO_SBX_RES_NPV');
adaptScenarioOptionsInPacakge('CIVL_PA_001603_RISKPRO_SBX_MSR_INV_REP');
adaptScenarioOptionsInPacakge('CIVL_PA_0014_WF_FILE_HANDLER');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS338_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS335_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS327_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS336_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS337_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_CA515_CARDS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS328_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS332_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS333_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_CA513_CARDS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS339_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_CA517_CARDS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_CA304_CARDS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS349_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS334_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_CA514_CARDS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS300_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_CA516_CARDS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS507_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS511_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC504_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC50G_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS505_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS519_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS513_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC501_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS512_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS520_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS508_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS501_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS516_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS517_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS503_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS506_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS504_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC505_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_OS300_ORDERS');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC502_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC50H_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS530_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_DS518_DEPOSITS_SAVINGS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC503_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC506_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE510_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE508_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE504_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE300_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE502_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE500_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_PC670_PARTIES_CONTRACTS_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE507_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE501_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE511_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE505_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE509_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE506_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0013_SBP_SE503_SECURITIES_EXT');
adaptScenarioOptionsInPacakge('CIVL_PA_0015_MATRIX_I018_NLM_003B');
adaptScenarioOptionsInPacakge('CIVL_PA_0015_MATRIX_I018_NLM_003C');
adaptScenarioOptionsInPacakge('CIVL_PA_0015_MATRIX_I018_NLM_003F');
adaptScenarioOptionsInPacakge('CIVL_PA_0015_MATRIX_I018_NLM_003A');
adaptScenarioOptionsInPacakge('CIVL_PA_0015_MATRIX_I018_NLM_003D');

