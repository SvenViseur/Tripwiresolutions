# ivlcheck_deploy_functions.sh
# A library of callable functions to interact with IVL servers
# to run scenarios or load plans
#
#
#
#################################################################
# Change history
#################################################################
# visv       # Oct/0200     # 1.0.0             # initial version
#################################################################
ivlcheck_deploy_Functions_ScriptVersion="1.0.0"
#
# Usage guidelines:
# use a properties scripts with credentials to provide these values:
#   ivlcheck_deploy_usr                  : the userid
#   ivlcheck_deploy_psw                  : the password
#   ivlcheck_deploy_master_usr           : the master userid
#   ivlcheck_deploy_master_psw           : the master password
#   ivlcheck_deploy_jdbc_odi_url         : the jdbc odi URL string
#   ivlcheck_deploy_default_odi_agent    : the default ODI agent
#   ivlcheck_deploy_default_context      : the default context
#
# Mandatory option for most calls:
#   ivlcheck_deploy_target               : either "IVL" or "CIVL"
#   ivlcheck_deploy_groovy_folder        : the location where the groovy code resides
#
#
# General option is ivlcheck_deploy_debug. Set this to "1" and you will get extra info
#
# Each call uses the $ivlcheck_deploy_error variable to inform the caller on the success or failure of the
#   executed function call. 0 always means success. Non-zero codes are function dependent.
#
#

ivlcheck_deploy_initialize() {
# the below is needed for the Log to echo alias
shopt -s expand_aliases

ivlcheck_deploy_make_Log_work

ivlcheck_deploy_error="0"
ivlcheck_deploy_initialized="1"
}

ivlcheck_deploy_make_Log_work() {
# Internal function. If the function Log exists or if Log is an alias, then do nothing
# If Log is not a function nor an alias, the set Log as an alias of echo
if [ -n "$(LC_ALL=C type -t Log)" ] && [ "$(LC_ALL=C type -t Log)" = "function" ]; then
  return
fi
if [ -n "$(LC_ALL=C type -t Log)" ] && [ "$(LC_ALL=C type -t Log)" = "alias" ]; then
  return
fi
echo "Log will be set as a function that simply calls echo"

  Log() {
    echo "$1"
  }
}

LogDebug() {
if [ "$ivlcheck_deploy_debug" = "1" ]; then
  Log "$1"
fi
}

