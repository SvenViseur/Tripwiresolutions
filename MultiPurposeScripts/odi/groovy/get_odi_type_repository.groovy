//Created by DI Studio


import java.util.regex.Pattern
import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiFolder
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.OdiSequence
import oracle.odi.domain.project.OdiVariable
import oracle.odi.domain.project.StepMapping
import oracle.odi.domain.project.Step
import oracle.odi.domain.project.OdiSequence.SequenceType
import oracle.odi.domain.project.finder.IOdiFolderFinder
import oracle.odi.domain.project.finder.IOdiKMFinder
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.domain.model.finder.IOdiColumnFinder
import oracle.odi.domain.model.finder.IOdiDataStoreFinder
import oracle.odi.domain.model.OdiDataStore
import oracle.odi.domain.mapping.component.DatastoreComponent
import oracle.odi.domain.mapping.component.FilterComponent
import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.adapter.project.IKnowledgeModule.ProcessingType
import oracle.odi.domain.project.OdiIKM
import oracle.odi.domain.project.OdiLKM
import oracle.odi.domain.topology.OdiContext
import oracle.odi.domain.topology.OdiContextualSchemaMapping
import oracle.odi.domain.topology.OdiDataServer
import oracle.odi.domain.topology.OdiLogicalSchema
import oracle.odi.domain.topology.OdiPhysicalSchema
import oracle.odi.domain.topology.OdiTechnology
import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.topology.finder.IOdiTechnologyFinder
import oracle.odi.domain.util.ObfuscatedString
import oracle.odi.domain.mapping.expression.MapExpression.ExecuteOnLocation
import oracle.odi.domain.mapping.physical.MapPhysicalNode
import oracle.odi.domain.model.OdiColumn
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFolderFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.generation.support.OdiScenarioGeneratorImpl
import oracle.odi.domain.adapter.flexfields.*
import oracle.odi.domain.topology.finder.IOdiFlexFieldFinder
import oracle.odi.domain.topology.OdiFlexField
import oracle.odi.core.repository.WorkRepository.WorkType


type_design=WorkType.DESIGN
type_runtime=WorkType.RUNTIME

println odiInstance.getWorkRepository().getType() 

repo_type=odiInstance.getWorkRepository().getType() 

//println ((IOdiFlexFieldFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiFlexField.class))
//def flexfield_scenario = ((IOdiFlexFieldFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiFlexField.class)).findByCode('ACTIVE_SCENARIO')

if ( repo_type == type_design ) { println "development" }
if ( repo_type == type_runtime ) { println "run time" }
