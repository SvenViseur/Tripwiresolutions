//Created by ODI Studio
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.domain.project.OdiFolder
import oracle.odi.domain.project.finder.IOdiFolderFinder
import java.util.regex.Pattern

def removeMapping(String pMapName){

      txnDef = new DefaultTransactionDefinition();
      tm = odiInstance.getTransactionManager()
      txnStatus = tm.getTransaction(txnDef)

	def project = "CIVL"

	def mappings = ((IMappingFinder)odiInstance.getTransactionalEntityManager().getFinder(Mapping.class)).findByName( pMapName, project)
	for (def mapping : mappings) {

		println("............Working on mapping "+ mapping.getName())

		mapping.getFolder().removeMapping(mapping)
		odiInstance.getTransactionalEntityManager().remove(mapping)

	}
	println("<<<<<<Commiting>>>>>>")

	tm.commit(txnStatus);

}

def project = "CIVL"

removeMapping("EXT_SBP_PC503_INCR")
removeMapping("LKS_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INCR")
removeMapping("LKS_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INCR")
removeMapping("LKS_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INCR")
removeMapping("LKS_SBP_DS501_DS503_INCR")
removeMapping("LKS_SBP_DS504_DS503_INCR")
removeMapping("LKS_SBP_DS505_DS503_INCR")
removeMapping("LKS_SBP_DS508_DS503_INCR")
removeMapping("LKS_SBP_DS511_DS503_INCR")
removeMapping("LKS_SBP_DS511_KANTOREN_INCR")
removeMapping("LKS_SBP_DS513_DS503_INCR")
removeMapping("LKS_SBP_DS517_DS503_INCR")
removeMapping("LKS_SBP_SE505_SE505_SE505_INCR")
removeMapping("LNK_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INCR")
removeMapping("LNK_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INCR")
removeMapping("LNK_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INCR")
removeMapping("LNK_SBP_SE505_SE505_SE505_INCR")
removeMapping("SAT_SBP_DS334CLIENTNOTIFICATIONDATA_INCR")
removeMapping("SRC_SBP_PC502_TDFT_INCR")
removeMapping("SRC_SBP_PC503_TDFT_INCR")
removeMapping("STG_DL_SBP_PC503_INCR")
removeMapping("STG_SBP_DS334CLIENTNOTIFICATIONDATA_INCR")
removeMapping("STG_SBP_PC502_INCR")

removeMapping("EXT_SBP_PC502_INIT")
removeMapping("EXT_SBP_PC503_INIT")
removeMapping("LKS_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INIT")
removeMapping("LKS_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INIT")
removeMapping("LKS_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INIT")
removeMapping("LKS_SBP_DS501_DS503_INIT")
removeMapping("LKS_SBP_DS504_DS503_INIT")
removeMapping("LKS_SBP_DS505_DS503_INIT")
removeMapping("LKS_SBP_DS508_DS503_INIT")
removeMapping("LKS_SBP_DS511_DS503_INIT")
removeMapping("LKS_SBP_DS511_KANTOREN_INIT")
removeMapping("LKS_SBP_DS513_DS503_INIT")
removeMapping("LKS_SBP_DS517_DS503_INIT")
removeMapping("LKS_SBP_SE505_SE505_SE505_INIT")
removeMapping("LNK_SBP_DS334CLIENTNOTIFICATIONDATA_DS334_INIT")
removeMapping("LNK_SBP_DS334CLIENTNOTIFICATIONDATA_KANTOREN_INIT")
removeMapping("LNK_SBP_DS334CLIENTNOTIFICATIONDATA_PC504_INIT")
removeMapping("LNK_SBP_SE505_SE505_SE505_INIT")
removeMapping("SAT_SBP_DS334CLIENTNOTIFICATIONDATA_INIT")
removeMapping("STG_DL_SBP_PC503_INIT")
removeMapping("STG_SBP_PC502_INIT")


println("Process Completed");


println("SCRIPT COMPLETED......................................!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");