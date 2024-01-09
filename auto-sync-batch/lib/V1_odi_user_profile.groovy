import java.util.List;;
import java.util.regex.Pattern
import oracle.odi.core.OdiInstance;
import oracle.odi.core.config.MasterRepositoryDbInfo;
import oracle.odi.core.config.OdiInstanceConfig;
import oracle.odi.core.config.PoolingAttributes;
import oracle.odi.core.config.WorkRepositoryDbInfo;
import oracle.odi.core.persistence.transaction.ITransactionStatus;
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition;
import oracle.odi.core.security.Authentication;
import oracle.odi.domain.security.OdiUser;
import oracle.odi.domain.security.OdiProfile;
import oracle.odi.domain.security.IOdiUserCreationService;
import oracle.odi.domain.security.OdiUserCreationServiceImpl;
import oracle.odi.domain.security.finder.IOdiProfileFinder;
import oracle.odi.domain.security.finder.IOdiUserFinder;

import oracle.odi.domain.security.finder.IOdiPrincipalFinder
import oracle.odi.domain.support.AbstractOdiEntity
import oracle.odi.domain.security.OdiPrincipal

import groovy.util.CliBuilder
import org.apache.commons.cli.*

println "INFO: ------------------------------------------------------------"
println "INFO: ----------------------- Script Info ------------------------"
println "INFO: ------------------------------------------------------------"

def info_command
info_command = "stat "+this.class.protectionDomain.codeSource.location.path

def proc_info = info_command.execute();
proc_info.waitForProcessOutput(System.out, System.err);

println "INFO: ------------------------------------------------------------"

def cli = new CliBuilder(usage: 'civl_deactivate_schedule.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
        f longOpt: 'filename_users', args:1, required: true, 'File input with all users'
        p longOpt: 'filename_profile', args:1, required: true, 'File input with all profiles'
}

def options = cli.parse(args)

println "f:"+options.f

if(!options){
        return
}

if(options.h){
        cli.usage()
        return
}

/////////////////////////////////////////////////////////////////////////
// SET 2 SUPERVISOR
/////////////////////////////////////////////////////////////////////////
def set2supervisor ( List all_supervisors, OdiInstance odiInstance ) {

   // set 2 supervisor if they are not yet supervisor
   // Remove all the profiles that are known
   ITransactionStatus trans_supprof = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

   def tm_supprof = odiInstance.getTransactionManager()
   def tme_supprof = odiInstance.getTransactionalEntityManager()

   final boolean SetSupervisor = true

   println "SUPERVISOR"

   // Remove profiles
   all_supervisors.each() { super_visor->
      println "Remove profile for supervisor role: "+super_visor

      odi_superuser = ((IOdiPrincipalFinder)tme_supprof.getFinder(OdiPrincipal.class)).findByName(super_visor);

      profile_list_remove=odi_superuser.getOdiProfileList()
      profile_list_remove.each() { profile_remove ->
         println super_visor+"-"+profile_remove.getName()
         odi_superuser.removeOdiProfile( profile_remove )
      }
   }

   tm_supprof.commit(trans_supprof)

   ITransactionStatus trans_sup = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

   def tm_sup = odiInstance.getTransactionManager()
   def tme_sup = odiInstance.getTransactionalEntityManager()

   all_supervisors.each() { super_visor->
     println "Assigned to supervisor role: "+super_visor

     odi_superuser = ((IOdiPrincipalFinder)tme_sup.getFinder(OdiPrincipal.class)).findByName(super_visor);

     odi_superuser.setSupervisor(SetSupervisor)
   }

   tm_sup.commit(trans_sup);
}

/////////////////////////////////////////////////////////////////////////
// CLEAR PROFILES
/////////////////////////////////////////////////////////////////////////

def clearProfiles ( List unique_users, OdiInstance odiInstance ) {
   ITransactionStatus trans_prof = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

   def tm_prof = odiInstance.getTransactionManager()
   def tme_prof = odiInstance.getTransactionalEntityManager()

   // Remove profiles
   unique_users.each() { normal_user->
      println "Remove profile for user : "+normal_user

      odi_user = ((IOdiPrincipalFinder)tme_prof.getFinder(OdiPrincipal.class)).findByName(normal_user);

      profile_list_remove=odi_user.getOdiProfileList()
      profile_list_remove.each() { profile_remove ->
         println "remove -> "+normal_user+"-"+profile_remove.getName()
         odi_user.removeOdiProfile( profile_remove )
      }
   }

   tm_prof.commit(trans_prof);
}

