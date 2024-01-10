import oracle.odi.core.OdiInstance
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication
import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.mapping.finder.IMappingFinder

def fillMapping(mapping, project) {
  // Connection

  def txnDef = new DefaultTransactionDefinition();  
  def tm = odiInstance.getTransactionManager()
  def tme = odiInstance.getTransactionalEntityManager()
  def txnStatus = tm.getTransaction(txnDef)

  def mapf = (IMappingFinder)tme.getFinder(Mapping.class)
  def mapList = mapf.findByName(mapping,project)
  
  for (def map : mapList){
          def mapAttrChanged = false
          def tgtList = map.getTargets()
          for (def tgt : tgtList){
              attrList = tgt.getAttributes()
              for (def att : attrList){
                  if (att.getExpression() == null){
                    println(tgt.getName() + ' - ' + att.getName() + ' - ' + att.getExpression());
                    mapAttrChanged = true
                    att.setExpressionText('UF_SET_DECIMAL('+tgt.getDelegate().getUpstreamConnectedLeafComponents()[0].getAlias()+'.'+att.getName()+',8)');
                  }
              }
          }
          
          tme.persist(map)
  }
  tm.commit(txnStatus);
}

fillMapping('COPY_CIVL_M_0013_SBP_DS332_DEPOSITS_SAVINGS','CIVL');