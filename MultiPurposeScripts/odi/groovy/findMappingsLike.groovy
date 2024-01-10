// Created: duke@oracleadvisor.com
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import oracle.odi.core.OdiInstance;
import oracle.odi.domain.adapter.topology.ITechnology;
import oracle.odi.domain.mapping.IMapComponent;
import oracle.odi.domain.mapping.Mapping;
import oracle.odi.domain.mapping.component.AggregateComponent;
import oracle.odi.domain.mapping.finder.IMappingFinder;
import oracle.odi.domain.project.OdiFolder;
import oracle.odi.domain.project.finder.IOdiFolderFinder;
import oracle.odi.domain.topology.OdiTechnology;
import oracle.odi.domain.topology.finder.IOdiTechnologyFinder;

public void findMappingsInFolderLike(final String like, final String project) {
      
      IOdiFolderFinder folderFinder = (IOdiFolderFinder) odiInstance
                      .getTransactionalEntityManager().getFinder(OdiFolder.class);
      if(folderFinder == null){
         return;
      }
      Collection<OdiFolder> odiFolders = folderFinder.findByProject(project);
      if(odiFolders == null){
        return;
      }
      List<String> folders = new ArrayList<String>();
      
      for (OdiFolder odiFolder : odiFolders) {
              folders.add(odiFolder.getName());
      }
      
      for (String folder : folders) {
      
              IMappingFinder mapFinder = (IMappingFinder) odiInstance
                              .getTransactionalEntityManager().getFinder(Mapping.class);
              if(mapFinder == null){
                continue;
              }
              Collection<Mapping> mappings = mapFinder.findByProject(project,
                              folder);
              if(mappings == null){
                continue;
              }
              for (Mapping m : mappings) {
                      if (m.getName()
                                      .contains(like.replace("%", "").replace("*", ""))) {
                              String message = "Found mapping %s.";
                              StringBuilder name = new StringBuilder();
                              getFullPath(m, (OdiFolder) m.getFolder(), name);
                              name.append(m.getName());
                              name.insert(0, "/" + m.getFolder().getProject().getName()+"/");
                              println(String.format(message,name));
                      }
              }
      }
}

public void getFullPath(final Mapping m, final OdiFolder folder,
                StringBuilder name) {
        if(folder != null)
            name.insert(0, folder.getName() + "/");
        if (folder != null && folder.getParentFolder() != null) 
            getFullPath(m, folder.getParentFolder(), name);
}

findMappingsInFolderLike("CIVL_M_0507_BDV_LNS_VERZEKERINGSDEKKING_RENTEFONDS_POSITIES", "CIVL");