/////////////////////////////////////////////////////////////////////////
// SET PROFILES
/////////////////////////////////////////////////////////////////////////

def setCorrectProfile( List unique_users, List file_user_profiles, OdiInstance odiInstance ) {
   ITransactionStatus trans_user = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());

   def tm_user = odiInstance.getTransactionManager()
   def tme_user = odiInstance.getTransactionalEntityManager()

   // add profiles
   unique_users.each() { normal_user->

     odi_user = ((IOdiUserFinder)tme_user.getFinder(OdiUser.class)).findByName(normal_user);
     odi_userProfileList = [];

     requested_profiles = file_user_profiles.findAll{ it[0] == normal_user }.unique()

     requested_profiles.each() { requested_profile->
           search_profile=((IOdiProfileFinder)tme_user.getFinder(OdiProfile.class)).findByName(requested_profile[1])
           if ( search_profile != null ) {
              odi_userProfileList.add( search_profile );
           } else {
             println "NOT FOUND : " + requested_profile[1]
           }
     }

     odi_user.addOdiProfileList(odi_userProfileList.unique());

     println "User -> " + normal_user
     println "----------------------------"
     odi_userProfileList.each() { println it.getName() }
     println "----------------------------"

   }
   tm_user.commit(trans_user);
}


/////////////////////////////////////////////////////////////////////////
//  START PROCEDURES
/////////////////////////////////////////////////////////////////////////

// Global definitions

def Url = System.getenv( 'ODI_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Master_User=System.getenv( 'ODI_MASTER_USER' );
def Master_Pass=System.getenv( 'ODI_MASTER_PWD' );
def WorkRep=System.getenv( 'ODI_WORKREP' );
def Odi_User=System.getenv( 'ODI_USER' );
def Odi_Pass=System.getenv( 'ODI_PWD' );

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

def tm = odiInstance.getTransactionManager()
def tme = odiInstance.getTransactionalEntityManager()

// Load user list first
def File user_filetmp = new File(options.f);

def file_user_list = ( user_filetmp as List).collect { it.split('\\|') }

def file_list_users = []

file_user_list.each() { usr ->
   if ( usr[0] != "" ) { 
     file_list_users += usr[0]
   }
}

def File profile_tmp = new File(options.p);
def file_profile_list = ( profile_tmp as List).collect { it.split('\\|') }
// Limit here only the profiles needed for the correct environment
def file_user_profiles = []

//odi_omgeving=Url.split("/")[3].substring(4,7)
odi_omgeving=Url.split("@")[1].substring(4,7)

file_user_list.each() { usr ->
   if ( usr[0] != "" ) {
     search_profile=usr[2]
     file_profile_list.each() { prof->
        if ( prof[0] == search_profile && prof[1] == odi_omgeving ) {
           file_user_profiles << [ usr[0] , prof[2] ]
        }
     }
  }
}

// Get all profiles from the ODI repository now

def odi_user_list = ((IOdiUserFinder)tme.getFinder(OdiUser.class)).findAll();
def odi_user_profiles = []

odi_user_list.each() { user ->
   if (file_list_users.contains(user.getName())){
   // Get also all the profiles
     user.getOdiProfileList().each() { odiprofile ->
       odi_user_profiles << [user.getName(), odiprofile.getName()]
     }
   }
}

// 1. get list of all the requested supervisor roles

List all_supervisors = new ArrayList()

file_user_profiles.each() { prof->
  if ( prof[1] == "SUPERVISOR" ){
     all_supervisors.add (prof[0])
  }
}

println "removall started"

// 2. Remove now all the requested profiles where user = supervisor
file_user_profiles.removeAll { all_supervisors.contains(it[0]) }


println "setsupervisor started"

// TEMPORARY DE-ACTIVATED
set2supervisor ( all_supervisors , odiInstance )

// Unique list of users only
List unique_users = new ArrayList()

file_user_profiles.each() { prof->
   unique_users.add (prof[0])
}

println "clear profiles started"
clearProfiles ( unique_users.unique(), odiInstance )

println "set correct profile started"
setCorrectProfile ( unique_users.unique(), file_user_profiles, odiInstance )

println "Script exited ... "


