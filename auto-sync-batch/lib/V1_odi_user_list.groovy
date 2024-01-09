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

def cli = new CliBuilder(usage: 'odi_user_list.groovy')
cli.with{
        h longOpt: 'help', 'Show usage information'
}

def options = cli.parse(args)

//if(!options){
//        return
//}

if(options.h){
        cli.usage()
        return
}

// Global definitions

def Url = System.getenv( 'ODI_URL' );
def Driver="oracle.jdbc.OracleDriver";
def Master_User=System.getenv( 'ODI_MASTER_USER' );
def Master_Pass=System.getenv( 'ODI_MASTER_PWD' );
def WorkRep=System.getenv( 'ODI_WORKREP' );
def Odi_User=System.getenv( 'ODI_USER' );
def Odi_Pass=System.getenv( 'ODI_PWD' );

//def odiserver=Url.split("/")[3].replaceAll("PEDR","").replaceAll("1_srv","")

def odiserver=Url.split("@")[1].substring(4,7)

// Connection
MasterRepositoryDbInfo masterInfo = new MasterRepositoryDbInfo(Url, Driver, Master_User,Master_Pass.toCharArray(), new PoolingAttributes());
WorkRepositoryDbInfo workInfo = new WorkRepositoryDbInfo(WorkRep, new PoolingAttributes());
OdiInstance odiInstance=OdiInstance.createInstance(new OdiInstanceConfig(masterInfo,workInfo));
Authentication auth = odiInstance.getSecurityManager().createAuthentication(Odi_User,Odi_Pass.toCharArray());
odiInstance.getSecurityManager().setCurrentThreadAuthentication(auth);

ITransactionStatus trans_user = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition());
def tm_user = odiInstance.getTransactionManager()
def tme_user = odiInstance.getTransactionalEntityManager()

def all_users = ((IOdiPrincipalFinder)tme_user.getFinder(OdiPrincipal.class)).findAll();

File flist = new File("odiusers.odiinfo")

all_users.each() { user ->

  if ( ! user.isRole() ) {
    println user.getName() + "|" + user.isSupervisor()
    flist << odiserver+"|"+Master_User+"|"+user.getName() + "|" + user.isSupervisor()+"\n"
    }
}

