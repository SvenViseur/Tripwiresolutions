import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.generation.support.OdiScenarioGeneratorImpl
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication


def workOnFolder(pFolder){
        def folder = ((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findByName(pFolder)
	println("Scenario Folder " + folder.getName())
	def odiScenarios = []
	def scGenImpl
	def scenFld
	def curScen
	def scenGens = []
	odiScenarios =  folder.getScenarios()
	for (def odiScenario : odiScenarios) {
		ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
		def tm = odiInstance.getTransactionManager()
		try{
			println("............Working on scenario "+odiScenario.getName() + " Version "+odiScenario.getVersion())
			scenGens.add(odiScenario)
			scGenImpl = new OdiScenarioGeneratorImpl(odiInstance)
			scGenImpl.regenerateLatestScenario(odiScenario.getName())
			print ("............Commiting work")
			tm.commit(trans)
		}
		catch (e) {
			println("Exception catched while creating scenario "+odiScenario.getName()+" : error : " + e)
			println("....Rollback work")
			tm.rollback(trans)
		}
	}
	def scenFolders = folder.getSubFolders()
	for (def scenFolder : scenFolders){
		workOnFolder(scenFolder)
	}
}



def workOnProjectFolder(pFolder){
        def folder = ((IOdiScenarioFolderFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenarioFolder.class)).findByName(pFolder)
	println("Scenario Folder " + folder.getName())
	def odiScenarios = []
	def scGenImpl
	def scenFld
	def curScen
	def scenGens = []
	odiScenarios =  folder.getScenarios()
	for (def odiScenario : odiScenarios) {
		ITransactionStatus trans = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
		def tm = odiInstance.getTransactionManager()
		try{
			println("............Working on scenario "+odiScenario.getName() + " Version "+odiScenario.getVersion())
			scenGens.add(odiScenario)
			scGenImpl = new OdiScenarioGeneratorImpl(odiInstance)
			scGenImpl.regenerateLatestScenario(odiScenario.getName())
			print("............Commiting work")
			tm.commit(trans)
		}
		catch (e) {
			println("Exception catched while creating scenario "+odiScenario.getName()+" : error : " + e)
			println("....Rollback work")
			tm.rollback(trans)
		}
	}
	def scenFolders = folder.getSubFolders()
	for (def scenFolder : scenFolders){
		workOnFolder(scenFolder)
	}
}

workOnFolder("05_FL_TO_BDV");

println("Process Completed");

