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
        t longOpt: 'filename_tech_users', args:1, required: true, 'File input with all technical users'
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

def RemoveUsers ( List unique_users, OdiInstance odiInstance ) {
   ITransactionStatus trans_user = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
   def tm_user = odiInstance.getTransactionManager()
   def tme_user = odiInstance.getTransactionalEntityManager()

   def all_users = ((IOdiPrincipalFinder)tme_user.getFinder(OdiPrincipal.class)).findAll();

   all_users.each() { user ->

      if ( ! user.isRole() && ! unique_users.contains(user.getName()) ) {
         println "deleting user : " + user.getName()

         profile_list = user.getOdiProfileList()
         profile_list.each() { user_profile ->
           user.removeOdiProfile(user_profile)
         }
        // Remove from repository
        tme_user.remove(user)
      }
   }
   tm_user.commit(trans_user);
}

def CreateUsers (  List unique_users, OdiInstance odiInstance ) {
   ITransactionStatus trans_newuser = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
   def tm_newuser = odiInstance.getTransactionManager()
   def tme_newuser = odiInstance.getTransactionalEntityManager()

   final char[] userPassword = 'welkom01'
   final boolean isSupervisor = false
   final Date expirationDate = new Date()

   unique_users.each() { user ->
      odi_user=((IOdiPrincipalFinder)tme_newuser.getFinder(OdiPrincipal.class)).findByName(user)
      if ( odi_user == null ) {
         println "creating user : "+user
         IOdiUserCreationService service = new OdiUserCreationServiceImpl(odiInstance);
         OdiUser newUser = service.createOdiUser(user, userPassword, isSupervisor, null);
         }
   }
   tm_newuser.commit(trans_newuser);
}

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

// Load user list first
def File user_filetmp = new File(options.f);

def user_list = ( user_filetmp as List).collect { it.split('\\|') }

// Load technical users also
def File tech_user_filetmp = new File(options.t);
def tech_user_list = ( tech_user_filetmp as List).collect { it.split('\\|') }

List all_list_users = new ArrayList()
List list_normal_users = new ArrayList()

user_list.each() { usr ->
   if ( usr[0] != "" ) {
     all_list_users.add( usr[0] )
     list_normal_users.add( usr[0] )
   }
}

tech_user_list.each() { usr ->
   all_list_users.add( usr[0] )
}

// Check if there are users which are not in the list

RemoveUsers ( all_list_users.unique() , odiInstance )

CreateUsers ( list_normal_users.unique() , odiInstance )

println "Script exited ... "