RunODICheckDeploy() {

# OUT: ivlcheck_deploy_error        : 0 if no error
#                            <>0 if error

if [ ! "$ivlcheck_deploy_initialized" = "1" ]; then
  ivlcheck_deploy_error="not_initialized"
  return
fi

Log "temp folder:"${ivlcheck_deploy_temp_folder}

ivlcheck_deploy_log_file="${ivlcheck_deploy_temp_folder}/run_odi_check_deploy.log"
touch $ivlcheck_deploy_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODICheckDeploy: Could not create temporary file (error=${RC})."
  ivlcheck_deploy_error=$RC
  return
fi
if [ -z $ODI_URL ]; then
  Log "Error in ODICheckDeploy: parameter ODI_URL is verplicht"
  ivlcheck_deploy_error=999
  return
fi
if [ -z $ODI_MASTER_USER ]; then
  Log "Error in ODICheckDeploy: parameter ODI_MASTER_USER is verplicht"
  ivlcheck_deploy_error=999
  return
fi
if [ -z $ODI_USER ]; then
  Log "Error in ODICheckDeploy: parameter ODI_USER is verplicht"
  ivlcheck_deploy_error=999
  return
fi
if [ -z $GROOVY_CONF ]; then
  Log "Error in ODICheckDeploy: parameter GROOVY_CONF is verplicht"
  ivlcheck_deploy_error=999
  return
fi
if [ ! -d "${ivlcheck_deploy_temp_folder}" ]; then
  ## we have an error, return to caller
  Log "Error in ODICheckDeploy: Could not find the specified temporary folder '$ivlcheck_deploy_temp_folder'."
  ivlcheck_deploy_error=990
  return
fi
ivlcheck_deploy_log_file="${ivlcheck_deploy_temp_folder}/run_odi_check_deploy.log"
touch $ivlcheck_deploy_log_file
RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODICheckDeploy: Could not create temporary file (error=${RC})."
  ivlcheck_deploy_error=$RC
  return
fi

Log "DoODICheckDeploy functie gestart"

#Log "Create users groovy script"
#Log "${ivlcheck_deploy_groovy_path}/groovy $ivlcheck_deploy_groovy_folder/${ivlrun_check_deploy_main_script_version}_odi_user_create.groovy -f ${user_profile_file} -t ${tech_user_file}"

#Log "groovy conf= "$GROOVY_CONF
#Log "ODI_MASTER_USER="$ODI_MASTER_USER
#Log "ODI_URL="$ODI_URL
#Log "ODI_USER="$ODI_USER
#Log "ODI_MASTER_PWD="$ODI_MASTER_PWD
#Log "ODI_PWD="$ODI_PWD

Log "logfile="${ivlcheck_deploy_log_file}

#################################
## Steps per ticket to perform ##
#################################

ivlcheck_deploy_unzip_folder=${ivlcheck_deploy_temp_folder}/ivlcheck

mkdir ${ivlcheck_deploy_unzip_folder}

# Split the lists into an array
# ivlcheck_deploy_tickets
IFS=', ' read -r -a ivlcheck_tickets_check <<< "$ivlcheck_deploy_tickets"

ivlcheck_output_basefile=${ivlcheck_deploy_temp_folder}/outputbase.txt
ivlcheck_output_workfile=${ivlcheck_deploy_temp_folder}/outputwork.txt
ivlcheck_temp_lpfile=${ivlcheck_deploy_temp_folder}/tmp_output_lp.txt
ivlcheck_output_lpfile=${ivlcheck_deploy_temp_folder}/output_lp.txt
ivlcheck_output_resultfile=${ivlcheck_deploy_temp_folder}/output_Result.txt

ivlcheck_output_order=0

echo "############################"  > ${ivlcheck_output_resultfile}
echo "# Results Deploy info"  >> ${ivlcheck_output_resultfile}
echo "############################"  >> ${ivlcheck_output_resultfile}
echo "" >> ${ivlcheck_output_resultfile}
echo "Parameters given" >> ${ivlcheck_output_resultfile}
echo "  Target repo: "${ivlcheck_deploy_target} >> ${ivlcheck_output_resultfile}
echo "  Target env : "${ivlcheck_deploy_env} >> ${ivlcheck_output_resultfile}
echo "--------------"  >> ${ivlcheck_output_resultfile}
echo "Ticket(s) Info"  >> ${ivlcheck_output_resultfile}
echo "--------------"  >> ${ivlcheck_output_resultfile}
echo "" >> ${ivlcheck_output_resultfile}

for ivlcheck_ticket in "${ivlcheck_tickets_check[@]}"
do

    Log "Processing ticket: $ivlcheck_ticket"

    ((ivlcheck_output_order+=1))

    ivlcheck_ticket_block="/TI:${ivlcheck_ticket}/,/TI:/p"

    # Step 1
    # Seek based upon the ticket number which zip file is needed

    Log "svn log -v ${ivlcheck_svn_url} --non-interactive --username ${ivlcheck_svn_usr} --password <pwd> | sed -n $ivlcheck_ticket_block | grep ".zip" | cut -d " " -f5 | head -n1 | xargs -I{} basename {}"

    ivlcheck_download_ticket=$(echo -n | svn log -v ${ivlcheck_svn_url} --non-interactive --username ${ivlcheck_svn_usr} --password ${ivlcheck_svn_psw} | sed -n $ivlcheck_ticket_block | grep ".zip" | cut -d " " -f5 | head -n1 | xargs -I{} basename {})

    RC=$?
    if [ $RC -ne 0 ]; then
      ## we have an error, return to caller
      Log "Error in ODICheckDeploy: Could not get the correct info for ticket [$ivlcheck_ticket] (error=${RC})."
      ivlcheck_deploy_error=$RC
      return
    fi

    if [ "${ivlcheck_download_ticket}" = "" ]; then
       echo " !! Ticket nr is unknown: $ivlcheck_ticket" >> ${ivlcheck_output_resultfile}
    else
       ivlcheck_zip_dirname="${ivlcheck_download_ticket%.*}"

       # Get the zip from the 4ME ticket
       #   goto the tmp folder
       Log "Creating extract folder: $ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}"

       mkdir $ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}

       RC=$?
       if [ $RC -ne 0 ]; then
         ## we have an error, return to caller
         Log "Error in ODICheckDeploy: Could not create the directory [$ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}] (error=${RC})."
         ivlcheck_deploy_error=$RC
         return
       fi

       cd $ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}
    
       # Unzip to the tmp folder
       svn export --non-interactive --username ${ivlcheck_svn_usr} --password ${ivlcheck_svn_psw} ${ivlcheck_svn_url}/${ivlcheck_download_ticket} $ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}/${ivlcheck_download_ticket}

       RC=$?
       if [ $RC -ne 0 ]; then
         ## we have an error, return to caller
         Log "Error in ODICheckDeploy: Could not export the zip file [${ivlcheck_download_ticket}] (error=${RC})."
         ivlcheck_deploy_error=$RC
         return
       fi

       echo ${ivlcheck_output_order}": (${ivlcheck_ticket}) ${ivlcheck_zip_dirname}" >> ${ivlcheck_output_resultfile}

       cd $ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}

       ## unzip the file

       unzip ${ivlcheck_download_ticket}

       # Step 2
       # Get the info from the Target ODI repository
       # Get the info from the zipfile itself

       # Get the Scenarios

       if [ -f "$ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}/odi/${ivlcheck_zip_dirname}/EXEC_${ivlcheck_zip_dirname}.zip" ]; then
         ${ivlcheck_deploy_groovy_path}/groovy $ivlcheck_deploy_groovy_folder/${ivlrun_check_deploy_main_script_version}_civl_get_deploy_scenario.groovy -b ${ivlcheck_output_basefile} -e ${ivlcheck_output_workfile} -f $ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}/odi/${ivlcheck_zip_dirname}/EXEC_${ivlcheck_zip_dirname}.zip -n ${ivlcheck_output_order} >> ${ivlcheck_deploy_log_file} 2>&1
       fi

       # Get the Loadplans
       if [ -f "$ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}/odi/${ivlcheck_zip_dirname}/LP_${ivlcheck_zip_dirname}.zip" ]; then

         unzip -l $ivlcheck_deploy_unzip_folder/${ivlcheck_zip_dirname}/odi/${ivlcheck_zip_dirname}/LP_${ivlcheck_zip_dirname}.zip | grep ".xml" | sed -e's/  */ /g' | cut -d " " -f 3- > ${ivlcheck_temp_lpfile}

         if [ -f ${ivlcheck_output_lpfile} ] ; then
            rm -f ${ivlcheck_output_lpfile}
         fi

         while IFS=" " read -r datum tijd loadplanNaam;
         do
             ivlcheck_tmp_datumtijd=$(echo ${datum:6:4}${datum:0:2}${datum:3:2}${tijd:0:2}${tijd:3:2}00)
             ivlcheck_tmp_loadplan=$(echo ${loadplanNaam:3} | sed "s/.xml//g")

             echo ${ivlcheck_output_order}"|"LP_${ivlcheck_zip_dirname}.zip"|"${ivlcheck_tmp_loadplan}"|"${ivlcheck_tmp_datumtijd}"|Build_Date|Build_User|Loadplan" >> ${ivlcheck_output_lpfile}
         done < ${ivlcheck_temp_lpfile}

         # Get the loadplan info from the target repository

         ${ivlcheck_deploy_groovy_path}/groovy $ivlcheck_deploy_groovy_folder/${ivlrun_check_deploy_main_script_version}_civl_get_deploy_loadplan.groovy -b ${ivlcheck_output_basefile} -e ${ivlcheck_output_workfile} -f ${ivlcheck_output_lpfile} -n ${ivlcheck_output_order} >> ${ivlcheck_deploy_log_file} 2>&1

       fi
    fi
