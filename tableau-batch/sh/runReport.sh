#!/bin/bash
#### runReport.sh script
# This script is to be run from IWS using /cola/run
# typical call is:
#
# /cola/run tblsh runReport.sh <options>
#
# Command line options:
# option          mand.     value (all values are case sensitive!!!)
# -S<site>         ALL      the site in Tableau to connect to
# -W<workbook>     ALL      the workbook to access (can contain spaces or the & character)
# -T<filetype>     ALL      the filetype to produce: png, pdf, csv or xlsx
# -V<view>         ALL      the view to access (can contain spaces) or _ALL if workbook report (pdf only)
# -F<folder>       ALL      the subfolder to use
# -B<base name>    ALL      the base filename to produce
# -O<orientation>  PDF      the page orientation: landscape or portrait
# -P<page type>    PDF      the page type/size: one of A4, A3, Legal
# -R<resolution>   PNG      the resolution of the image: standard or high
# -I<filterexp>    NO       an optional filter expression on the data. Syntax is from tableau API itself.
#                              example: "vf_year=2017". It can contain blanks.
# -J<project>      ALL      the project in Tableau where the workbook reside
#
#############################################################################
# Change history    Please add at least 1 line when you change ths code!    #
# Change history    Please update the ScriptVersion variable to a new vrs!  #
#############################################################################
# dexa  # Sep/2020      # 1.0.0   # initial version
# visv  # Aug/2021      # 1.1.0   # Added the project
#############################################################################
#

SetLogFile()
{

LOG_FILE="${tbllog}/runReport_${UNISON_SCHED_DATE}_${UNISON_JOBNUM}.log"
touch $LOG_FILE
echo "Log started on:" >> $LOG_FILE
date >> $LOG_FILE

}

LogIWSInfo() {
echo "IWS related info:" >> $LOG_FILE
echo "Workstation: $UNISON_HOST" >> $LOG_FILE
echo "Jobname:     $UNISON_JOB" >> $LOG_FILE
echo "Jobnumber:   $UNISON_JBNUM" >> $LOG_FILE
echo "Run number:  $UNISON_RUN" >> $LOG_FILE
echo "End of IWS related info" >> $LOG_FILE


}


Initialise()
{
    SUBROUTINE=$0

    # General Settings and procedures
    . $colash/ShProcedures.sh;

}

LoadIniFiles()
{
  source ${tblini}/taredi.properties
  source ${tblini}/taredi_cred.properties

}

DoRunReport()
{
  SUBROUTINE=$0
  source ${tblsh}/taredi_functions.sh

  taredi_contentUrl="$ArgSite"
  taredi_workbook_name="$ArgWorkbook"
  taredi_project_name="$ArgProject"
  taredi_max_age=1
  taredi_view_name="$ArgView"
  taredi_format_type="$ArgFileType"
  taredi_pdf_page_orientation="$ArgPdfPageOrientation"
  taredi_pdf_page_type="$ArgPdfPageType"
  taredi_png_resolution="$ArgPngResolution"
  if [ ! "$ArgDataFilter" = "X" ]; then
    taredi_filter="$ArgDataFilter"
  fi

  taredi_temp_folder="${tbltmp}/J${UNISON_JOBNUM}"
  rm -rf ${taredi_temp_folder}
  mkdir -p ${taredi_temp_folder}

  taredi_initialize

  ## ensure the target folder exists, make it if needed
  mkdir -p "${tblpub}/naar/${ArgTargetFolder}"
  if [ ! -d "${tblpub}/naar/${ArgTargetFolder}" ]; then
    Failure "failed to create the target folder '${tblpub}/naar/${ArgTargetFolder}'."
  fi

  local Timestamp=$( date +%Y%m%d_%H%M%S )
  taredi_filename="${tblpub}/naar/${ArgTargetFolder}/${ArgTargetFilenameBase}_${Timestamp}.${taredi_format_type}"
  Log "Target file to produce will be: $taredi_filename"
  ## check if it already exists
  if [ -e "$taredi_filename" ]; then
    Failure "There is already a file with the name of the target file!"
  fi

  Log "calling taredi_get_token"
  taredi_get_token
  Log "returned from taredi_get_token"
  Log "taredi_error=$taredi_error"

  if [ ! $taredi_error == "0" ]; then
    Log "taredi_contentUrl     = $taredi_contentUrl"
    Log "taredi_tableau_url    = $taredi_tableau_url"
    Log "taredi_usr            = $taredi_usr"
    Log "taredi_api_vrs        = $taredi_api_vrs"
    Failure "failed to obtain token (error: ${taredi_error})"
  fi

  Log "calling taredi_get_workbook_id"
  taredi_get_workbook_id
  Log "returned from taredi_get_workbook_id"
  Log "taredi_error=$taredi_error"

  if [ ! $taredi_error == "0" ]; then
    Log "taredi_contentUrl     = $taredi_contentUrl"
    Log "taredi_tableau_url    = $taredi_tableau_url"
    Log "taredi_usr            = $taredi_usr"
    Log "taredi_api_vrs        = $taredi_api_vrs"
    Log "taredi_project_name   = $taredi_project_name"
    Log "taredi_workbook_name  = $taredi_workbook_name"
    Failure "failed to obtain workbook id (error: ${taredi_error})"
  fi

  if [ "$ArgView" = "_ALL" ]; then
    # produce a workbook output
    Log "calling taredi_get_file_workbook"
    taredi_get_file_workbook
    Log "returned from taredi_get_file_workbook"
    Log "taredi_error=$taredi_error"

    if [ ! $taredi_error == "0" ]; then
      Log "taredi_contentUrl           = $taredi_contentUrl"
      Log "taredi_tableau_url          = $taredi_tableau_url"
      Log "taredi_usr                  = $taredi_usr"
      Log "taredi_api_vrs              = $taredi_api_vrs"
      Log "taredi_workbook_name        = $taredi_workbook_name"
      Log "taredi_project_name         = $taredi_project_name"
      Log "taredi_pdf_page_orientation = $taredi_page_orientation"
      Log "taredi_pdf_page_type        = $taredi_page_type"
      Failure "failed to produce workbook report file (error: ${taredi_error})"
    fi
    rm -rf ${taredi_temp_folder}

  else
    # produce a view output
    Log "calling taredi_get_view_id"
    taredi_get_view_id
    Log "returned from taredi_get_view_id"
    Log "taredi_error=$taredi_error"

    if [ ! $taredi_error == "0" ]; then
      Log "taredi_contentUrl           = $taredi_contentUrl"
      Log "taredi_tableau_url          = $taredi_tableau_url"
      Log "taredi_usr                  = $taredi_usr"
      Log "taredi_api_vrs              = $taredi_api_vrs"
      Log "taredi_project_name         = $taredi_project_name"
      Log "taredi_workbook_name        = $taredi_workbook_name"
      Log "taredi_view_name            = $taredi_view_name"
      Failure "failed to obtain a view id (error: ${taredi_error})"
    fi

    Log "calling taredi_get_file_one_view"
    taredi_get_file_one_view
    Log "returned from taredi_get_file_one_view"
    Log "taredi_error=$taredi_error"

    if [ ! $taredi_error == "0" ]; then
      Log "taredi_contentUrl           = $taredi_contentUrl"
      Log "taredi_tableau_url          = $taredi_tableau_url"
      Log "taredi_usr                  = $taredi_usr"
      Log "taredi_api_vrs              = $taredi_api_vrs"
      Log "taredi_workbook_name        = $taredi_workbook_name"
      Log "taredi_format_type          = $taredi_format_type"
      Log "taredi_pdf_page_orientation = $taredi_page_orientation"
      Log "taredi_pdf_page_type        = $taredi_page_type"
      Log "taredi_png_resolution       = $taredi_png_resolution"
      Log "taredi_filter               = $taredi_filter"
      Failure "failed to produce view report file (error: ${taredi_error})"
    fi
    rm -rf ${taredi_temp_folder}

  fi

}


