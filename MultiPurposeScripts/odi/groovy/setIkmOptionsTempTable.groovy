import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map.Entry;

import oracle.odi.core.persistence.transaction.ITransactionDefinition;
import oracle.odi.core.persistence.transaction.ITransactionManager;
import oracle.odi.core.persistence.transaction.ITransactionStatus;
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition;
import oracle.odi.core.OdiInstance;
import oracle.odi.domain.mapping.MapRootContainer;
import oracle.odi.domain.mapping.Mapping;
import oracle.odi.domain.mapping.exception.MappingException;
import oracle.odi.domain.mapping.physical.ExecutionUnit;
import oracle.odi.domain.mapping.physical.MapPhysicalDesign;
import oracle.odi.domain.mapping.physical.MapPhysicalNode;
import oracle.odi.domain.project.OdiFolder;
import oracle.odi.domain.project.OdiKM;
import oracle.odi.domain.project.finder.IOdiFolderFinder;

public void addToList(String folderName, List<MapRootContainer> mappings) {
    final IOdiFolderFinder finder = ((IOdiFolderFinder) odiInstance
            .getTransactionalEntityManager().getFinder(OdiFolder.class));
    // identify (nested) folder first and then find Mapping
    Collection<OdiFolder> rootFolders = finder.findByName(folderName);
    for (OdiFolder rootFolder : rootFolders) {
        for (MapRootContainer m : rootFolder.getMappings()) {
            mappings.add(m);
        }
        if (rootFolder.getSubFolders() != null
                && rootFolder.getSubFolders().size() > 0) {
            for (OdiFolder sub : rootFolder.getSubFolders()) {
                addToList(sub.getName(), mappings);
            }
        }
    }
}
public void modifyIkmOption(final MapRootContainer mapping,
                            final String optionName, final String optionValue) throws Exception {
    for (MapPhysicalDesign pd : ((Mapping) mapping).getPhysicalDesigns()) {
        // here are the target IKMs set
        for (ExecutionUnit teu : pd.getTargetExecutionUnits()) {
            for (MapPhysicalNode target : teu.getTargetNodes()) {
                String ikmNameMapping = target.getIKMName();
                //if(!ikmNameMapping.equalsIgnoreCase(ikmName)){
                //               continue;
                //}
                String msg = String
                        .format("On mapping %s trying to set option %s to value %s on node %s",
                                mapping.getName(), optionName, optionValue,
                                target.getBoundObjectName());
                if (target.getIKMOptionValue(optionName) != null) {
                    if (target.getBoundObjectName().startsWith("T\$_")) {
                        println(msg);
                        target.getIKMOptionValue(optionName).setValue(optionValue);
                    }
                }
            }
        }
    }
}
    final String optionName = "DROP_TARGET_TABLE";
    final String optionValue = "true";
    final String rootFolderName = "30_BDV_TO_ACL";
    List<MapRootContainer> mappings = new ArrayList<MapRootContainer>();
    addToList(rootFolderName, mappings);
    for (MapRootContainer m : mappings) {
        ITransactionDefinition txnDef = new DefaultTransactionDefinition();
        ITransactionManager tm = odiInstance.getTransactionManager();
        ITransactionStatus txnStatus = tm.getTransaction(txnDef);
//     println(String.format(
//                                                                        "Mapping found: %s in folder %s. ", m.getName(), m
//                                                                                                      .getFolder().getName()));
        modifyIkmOption(m, optionName, optionValue);
        odiInstance.getTransactionalEntityManager().merge(m);
        tm.commit(txnStatus);
    }