done

#######################################################################
## Check 1 => loop per scenario/loadplan to check if the order is ok ##
## Check 2 => See if there are any doubles in the workfile           ##
#######################################################################

###########
# Check 1 #
###########

Log "Start with check 1: Check dates"

ivlcheck_output_checksfile=${ivlcheck_deploy_temp_folder}/output_checks1.txt
ivlcheck_output_sortinfo=${ivlcheck_deploy_temp_folder}/output_sort.txt

## Make the base uniq 
cat ${ivlcheck_output_basefile} | sort | uniq > ${ivlcheck_output_checksfile}
## Add the deploy info to the check file
cat ${ivlcheck_output_workfile} >> ${ivlcheck_output_checksfile}

echo "" >> ${ivlcheck_output_resultfile}
echo "------------------------------------------------------------------------"  >> ${ivlcheck_output_resultfile}
echo "# Deploy Information : Check the order of deploy"  >> ${ivlcheck_output_resultfile}
echo "------------------------------------------------------------------------"  >> ${ivlcheck_output_resultfile}
echo "" >> ${ivlcheck_output_resultfile}

ivlcheck_failure=0

# Proces for each scenario now
cat ${ivlcheck_output_checksfile} | cut -d "|" -f 3 | sort -u | while read ivlcheck_odi_object
do
   # Check if order is ok. If not, there is an object that will be overwritten with old data
   cat ${ivlcheck_output_checksfile} | grep -w "${ivlcheck_odi_object}" | sort | cut -d '|' -f4 > ${ivlcheck_output_sortinfo}
   ivlcheck_result_order_ok=$(join --check-order ${ivlcheck_output_sortinfo} ${ivlcheck_output_sortinfo} &>/dev/null && echo "OK" || echo "FAIL")
   ivl_repo_datum_check=$( cat ${ivlcheck_output_basefile} | sort | uniq  | grep -w "${ivlcheck_odi_object}"  | sed "s+|+ +g" | cut -d " " -f4 )

   ivl_repo_datum_report=$(echo ${ivl_repo_datum_check} | awk '{ print substr($1,7,2)"/"substr($1,5,2)"/"substr($1,1,4)" "substr($1,9,2)":"substr($1,11,2) }')

