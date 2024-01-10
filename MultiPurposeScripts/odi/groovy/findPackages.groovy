// Created: duke@oracleadvisor.com
import java.util.Collection;

import oracle.odi.core.OdiInstance;
import oracle.odi.domain.project.OdiFolder;
import oracle.odi.domain.project.OdiPackage;
import oracle.odi.domain.project.finder.IOdiPackageFinder;

public void findPackagesInFolderLike(final String like) {

        IOdiPackageFinder pckFinder = (IOdiPackageFinder) odiInstance
                        .getTransactionalEntityManager().getFinder(OdiPackage.class);
        Collection<OdiPackage> odiPackages = pckFinder.findAll();

        for (OdiPackage pck : odiPackages) {
                if (pck.getName().contains(like.replace("%", "").replace("%", ""))) {
                        final String msg = "Found Package %s.";
                        StringBuilder folder = new StringBuilder();
                        getFullPath(pck, pck.getParentFolder(), folder);
                        folder.append(pck.getName() + "/");
                        folder.insert(0, "/" + pck.getParentFolder().getProject().getName()+ "/");
                        println(String.format(msg, folder));
                }
        }

}

public void getFullPath(final OdiPackage lp, final OdiFolder parent,
                StringBuilder folder) {
        if(parent != null){
                folder.insert(0, parent.getName() + "/");
        }
        if (parent != null && parent.getParentFolder() != null) {
                getFullPath(lp, parent.getParentFolder(), folder);
        }
}
        
findPackagesInFolderLike("COMARCH_OUT");
        