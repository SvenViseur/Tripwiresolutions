-- monitor sessies
SELECT to_char(sess_beg,'DD/MM/YYYY HH24:MI') startdatum, substr(startup_variables,INSTR(startup_variables,'=',1,1)+1,instr(startup_variables,CHR(10),1,1)-INSTR(startup_variables,'=',1,1)) schema , numtodsinterval(sess_dur / 60,'MINUTE') duurtijd, sum(round(sess_dur / 60,1)) over (partition by trunc(sess_beg)) tot_dur
  FROM civl4_odi_repo.snp_session
 WHERE sess_name = 'CIVL_S_9099_GATHER_SCHEMA_STATS'
--   AND substr(startup_variables,1,instr(startup_variables,CHR(10),1,1)) 
 ORDER BY sess_beg DESC
;

-- details van 1 sessie bekijken
SELECT task.*
  FROM civl4_odi_repo.snp_session sess
  JOIN civl4_odi_repo.snp_sess_task_log task ON (sess.sess_no = task.sess_no)
 WHERE sess.sess_name = 'CIVL_S_0013_SBP_DS519_DEPOSITS_SAVINGS_MAP'
   AND TRUNC(sess.sess_beg) = trunc(sysdate)
 ORDER BY task.scen_task_no
;

-- monitor loadplans gegroepeerd per loadplan over restarts heen
SELECT load_plan_Name,i_lp_inst, numtodsinterval(SUM(duration)/60/60,'HOUR') doorlooptijd_uur, MIN(start_date) start_date, MAX(end_date) end_date
  FROM civl4_odi_repo.snp_lpi_run
 WHERE load_plan_name = 'CIVL_LP_900236_SBP_INCR_LOAD'
 GROUP BY i_lp_inst, load_plan_Name
 ORDER BY load_plan_Name, start_date DESC
;

-- monitor loadplans per sessie
SELECT load_plan_Name,i_lp_inst, nb_run, numtodsinterval(duration/60/60,'HOUR') doorlooptijd_min, to_char(start_date,'DD/MM/YYYY HH24:MI:SS') start_date, to_char(end_date,'DD/MM/YYYY HH24:MI:SS') end_date
  FROM civl4_odi_repo.snp_lpi_run
 WHERE load_plan_name = 'CIVL_LP_900236_SBP_INCR_LOAD'
   AND duration > 30
 ORDER BY load_plan_Name, start_date DESC
;

-- monitor loadplan steps over restarts heen
SELECT lp.load_plan_name, lp.i_lp_inst, lp.nb_run, step.lp_step_name, to_char(slog.start_date,'DD/MM/YYYY HH24:MI:SS') start_date, to_char(slog.end_date,'DD/MM/YYYY HH24:MI:SS') end_date, numtodsinterval(( slog.end_date - slog.start_date) * 24,'HOUR') doorlooptijd
  FROM civl4_odi_repo.snp_lpi_run        lp 
  JOIN civl4_odi_repo.snp_lpi_step       step ON (step.i_lp_inst = lp.i_lp_inst)
  JOIN civl4_odi_repo.snp_lpi_step_log   slog ON (step.i_lp_inst = slog.i_lp_inst AND step.i_lp_step = slog.i_lp_step AND lp.nb_run = slog.nb_run)
 WHERE lp.load_plan_name = 'CIVL_LP_900236_SBP_INCR_LOAD'
--   AND trunc(lp.start_date) = trunc(sysdate)
   AND lp.i_lp_inst = 63097
   AND step.lp_step_name LIKE 'Serial%>%'
   AND slog.end_date - slog.start_date > 0
 ORDER BY lp.load_plan_Name, lp.start_date, slog.start_date
;