#   ivl_new_datum_check=${ivl_repo_datum_check}

   if [ "${ivlcheck_result_order_ok}" = "FAIL" ]; then
       ivlcheck_failure=1
       # There is a potential error in deploying the scenario/loadplan
       echo "!! Date check deploy object: $ivlcheck_odi_object (${ivl_repo_datum_report})" >> ${ivlcheck_output_resultfile}
       echo "   ---------------------------------------------------------------------" >> ${ivlcheck_output_resultfile}
       #echo "   "  >> ${ivlcheck_output_resultfile}

#       ivl_deploy_datum_check=$( cat ${ivlcheck_output_workfile}  | grep -w "${ivlcheck_odi_object}"  | sed "s+|+ +g" | cut -d " " -f4)

#       if [[ "${ivl_deploy_datum_check}" > "${ivl_new_datum_check}" ]]; then
#           ivlcheck_add_flags=" <<---"
#       else
#           ivlcheck_add_flags=""
#       fi

       cat ${ivlcheck_output_workfile}  | grep -w "${ivlcheck_odi_object}"  | sed "s+|+ +g" | awk '{ print "    "$1",  "$2 ", Build date: " substr($4,7,2)"/"substr($4,5,2)"/"substr($4,1,4)" "substr($4,9,2)":"substr($4,11,2) }' >> ${ivlcheck_output_resultfile}