SetLogFile

LogIWSInfo

Initialise

## process command line options

ArgSite="X"
ArgWorkbook="X"
ArgFileType="X"
ArgView="X"
ArgTargetFolder="X"
ArgTargetFilenameBase="X"
ArgPdfPageOrientation="X"
ArgPdfPageType="X"
ArgPngResolution="X"
ArgDataFilter="X"
ArgProject="X"

Log "Parsing options ..."
while getopts :hS:W:T:V:F:B:O:P:R:I:J: option; do
  case $option
    in
    h) print_help;;
    S) ArgSite=${OPTARG};;
    W) ArgWorkbook=${OPTARG};;
    T) ArgFileType=${OPTARG};;
    V) ArgView=${OPTARG};;
    F) ArgTargetFolder=${OPTARG};;
    B) ArgTargetFilenameBase=${OPTARG};;
    O) ArgPdfPageOrientation=${OPTARG};;
    P) ArgPdfPageType=${OPTARG};;
    R) ArgPngResolution=${OPTARG};;
    I) ArgDataFilter=${OPTARG};;
    J) ArgProject=${OPTARG};;
    *) Failure "Unknown option $OPTARG given.";;
  esac
done
if [ "${ArgSite}" = "X" ]; then
  Log "Missing -S parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgWorkbook}" = "X" ]; then
  Log "Missing -W parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgProject}" = "X" ]; then
  Log "Missing -J parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgFileType}" = "X" ]; then
  Log "Missing -T parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgView}" = "X" ]; then
  Log "Missing -V parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgTargetFolder}" = "X" ]; then
  Log "Missing -F parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgTargetFilenameBase}" = "X" ]; then
  Log "Missing -B parameter. Use -h for help."
  Failure "bad options."
fi
if [ "${ArgFileType}" = "pdf" ]; then
  ## PDF specific validations
  if [ "${ArgPdfPageOrientation}" = "X" ]; then
    Log "Missing -O parameter when type is PDF. Use -h for help."
    Failure "bad options."
  fi
  if [ "${ArgPdfPageType}" = "X" ]; then
    Log "Missing -P parameter when type is PDF. Use -h for help."
    Failure "bad options."
  fi
fi
if [ "${ArgFileType}" = "png" ]; then
  ## PNG specific validations
  if [ "${ArgPngResolution}" = "X" ]; then
    Log "Missing -R parameter when type is PNG. Use -h for help."
    Failure "bad options."
  fi
fi

LoadIniFiles

# Check if taredi/tableau exists on this environment
if [ "${taredi_active}" = "NO" ]; then
  Log "Taredi is inactive according to the properties files. Nothing to do."
  exit 0
fi

DoRunReport

exit 0

