import oracle.odi.core.OdiInstance
import oracle.odi.core.config.MasterRepositoryDbInfo
import oracle.odi.core.config.OdiInstanceConfig
import oracle.odi.core.config.PoolingAttributes
import oracle.odi.core.config.WorkRepositoryDbInfo
import oracle.odi.core.persistence.transaction.ITransactionStatus
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition
import oracle.odi.core.security.Authentication

import groovy.util.CliBuilder
import org.apache.commons.cli.*
import java.util.*

import java.text.SimpleDateFormat

import oracle.odi.domain.security.OdiUser;
import oracle.odi.domain.security.finder.IOdiUserFinder;

import oracle.odi.domain.security.finder.IOdiPrincipalFinder
import oracle.odi.domain.support.AbstractOdiEntity
import oracle.odi.domain.security.OdiPrincipal

ITransactionStatus trans_user = odiInstance.getTransactionManager().getTransaction(new DefaultTransactionDefinition())

def tm_user = odiInstance.getTransactionManager()
def tme_user = odiInstance.getTransactionalEntityManager()

def NewDate = new SimpleDateFormat("EEEddMMMyyyy").format(new Date())

final char[] userPassword = NewDate

//search the user also
def theUser = ((IOdiUserFinder)tme_user.getFinder(OdiUser.class)).findByName("TMPUSER");

if ( theUser != null ) {
  theUser.setAccountExpiracyDate()
}

odiInstance.getSecurityManager().setPassword( "TMPUSER" , userPassword )

tm_user.commit(trans_user)
println NewDate

