// Created: duke@oracleadvisor.com
import java.util.Collection;

import oracle.odi.core.OdiInstance;
import oracle.odi.domain.runtime.loadplan.OdiLoadPlan;
import oracle.odi.domain.runtime.loadplan.finder.IOdiLoadPlanFinder;
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder;


public void findLoadPlanLike(final String like) {

        IOdiLoadPlanFinder lpFinder = (IOdiLoadPlanFinder) odiInstance
                        .getTransactionalEntityManager().getFinder(OdiLoadPlan.class);
        Collection<OdiLoadPlan> loadplans = lpFinder.findAll();

        for (OdiLoadPlan lp : loadplans) {
                if (lp.getName().contains(like.replace("%", "").replace("*", ""))) {
                        String message = "Found loadplan %s in folder %s.";
                        StringBuilder folder = new StringBuilder();
                        getFullPath(lp, lp.getScenarioFolder(), folder);
                        folder.insert(0, "/");
                        println(String.format(message, lp.getName(), folder + lp.getName()));
                }
        }
}

public void getFullPath(final OdiLoadPlan lp, final OdiScenarioFolder parent,  StringBuilder folder){
        if(parent != null && parent.getName() != null)
           folder.insert(0, parent.getName()+"/");
        if(parent != null && parent.getParentScenFolder() != null){
                getFullPath(  lp,   parent.getParentScenFolder(),   folder);
        }
}

findLoadPlanLike("COMARCH_OUT")