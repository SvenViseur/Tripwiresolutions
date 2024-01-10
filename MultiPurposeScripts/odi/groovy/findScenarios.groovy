// Created: duke@oracleadvisor.com
import java.util.Collection;

import oracle.odi.core.OdiInstance;
import oracle.odi.domain.runtime.scenario.OdiScenario;
import oracle.odi.domain.runtime.scenario.OdiScenarioFolder;
import oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder;


public void findScenariosInFolderLike(final String like) {

        IOdiScenarioFinder scenFinder = (IOdiScenarioFinder) odiInstance
                        .getTransactionalEntityManager().getFinder(OdiScenario.class);
        Collection<OdiScenario> odiScenarios = scenFinder.findAll();

        for (OdiScenario scen : odiScenarios) {
                if (scen.getName().contains(like.replace("%", "").replace("%", ""))) {
                        final String msg = "Found Scenario %s.";
                        StringBuilder folder = new StringBuilder();
                        getFullPath(scen, scen.getScenarioFolder(), folder);
                        folder.append ( scen.getName());
                        folder.insert(0, "/");
                        println(String.format(msg,folder));
                }
        }
}

public void getFullPath(final OdiScenario lp, final OdiScenarioFolder parent,  StringBuilder folder){
        if(parent != null && parent.getName() != null)
                folder.insert(0, parent.getName()+"/");
        if(parent != null && parent.getParentScenFolder() != null){
                getFullPath(  lp,   parent.getParentScenFolder(),   folder);
        }
}

findScenariosInFolderLike("CONTACT");