#      ivl_new_datum_check=${ivl_deploy_datum_check}
       echo "   "  >> ${ivlcheck_output_resultfile}
   fi

done

if [ $"{ivlcheck_failure}" = "0" ]; then
   echo " NO ISSUES FOUND" >> ${ivlcheck_output_resultfile}
fi


###########
# Check 2 #
###########

# Check now for odi objects in multiple deploys
Log "Start with check 2: objects in multiple deploys"

echo "" >> ${ivlcheck_output_resultfile}
echo "----------------------------------------------------"  >> ${ivlcheck_output_resultfile}
echo "# Deploy Information : ODI Objects in multiple deploys"  >> ${ivlcheck_output_resultfile}
echo "----------------------------------------------------"  >> ${ivlcheck_output_resultfile}
echo "" >> ${ivlcheck_output_resultfile}

ivlcheck_failure=0

cat ${ivlcheck_output_workfile} | cut -d '|' -f3 | sort | uniq --count | sed "s/^ *//g" | grep -v "^1" | while IFS=" " read -r ivlcheck_counts ivlcheck_odi_object
do

   ivlcheck_failure=1
   
   echo "!! issue found with object: $ivlcheck_odi_object ( #: ${ivlcheck_counts})" >> ${ivlcheck_output_resultfile}
   echo "   ---------------------------------------------------------------------" >> ${ivlcheck_output_resultfile}
   cat ${ivlcheck_output_workfile}  | grep -w "${ivlcheck_odi_object}"  | sed "s+|+ +g" | awk '{ print "    "$1",  "$2 ", Build date: " substr($4,7,2)"/"substr($4,5,2)"/"substr($4,1,4)" "substr($4,9,2)":"substr($4,11,2) }' >> ${ivlcheck_output_resultfile}
   echo "   ---------------------------------------------------------------------" >> ${ivlcheck_output_resultfile}

done

if [ $"{ivlcheck_failure}" = "0" ]; then
   echo " NO MULTIPLE DEPLOYS FOUND" >> ${ivlcheck_output_resultfile}
fi

################################
# Send output result via mail  #
################################

Log "Sending mail to "${ivlcheck_deploy_sendmail}

ivlcheck_output_mailfile=${ivlcheck_deploy_temp_folder}/output_Mail.txt

ivlcheck_date=$(date +%d/%m/%Y" "%H:%M:%S)

# Prepare the mail with the result

echo "From: check_deploy" > ${ivlcheck_output_mailfile}
echo "Subject: Auto-Deploy Pre-check Results - "${ivlcheck_date} >> ${ivlcheck_output_mailfile}
echo "" >> ${ivlcheck_output_mailfile}
cat ${ivlcheck_output_resultfile} >> ${ivlcheck_output_mailfile}

# Send the mail

sendmail ${ivlcheck_deploy_sendmail} < ${ivlcheck_output_mailfile}

RC=$?
if [ $RC -ne 0 ]; then
  ## we have an error, return to caller
  Log "Error in ODICheckDeploy: Could not get the correct info for ticket [$ivlcheck_ticket] (error=${RC})."
  ivlcheck_deploy_error=$RC
  return
fi

Log "DoODICheckDeploy functie beëindigd"

# now send the output of the log file to the Log function

the_log=$(cat ${ivlcheck_deploy_log_file})
Log "$the_log"
rm $ivlcheck_deploy_log_file

the_log=$(cat ${ivlcheck_output_resultfile})
Log "$the_log"

if [ $RC -ne 0 ]; then
    ## we have an error, return to caller
  Log "Error in ODICheckDeploy: The script encountered an error during execution. Please check the above log."
  ivlcheck_deploy_error=980
  return
fi

ivlcheck_deploy_error=0
return
}

