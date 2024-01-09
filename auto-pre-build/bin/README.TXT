

Script to be set into the crontab (use command crontab -e)
Will be executed every 1 minute from monday till friday


*/1 * * * 1-5 $HOME/civl_release/prd/bin_prebuilder/bin/civl_get_jira_list.sh > /dev/null 2>&1

Will be executed every 5 minute from saturdaty till sunday

*/5 * * * 6-7 $HOME/civl_release/prd/bin_prebuilder/bin/civl_get_jira_list.sh > /dev/null 2>&1

