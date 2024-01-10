// Created: duke@oracleadvisor.com
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import oracle.odi.core.OdiInstance;
import oracle.odi.domain.adapter.AdapterException;
import oracle.odi.domain.mapping.IMapComponent;
import oracle.odi.domain.mapping.MapConnectorPoint;
import oracle.odi.domain.mapping.MapRootContainer;
import oracle.odi.domain.mapping.component.AggregateComponent;
import oracle.odi.domain.mapping.component.ExpressionComponent;
import oracle.odi.domain.mapping.exception.MapComponentException;
import oracle.odi.domain.mapping.exception.MappingException;
import oracle.odi.domain.mapping.expression.MapExpression;
import oracle.odi.domain.project.OdiFolder;
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


private void log(MapRootContainer m, String msg) {
        String mapMsg = String.format("Voor mapping; %s in folder %s :",
                        m.getName(), m.getFolder().getName());
        println(mapMsg + msg);
}

private boolean containsOrder(MapExpression childExpression)
			throws MapComponentException {
		if(childExpression.getExpressionMap() == null || childExpression.getExpressionMap().values() == null){
			return false;
		}
		for (MapExpression me : childExpression.getExpressionMap().values()) {
			if (me.getText().toLowerCase().contains("over")
					&& me.getText().toLowerCase().contains("order")
					&& me.getText().toLowerCase().contains("by")) {
				return true;
			}
		}
		return false;
	}

private void checkCase1ExpressionsOrderBy(MapRootContainer m)
                throws MappingException {
        boolean parentContainsOrder = false;
        boolean childContainsOrder = false;
        for (IMapComponent comp : m.getAllComponents()) {
                if (comp instanceof ExpressionComponent) {
                        for (MapExpression parentExpression : ((ExpressionComponent) comp)
                                        .getAllExpressions()) {
                                parentContainsOrder = containsOrder(parentExpression);
                                if (parentContainsOrder) {
                                        break;
                                }
                        }
                }
                if (comp instanceof ExpressionComponent) {
                        if (!parentContainsOrder) {
                                break;
                        }
                        for (MapConnectorPoint con : comp.getConnectorPoints()) {
                                for (IMapComponent childMC : con
                                                .getUpstreamConnectedComponents()) {
                                        if (childMC.getTypeName()
                                                        .equalsIgnoreCase("EXPRESSION")) {
                                                IMapComponent child = childMC;
                                                for (MapExpression childExpression : child
                                                                .getAllExpressions()) {
                                                        childContainsOrder = containsOrder(childExpression);
                                                        if (childContainsOrder) {
                                                                String msg = String
                                                                                .format("Case1: 2 Expressions na elkaar die elk een ORDER BY bevatten voor child expression %s",
                                                                                                child.getName());
                                                                log(m, msg);
                                                        }
                                                }

                                        }
                                }
                        }
                }
        }
}


private void checkCase2SortExpressionsOrderBy(MapRootContainer m) throws MapComponentException, AdapterException, MappingException {
		boolean parentContainsOrder = false;
		boolean childContainsOrder = false;
		for (IMapComponent comp : m.getAllComponents()) {
			if (comp instanceof ExpressionComponent) {
				for (MapExpression parentExpression : ((ExpressionComponent) comp)
						.getAllExpressions()) {
					parentContainsOrder = containsOrder(parentExpression);
					if (parentContainsOrder) {
						break;
					}
				}
			}
			if (comp instanceof ExpressionComponent) {
				if (!parentContainsOrder) {
					break;
				}
				for (MapConnectorPoint con : comp.getConnectorPoints()) {
					for (IMapComponent childMC : con
							.getUpstreamConnectedComponents()) {
						if (childMC.getTypeName()
								.equalsIgnoreCase("SORT")) {
							IMapComponent child = childMC;
							for (MapExpression childExpression : child
									.getAllExpressions()) {
								childContainsOrder = containsOrder(childExpression);
								if (childContainsOrder) {
									String msg = String
											.format("Case2: 1 SORT met Expression na elkaar die elk een ORDER BY bevatten voor child expression %s",
													child.getName());
									log(m, msg);
								}
							}

						}
					}
				}
			}
		}
	}

private void checkCase3SortAggregate(MapRootContainer m) throws MapComponentException, AdapterException, MappingException {
		boolean parentContainsOrder = false;
		boolean childContainsOrder = false;
		for (IMapComponent comp : m.getAllComponents()) {
			if (comp instanceof AggregateComponent) {
				for (MapExpression parentExpression : comp
						.getAllExpressions()) {
					parentContainsOrder = containsOrder(parentExpression);
					if (parentContainsOrder) {
						break;
					}
				}
			}
			if (comp instanceof ExpressionComponent) {
				if (!parentContainsOrder) {
					break;
				}
				for (MapConnectorPoint con : comp.getConnectorPoints()) {
					for (IMapComponent childMC : con
							.getUpstreamConnectedComponents()) {
						if (childMC.getTypeName()
								.equalsIgnoreCase("SORT")) {
							IMapComponent child = childMC;
							for (MapExpression childExpression : child
									.getAllExpressions()) {
								childContainsOrder = containsOrder(childExpression);
								if (childContainsOrder) {
									String msg = String
											.format("Case3: 1 SORT met Aggregate na elkaar voor child expression %s",
													child.getName());
									log(m, msg);
								}
							}

						}
					}
				}
			}
		}
	}

private void checkCase4Unknown(MapRootContainer m) {

}

List<MapRootContainer> mappings = new ArrayList<MapRootContainer>();
addToList("00_FILE_TO_SRC", mappings);
addToList("01_CDC_TO_SRC", mappings);
addToList("02_SRC_TO_EXT", mappings);
addToList("03_EXT_TO_STG", mappings);
addToList("04_STG_TO_FL", mappings);
addToList("05_FL_TO_BDV", mappings);
addToList("06_BDV_TO_ACL", mappings);
addToList("07_ACL_TO_OUT", mappings);
addToList("08_PL", mappings);
addToList("90_INFLOW", mappings);
addToList("99_GLOBAL", mappings);
for (MapRootContainer m : mappings) {
        checkCase1ExpressionsOrderBy(m);
        checkCase2SortExpressionsOrderBy(m);
        checkCase3SortAggregate(m);
        checkCase4Unknown(m);
}