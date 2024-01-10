//Created by DI Studio

import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.mapping.finder.IMappingFinder
import oracle.odi.domain.project.finder.IOdiPackageFinder
import oracle.odi.domain.project.finder.IOdiUserProcedureFinder
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder
import oracle.odi.domain.runtime.scenario.OdiScenario
import oracle.odi.domain.project.OdiUserProcedure
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder
import oracle.odi.core.service.deployment.*
import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

import oracle.odi.domain.topology.finder.IOdiContextFinder
import oracle.odi.domain.topology.OdiContext

import oracle.odi.domain.topology.finder.IOdiContextualSchemaMappingFinder
import oracle.odi.domain.topology.OdiContextualSchemaMapping
import oracle.odi.domain.topology.finder.IOdiContextualAgentMappingFinder
import oracle.odi.domain.topology.OdiContextualAgentMapping

import oracle.odi.domain.topology.finder.IOdiLogicalSchemaFinder
import oracle.odi.domain.topology.OdiLogicalSchema

import oracle.odi.domain.topology.finder.IOdiPhysicalSchemaFinder
import oracle.odi.domain.topology.OdiPhysicalSchema
import oracle.odi.domain.topology.finder.IOdiLogicalAgentFinder
import oracle.odi.domain.topology.OdiLogicalAgent

import oracle.odi.impexp.EncodingOptions
import oracle.odi.impexp.smartie.impl.SmartExportServiceImpl
import oracle.odi.impexp.support.ExportServiceImpl
import java.text.*

import oracle.odi.domain.adapter.flexfields.*
import oracle.odi.domain.topology.finder.IOdiFlexFieldFinder
import oracle.odi.domain.topology.OdiFlexField
import oracle.odi.core.repository.WorkRepository.WorkType

type_design=WorkType.DESIGN
type_runtime=WorkType.RUNTIME

// Determine the type of repostory
repo_type=odiInstance.getWorkRepository().getType() 

if ( repo_type == type_design ) {

def All_scenarios = ((IOdiScenarioFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiScenario.class)).findAll()
search_scen_ff_field="ACTIVE_SCENARIO"

All_scenarios.each() { scn ->

// Get the flex fields for this scenario
   scn.initFlexFields(((IOdiFlexFieldFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiFlexField.class)))
   scen_ff_values = scn.getFlexFieldsValues()
   scen_ff_values.each() { ff_val -> 
      if ( ff_val.getCode() == search_scen_ff_field ) {
         scen_active = ff_val.getValue()  
         }
   }

try {

// If is was generated from a mapping: check the flexfield for that mapping
   if (scn.wasGeneratedFromMapping()){
      //println("....Include mapping")
      def mapId = scn.getSourceMappingId()
      def map = ((IMappingFinder)odiInstance.getTransactionalEntityManager().getFinder(Mapping.class)).findById(scn.getSourceComponentId())

      search_ff_field="ACTIVE_MAPPING"
      map.initFlexFields(((IOdiFlexFieldFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiFlexField.class)))
      map_ff_values = map.getFlexFieldsValues()
      
      map_ff_values.each() { ff_val -> 
         if ( ff_val.getCode() == search_ff_field ) {
            map_active = ff_val.getValue()
           }
      }
      
      if ( scen_active != map_active ) {
         println scn.getName() + " - " + map.getName() + "  --> Scenario and mapping active settings are not correct"
      }
   }

// If is was generated from a package: check the flexfield for that package
   if (scn.wasGeneratedFromPackage()){
      //println("....Include package")
      def pckId = scn.getSourcePackageId()
      def pckg = ((IOdiPackageFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiPackage.class)).findById(pckId)

      search_ff_field="ACTIVE_PACKAGE"
      pckg.initFlexFields(((IOdiFlexFieldFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiFlexField.class)))
      pckg_ff_values = pckg.getFlexFieldsValues()
      
      pckg_ff_values.each() { ff_val -> 
         if ( ff_val.getCode() == search_ff_field ) {
            package_active = ff_val.getValue()
           }
      }
      
      if ( scen_active != package_active ) {
         println scn.getName() + " - " + pckg.getName() + "  --> Scenario and package active settings are not correct"
      }
   }

// If is was generated from a procedure: check the flexfield for that procedure
   if (scn.wasGeneratedFromUserProcedure()){
      //println("....Include procedure")
      def prcId = scn.getSourceComponentId()
      def prc = ((IOdiUserProcedureFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiUserProcedure.class)).findById(scn.getSourceComponentId())

      search_ff_field="ACTIVE_PROCEDURE"
      prc.initFlexFields(((IOdiFlexFieldFinder)odiInstance.getTransactionalEntityManager().getFinder(OdiFlexField.class)))
      prc_ff_values = prc.getFlexFieldsValues()

      prc_ff_values.each() { ff_val -> 
         if ( ff_val.getCode() == search_ff_field ) {
            procedure_active = ff_val.getValue()
           }
      }
      if ( scen_active != procedure_active ) {
         println scn.getName() + " - " + prc.getName() + "  --> Scenario and Procedure active settings are not correct"
      }
   }

} catch(e) {
  println e
  println "--> Check ended with error for scenario: "+scn.getName();
}

}
}
else {
  println "###################################################################################"
  println "Only availaible for development repository type, not run-time type of repository!!!"
  println "###################################################################################"
}
println "Script executed"


